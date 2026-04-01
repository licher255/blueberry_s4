#include "kinco_can_control/kinco_can_control_node.hpp"

#include <fcntl.h>
#include <limits>

namespace kinco {

CanControlNode::CanControlNode(rclcpp::Node::SharedPtr node)
    : node_(node),
      if_name_("can_fd"),
      node_id_(1),
      state_publish_rate_(10.0),
      can_socket_(-1),
      running_(false),
      state_updated_(false),
      target_position_cmd_(std::numeric_limits<double>::quiet_NaN()) {
  READ_PARAM(std::string, "can_name", if_name_, "can_fd");
  READ_PARAM(int, "node_id", node_id_, 1);
  READ_PARAM(double, "state_publish_rate", state_publish_rate_, 10.0);

  cmd_sub_ = node_->create_subscription<kinco_can_interfaces::msg::KincoCmd>(
      "kinco_cmd", 10,
      std::bind(&CanControlNode::kincoCmdCallback, this,
                std::placeholders::_1));

  state_pub_ = node_->create_publisher<kinco_can_interfaces::msg::KincoState>(
      "kinco_state", 10);

  // Initialize state cache
  state_msg_.node_id = node_id_;
  state_msg_.position_deg = std::numeric_limits<double>::quiet_NaN();
  state_msg_.speed_rpm = std::numeric_limits<double>::quiet_NaN();
  state_msg_.is_enabled = false;
  state_msg_.error_code = 0;
  state_msg_.target_reached = false;
  state_msg_.limit_reached = false;
  state_msg_.target_position_deg = std::numeric_limits<double>::quiet_NaN();
  state_msg_.remaining_distance_deg = std::numeric_limits<double>::quiet_NaN();
}

CanControlNode::~CanControlNode() { stop(); }

bool CanControlNode::run() {
  RCLCPP_INFO(node_->get_logger(), "Using CAN interface: %s", if_name_.c_str());

  can_socket_ = socket(PF_CAN, SOCK_RAW, CAN_RAW);
  if (can_socket_ < 0) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to open socket: %s",
                 strerror(errno));
    return false;
  }

  // DO NOT enable CAN-FD frames - we only want standard CAN frames for Kinco
  // This naturally isolates us from WHJ's CAN-FD traffic

  struct ifreq ifr;
  strncpy(ifr.ifr_name, if_name_.c_str(), IFNAMSIZ - 1);
  ifr.ifr_name[IFNAMSIZ - 1] = '\0';
  if (ioctl(can_socket_, SIOCGIFINDEX, &ifr) < 0) {
    RCLCPP_ERROR(node_->get_logger(),
                 "Failed to get interface index: %s ==> %s", strerror(errno),
                 if_name_.c_str());
    close(can_socket_);
    can_socket_ = -1;
    return false;
  }

  struct sockaddr_can addr;
  memset(&addr, 0, sizeof(addr));
  addr.can_family = AF_CAN;
  addr.can_ifindex = ifr.ifr_ifindex;
  if (bind(can_socket_, reinterpret_cast<struct sockaddr*>(&addr),
           sizeof(addr)) < 0) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to bind socket: %s",
                 strerror(errno));
    close(can_socket_);
    can_socket_ = -1;
    return false;
  }

  // Set non-blocking for recv thread
  int flags = fcntl(can_socket_, F_GETFL, 0);
  fcntl(can_socket_, F_SETFL, flags | O_NONBLOCK);

  running_ = true;

  // Initialize motor
  if (!startNode()) {
    RCLCPP_WARN(node_->get_logger(), "NMT start failed, continuing...");
  }
  std::this_thread::sleep_for(std::chrono::milliseconds(100));

  if (!enableAbsoluteMode()) {
    RCLCPP_WARN(node_->get_logger(), "Enable absolute mode failed");
  } else {
    std::lock_guard<std::mutex> lock(state_mutex_);
    state_msg_.is_enabled = true;
  }

  // Start background threads
  recv_thread_ = std::thread(&CanControlNode::canDataRecvCallback, this);
  timer_thread_ = std::thread(&CanControlNode::timerLoop, this);

  RCLCPP_INFO(node_->get_logger(),
              "Kinco CAN node started (node_id=%d)", node_id_);
  return true;
}

void CanControlNode::stop() {
  running_ = false;

  if (recv_thread_.joinable()) {
    recv_thread_.join();
  }
  if (timer_thread_.joinable()) {
    timer_thread_.join();
  }

  if (can_socket_ >= 0) {
    close(can_socket_);
    can_socket_ = -1;
  }
}

bool CanControlNode::sendCanFrame(uint32_t can_id, const uint8_t* data,
                                  uint8_t len) {
  struct can_frame frame;
  memset(&frame, 0, sizeof(frame));
  frame.can_id = can_id;  // Standard frame (11-bit) by default
  frame.can_dlc = len;
  memcpy(frame.data, data, len);

  int ret = write(can_socket_, &frame, sizeof(frame));
  if (ret <= 0) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to send CAN frame: %s",
                 strerror(errno));
    return false;
  }
  return true;
}

void CanControlNode::canDataRecvCallback() {
  struct can_frame recv_frame;
  // Kinco uses fixed IDs (not node_id based) according to protocol doc
  const uint32_t tpdo1_id = TPDO1_ID;  // 0x181 - Status/Alarm
  const uint32_t tpdo2_id = TPDO2_ID;  // 0x281 - Position/Velocity (per protocol)
  const uint32_t emcy_id = EMCY_ID_BASE + node_id_;

  while (running_ && rclcpp::ok()) {
    int nbytes = read(can_socket_, &recv_frame, sizeof(recv_frame));
    if (nbytes < 0) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        std::this_thread::sleep_for(std::chrono::milliseconds(1));
      } else {
        RCLCPP_ERROR(node_->get_logger(), "CAN read error: %s", strerror(errno));
        std::this_thread::sleep_for(std::chrono::milliseconds(10));
      }
      continue;
    }

    if (nbytes != static_cast<int>(sizeof(struct can_frame))) {
      // Skip CAN-FD frames or malformed frames (should not happen without FD_FRAMES)
      continue;
    }

    uint32_t can_id = recv_frame.can_id & CAN_SFF_MASK;

    if (can_id == tpdo2_id && recv_frame.can_dlc >= 8) {
      // Per protocol doc: TPDO2 (0x281) contains:
      // Byte 1-4: Actual Position (low byte first)
      // Byte 5-8: Actual Velocity (low byte first)
      int32_t pos_inc =
          (static_cast<int32_t>(recv_frame.data[3]) << 24) |
          (static_cast<int32_t>(recv_frame.data[2]) << 16) |
          (static_cast<int32_t>(recv_frame.data[1]) << 8) |
          static_cast<int32_t>(recv_frame.data[0]);
      int32_t vel_raw =
          (static_cast<int32_t>(recv_frame.data[7]) << 24) |
          (static_cast<int32_t>(recv_frame.data[6]) << 16) |
          (static_cast<int32_t>(recv_frame.data[5]) << 8) |
          static_cast<int32_t>(recv_frame.data[4]);

      std::lock_guard<std::mutex> lock(state_mutex_);
      state_msg_.position_deg = static_cast<double>(pos_inc) / GEAR_RATIO;
      state_msg_.speed_rpm = static_cast<double>(vel_raw) / RPM_TO_UNITS;
      state_updated_ = true;
    } else if (can_id == tpdo1_id && recv_frame.can_dlc >= 4) {
      // Per Kinco protocol: TPDO1 (0x181) contains:
      // Byte 0-1: Status Word (16-bit, little-endian)
      // Byte 2-3: Warning Word (16-bit, little-endian)
      //
      // Status Word bits (6041h):
      // bit0: Ready_to_switch_on, bit1: Switched_on, bit2: Operation_enabled
      // bit3: Fault, bit4: Voltage_enabled, bit5: Quick_stop
      // bit6: Switch_on_disabled, bit7: Warning, bit9: Remote
      // bit10: Target_reached, bit11: Internal_limit_active
      //
      // Warning Word bits (2680h):
      // bit0: Battery Warning, bit1: Mixed Warning, bit2: Encoder Busy
      
      uint16_t status_word = recv_frame.data[0] | (recv_frame.data[1] << 8);
      uint16_t warning_word = recv_frame.data[2] | (recv_frame.data[3] << 8);
      
      // Parse status word
      bool is_enabled = (status_word & 0x04) != 0;       // bit2: Operation_enabled
      bool target_reached = (status_word & 0x0400) != 0; // bit10: Target_reached
      // bool has_fault = (status_word & 0x08) != 0;        // bit3: Fault (available for future use)
      // bool has_warning = (status_word & 0x0080) != 0;    // bit7: Warning (available for future use)
      
      std::lock_guard<std::mutex> lock(state_mutex_);
      state_msg_.is_enabled = is_enabled;
      state_msg_.target_reached = target_reached;
      // Use warning_word if present, otherwise use fault from status_word
      state_msg_.error_code = warning_word;
      state_updated_ = true;
    } else if (can_id == emcy_id && recv_frame.can_dlc >= 8) {
      // Byte 4-5: error status (0x2601)
      uint16_t err_status =
          recv_frame.data[4] | (recv_frame.data[5] << 8);

      std::lock_guard<std::mutex> lock(state_mutex_);
      state_msg_.error_code = err_status;
      state_updated_ = true;
    }
    // Other frames are silently consumed to keep buffer clear
  }
}

void CanControlNode::timerLoop() {
  auto interval = std::chrono::milliseconds(
      static_cast<int>(1000.0 / state_publish_rate_));

  while (running_ && rclcpp::ok()) {
    kinco_can_interfaces::msg::KincoState msg;
    {
      std::lock_guard<std::mutex> lock(state_mutex_);
      msg = state_msg_;
      
      // Calculate remaining distance to target
      if (!std::isnan(target_position_cmd_) && !std::isnan(msg.position_deg)) {
        msg.target_position_deg = target_position_cmd_;
        msg.remaining_distance_deg = target_position_cmd_ - msg.position_deg;
      } else {
        msg.target_position_deg = std::numeric_limits<double>::quiet_NaN();
        msg.remaining_distance_deg = std::numeric_limits<double>::quiet_NaN();
      }
      msg.header.stamp = node_->now();
      msg.header.frame_id = "kinco_link";
      state_updated_ = false;
    }
    state_pub_->publish(msg);
    std::this_thread::sleep_for(interval);
  }
}

bool CanControlNode::startNode() {
  // Per protocol doc: 0x000, 01 00 - Start all nodes (broadcast)
  // NMT command: 0x01 = Start Remote Node, 0x00 = All nodes
  uint8_t data[2] = {0x01, 0x00};
  bool ok = sendCanFrame(NMT_ID, data, 2);
  if (ok) {
    RCLCPP_INFO(node_->get_logger(), "[Kinco-%d] NMT Start (0x000, 01 00) sent", node_id_);
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
  }
  return ok;
}

bool CanControlNode::sendRpdo1(uint8_t control_low, uint8_t control_high,
                               uint8_t mode) {
  uint8_t data[8] = {control_low, control_high, mode, 0x00, 0x00, 0x00, 0x00, 0x00};
  return sendCanFrame(RPDO1_ID, data, 8);
}

bool CanControlNode::enableAbsoluteMode() {
  bool ok = sendRpdo1(0x01, 0x3F, 0x10);
  if (ok) {
    RCLCPP_INFO(node_->get_logger(), "[Kinco-%d] Enabled absolute mode", node_id_);
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
  }
  return ok;
}

bool CanControlNode::disable() {
  bool ok = sendRpdo1(0x01, 0x06, 0x10);
  if (ok) {
    RCLCPP_INFO(node_->get_logger(), "[Kinco-%d] Disabled", node_id_);
    std::lock_guard<std::mutex> lock(state_mutex_);
    state_msg_.is_enabled = false;
  }
  return ok;
}

bool CanControlNode::clearFault() {
  bool ok = sendRpdo1(0x01, 0x86, 0x10);
  if (ok) {
    RCLCPP_INFO(node_->get_logger(), "[Kinco-%d] Fault clear sent", node_id_);
    std::lock_guard<std::mutex> lock(state_mutex_);
    state_msg_.error_code = 0;
    std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }
  return ok;
}

bool CanControlNode::setOrigin() {
  RCLCPP_INFO(node_->get_logger(), "[Kinco-%d] Setting origin...", node_id_);
  if (!sendRpdo1(0x06, 0x0F, 0x00)) return false;
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  if (!sendRpdo1(0x06, 0x1F, 0x00)) return false;
  std::this_thread::sleep_for(std::chrono::milliseconds(100));
  if (!enableAbsoluteMode()) return false;
  RCLCPP_INFO(node_->get_logger(), "[Kinco-%d] Origin set", node_id_);
  return true;
}

bool CanControlNode::moveToPosition(double degree, double rpm) {
  int32_t pos_inc = static_cast<int32_t>(degree * GEAR_RATIO);
  uint32_t vel_units = static_cast<uint32_t>(rpm * RPM_TO_UNITS);

  uint8_t data[8];
  data[0] = pos_inc & 0xFF;
  data[1] = (pos_inc >> 8) & 0xFF;
  data[2] = (pos_inc >> 16) & 0xFF;
  data[3] = (pos_inc >> 24) & 0xFF;
  data[4] = vel_units & 0xFF;
  data[5] = (vel_units >> 8) & 0xFF;
  data[6] = (vel_units >> 16) & 0xFF;
  data[7] = (vel_units >> 24) & 0xFF;

  bool ok = sendCanFrame(RPDO2_ID, data, 8);
  if (ok) {
    RCLCPP_INFO(node_->get_logger(),
                "[Kinco-%d] Move to %.2f deg @ %.1f rpm", node_id_, degree, rpm);
  }
  return ok;
}

bool CanControlNode::stopMotion() {
  std::lock_guard<std::mutex> lock(state_mutex_);
  double current_pos = state_msg_.position_deg;
  if (!std::isnan(current_pos)) {
    return moveToPosition(current_pos, 0.0);
  }
  return true;
}

void CanControlNode::kincoCmdCallback(
    const kinco_can_interfaces::msg::KincoCmd::SharedPtr msg) {
  if (msg->node_id != node_id_) {
    RCLCPP_WARN(node_->get_logger(),
                "Command for node %d, we are %d", msg->node_id, node_id_);
    return;
  }

  if (msg->clear_error) {
    clearFault();
  }

  if (msg->set_zero) {
    if (setOrigin()) {
      // Reset target position after zeroing
      target_position_cmd_ = 0.0;
    }
  }

  if (!std::isnan(msg->target_position_deg)) {
    double rpm = std::isnan(msg->target_speed_rpm) ? 50.0 : msg->target_speed_rpm;
    if (moveToPosition(msg->target_position_deg, rpm)) {
      // Store target position for distance calculation
      target_position_cmd_ = msg->target_position_deg;
    }
  }

  if (msg->enable) {
    if (enableAbsoluteMode()) {
      std::lock_guard<std::mutex> lock(state_mutex_);
      state_msg_.is_enabled = true;
    }
  } else {
    // If this is a disable-only command (no other fields set)
    bool has_other_action = msg->clear_error || msg->set_zero ||
                            !std::isnan(msg->target_position_deg);
    if (!has_other_action) {
      disable();
    }
  }
}

}  // namespace kinco

int main(int argc, char* argv[]) {
  rclcpp::init(argc, argv);
  auto node = std::make_shared<rclcpp::Node>("kinco_can_control_node");

  kinco::CanControlNode controller(node);
  if (!controller.run()) {
    RCLCPP_ERROR(node->get_logger(),
                 "Failed to initialize kinco_can_control_node");
    rclcpp::shutdown();
    return 1;
  }

  RCLCPP_INFO(node->get_logger(),
              "kinco_can_control_node initialized successfully");

  rclcpp::spin(node);

  controller.stop();
  RCLCPP_INFO(node->get_logger(), "kinco_can_control_node stopped");
  rclcpp::shutdown();

  return 0;
}
