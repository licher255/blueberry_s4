#include "whj_can_control/whj_can_control_node.hpp"

#include <linux/can.h>
#include <linux/can/raw.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <cmath>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace whj {

// Protocol constants
static constexpr uint8_t CMD_READ = 0x01;
static constexpr uint8_t CMD_WRITE = 0x02;
static constexpr uint8_t WRITE_SUCCESS = 0x01;
static constexpr uint32_t RESPONSE_ID_OFFSET = 0x100;

// Unit conversions
static constexpr float POS_SCALE = 0.0001f;
static constexpr float TARGET_SPEED_SCALE = 0.002f;
static constexpr float ACTUAL_SPEED_SCALE = 0.02f;
static constexpr float VOLTAGE_SCALE = 0.01f;
static constexpr float TEMP_SCALE = 0.1f;

CanControlNode::CanControlNode(rclcpp::Node::SharedPtr node)
    : node_(node),
      if_name_("can_fd"),
      motor_id_(7),
      state_publish_rate_(10.0),
      timeout_ms_(1500),
      retry_count_(5),
      can_socket_(-1),
      running_(false) {
  READ_PARAM(std::string, "can_name", if_name_, "can_fd");
  READ_PARAM(int, "motor_id", motor_id_, 7);
  READ_PARAM(double, "state_publish_rate", state_publish_rate_, 10.0);
  READ_PARAM(int, "timeout_ms", timeout_ms_, 1500);
  READ_PARAM(int, "retry_count", retry_count_, 5);

  cmd_sub_ = node_->create_subscription<whj_can_interfaces::msg::WhjCmd>(
      "whj_cmd", 10,
      std::bind(&CanControlNode::whjCmdCallback, this,
                std::placeholders::_1));

  state_pub_ = node_->create_publisher<whj_can_interfaces::msg::WhjState>(
      "whj_state", 10);
}

CanControlNode::~CanControlNode() { stop(); }

bool CanControlNode::run() {
  RCLCPP_INFO(node_->get_logger(), "Using CAN-FD interface: %s",
              if_name_.c_str());

  can_socket_ = socket(PF_CAN, SOCK_RAW, CAN_RAW);
  if (can_socket_ < 0) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to open socket: %s",
                 strerror(errno));
    return false;
  }

  // Enable CAN-FD frames (for receiving FD frames)
  int enable_fd = 1;
  setsockopt(can_socket_, SOL_CAN_RAW, CAN_RAW_FD_FRAMES, &enable_fd,
             sizeof(enable_fd));

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

  running_ = true;

  // Initialize motor before starting timer
  if (!initializeMotor()) {
    RCLCPP_WARN(node_->get_logger(),
                "Motor initialization did not fully succeed, but continuing...");
  }

  // Start timer loop for state publishing
  timer_thread_ = std::thread(&CanControlNode::timerLoop, this);

  return true;
}

void CanControlNode::stop() {
  running_ = false;

  if (can_socket_ >= 0) {
    close(can_socket_);
    can_socket_ = -1;
  }

  if (timer_thread_.joinable()) {
    timer_thread_.join();
  }
}

std::vector<uint8_t> CanControlNode::buildReadFrame(Register reg,
                                                     uint8_t count) {
  return {CMD_READ, static_cast<uint8_t>(reg), count};
}

std::vector<uint8_t> CanControlNode::buildWriteFrame(Register reg,
                                                      uint16_t value) {
  return {CMD_WRITE,
          static_cast<uint8_t>(reg),
          static_cast<uint8_t>(value & 0xFF),
          static_cast<uint8_t>((value >> 8) & 0xFF)};
}

int32_t CanControlNode::toInt32(uint16_t low, uint16_t high) {
  int32_t val = (static_cast<uint32_t>(high) << 16) | low;
  if (val & 0x80000000) {
    val -= 0x100000000LL;
  }
  return val;
}

bool CanControlNode::sendCanFdFrame(uint32_t can_id, const uint8_t* data,
                                     uint8_t len) {
  // Use CAN-FD frame with BRS (same as Python with USE_BRS=True)
  struct canfd_frame frame;
  memset(&frame, 0, sizeof(frame));
  frame.can_id = can_id;
  frame.len = len;
  frame.flags = CANFD_BRS;  // Bitrate switching
  memcpy(frame.data, data, len);

  int ret = write(can_socket_, &frame, sizeof(frame));
  if (ret <= 0) {
    RCLCPP_ERROR(node_->get_logger(), "Failed to send CAN-FD frame: %s",
                 strerror(errno));
    return false;
  }
  return true;
}

// Clear receive buffer - aggressive clearing for CAN-FD
void CanControlNode::clearReceiveBuffer() {
  fd_set rdfs;
  struct timeval tv;
  struct canfd_frame frame;
  int cleared = 0;
  
  // Multiple rounds of clearing to ensure buffer is empty
  for (int round = 0; round < 3; ++round) {
    while (true) {
      FD_ZERO(&rdfs);
      FD_SET(can_socket_, &rdfs);
      tv.tv_sec = 0;
      tv.tv_usec = 0;  // Non-blocking
      
      if (select(can_socket_ + 1, &rdfs, nullptr, nullptr, &tv) <= 0) {
        break;
      }
      
      int nbytes = read(can_socket_, &frame, sizeof(frame));
      if (nbytes < 0) {
        break;
      }
      cleared++;
    }
    // Small delay between rounds to let any in-flight frames arrive
    if (round < 2) {
      std::this_thread::sleep_for(std::chrono::microseconds(500));
    }
  }
  
  if (cleared > 0) {
    RCLCPP_DEBUG(node_->get_logger(), "Cleared %d frames from buffer", cleared);
  }
}

std::vector<uint8_t> CanControlNode::sendCommandWithResponse(
    uint32_t can_id, const uint8_t* data, uint8_t len, uint32_t resp_id,
    int timeout_ms) {
  // Clear buffer aggressively to avoid processing old frames
  clearReceiveBuffer();
  
  // Small delay after clearing to ensure bus is stable (important for CAN-FD)
  std::this_thread::sleep_for(std::chrono::microseconds(1000));

  if (!sendCanFdFrame(can_id, data, len)) {
    return {};
  }

  // Poll for response (synchronous, no background thread)
  fd_set rdfs;
  struct timeval tv;
  auto start = std::chrono::steady_clock::now();
  auto send_time = start;
  
  while (true) {
    auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
        std::chrono::steady_clock::now() - start).count();
    if (elapsed >= timeout_ms) {
      break;
    }
    
    FD_ZERO(&rdfs);
    FD_SET(can_socket_, &rdfs);
    tv.tv_sec = 0;
    tv.tv_usec = 1000;  // 1ms polling interval
    
    int ret = select(can_socket_ + 1, &rdfs, nullptr, nullptr, &tv);
    if (ret > 0) {
      // Read into buffer - use canfd_frame size as it's larger
      struct canfd_frame rx;
      int nbytes = read(can_socket_, &rx, sizeof(rx));
      auto recv_time = std::chrono::steady_clock::now();
      
      // Check if response came too fast (< 1ms) - likely old data
      auto response_time_us = std::chrono::duration_cast<std::chrono::microseconds>(
          recv_time - send_time).count();
      
      if (nbytes >= 5) {  // Minimum valid WHJ response: cmd + reg + data
        uint32_t rx_id = rx.can_id & 0x1FF;
        if (rx_id == resp_id) {
          // Validate response time - if too fast, it might be stale data
          if (response_time_us < 500) {
            RCLCPP_WARN(node_->get_logger(), 
                "Response too fast (%ld us), possibly stale data, retrying...", 
                response_time_us);
            continue;  // Skip this frame and wait for real response
          }
          
          // Valid response - extract data
          if (nbytes == static_cast<int>(sizeof(struct can_frame))) {
            // Standard CAN frame
            struct can_frame* std_rx = reinterpret_cast<struct can_frame*>(&rx);
            return std::vector<uint8_t>(std_rx->data, std_rx->data + std_rx->can_dlc);
          } else {
            // CAN-FD frame
            return std::vector<uint8_t>(rx.data, rx.data + rx.len);
          }
        }
      }
      // Ignore frames from other IDs or invalid sizes
    }
    
    // Small sleep to avoid busy-waiting too aggressively
    if (ret <= 0) {
      std::this_thread::sleep_for(std::chrono::microseconds(100));
    }
  }
  
  return {};  // Timeout
}

std::vector<uint8_t> CanControlNode::retryCommandWithResponse(
    uint32_t can_id, const uint8_t* data, uint8_t len, uint32_t resp_id,
    int timeout_ms) {
  for (int attempt = 0; attempt < retry_count_; ++attempt) {
    auto resp = sendCommandWithResponse(can_id, data, len, resp_id, timeout_ms);
    if (!resp.empty()) {
      return resp;
    }
    if (attempt < retry_count_ - 1) {
      std::this_thread::sleep_for(
          std::chrono::milliseconds(50 + 50 * attempt));
    }
  }
  return {};
}

bool CanControlNode::initializeMotor() {
  RCLCPP_INFO(node_->get_logger(), "[Init] Initializing motor %d...",
              motor_id_);

  // IAP handshake
  {
    uint8_t iap_cmd[3] = {0x02, 0x49, 0x00};
    uint32_t resp_id = motor_id_ + RESPONSE_ID_OFFSET;
    bool iap_ok = false;
    for (int attempt = 0; attempt < 3; ++attempt) {
      auto resp = sendCommandWithResponse(motor_id_, iap_cmd, 3, resp_id, 1000);
      if (!resp.empty() && resp.size() >= 1 && resp[0] == 0x02) {
        iap_ok = true;
        RCLCPP_INFO(node_->get_logger(), "[Init] IAP handshake OK");
        break;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(50 * (attempt + 1)));
    }
    if (!iap_ok) {
      RCLCPP_WARN(node_->get_logger(),
                  "[Init] IAP handshake timeout, but motor may still be enabled");
    }
  }

  // Ping motor (read firmware version)
  auto cmd = buildReadFrame(Register::SYS_FW_VERSION, 1);
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  if (!resp.empty()) {
    RCLCPP_INFO(node_->get_logger(), "[Init] Motor is online!");
  } else {
    RCLCPP_WARN(node_->get_logger(),
                "[Init] Cannot confirm motor status, but continuing...");
  }

  return true;
}

bool CanControlNode::enableMotor(bool enable) {
  auto cmd = buildWriteFrame(Register::SYS_ENABLE_DRIVER, enable ? 1 : 0);
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  if (resp.size() >= 3 && resp[0] == CMD_WRITE && resp[2] == WRITE_SUCCESS) {
    RCLCPP_INFO(node_->get_logger(), "Motor %s",
                enable ? "enabled" : "disabled");
    return true;
  }
  return false;
}

bool CanControlNode::clearError() {
  auto cmd = buildWriteFrame(Register::SYS_CLEAR_ERROR, 1);
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  return !resp.empty();
}

bool CanControlNode::setWorkMode(WorkMode mode) {
  auto cmd = buildWriteFrame(Register::TAG_WORK_MODE,
                              static_cast<uint16_t>(mode));
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  return !resp.empty();
}

bool CanControlNode::setZeroPosition() {
  auto cmd = buildWriteFrame(Register::SYS_SET_ZERO_POS, 1);
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  return !resp.empty();
}

bool CanControlNode::setTargetPosition(float position_deg) {
  int32_t raw = static_cast<int32_t>(position_deg / POS_SCALE);

  auto cmd_low = buildWriteFrame(Register::TAG_POSITION_L, raw & 0xFFFF);
  auto resp_low = retryCommandWithResponse(
      motor_id_, cmd_low.data(), cmd_low.size(),
      motor_id_ + RESPONSE_ID_OFFSET, timeout_ms_);
  if (resp_low.empty()) return false;

  std::this_thread::sleep_for(std::chrono::milliseconds(5));

  auto cmd_high =
      buildWriteFrame(Register::TAG_POSITION_H, (raw >> 16) & 0xFFFF);
  auto resp_high = retryCommandWithResponse(
      motor_id_, cmd_high.data(), cmd_high.size(),
      motor_id_ + RESPONSE_ID_OFFSET, timeout_ms_);
  return !resp_high.empty();
}

bool CanControlNode::setTargetSpeed(float speed_rpm) {
  int32_t raw = static_cast<int32_t>(speed_rpm / TARGET_SPEED_SCALE);

  auto cmd_low = buildWriteFrame(Register::TAG_SPEED_L, raw & 0xFFFF);
  auto resp_low = retryCommandWithResponse(
      motor_id_, cmd_low.data(), cmd_low.size(),
      motor_id_ + RESPONSE_ID_OFFSET, timeout_ms_);
  if (resp_low.empty()) return false;

  std::this_thread::sleep_for(std::chrono::milliseconds(5));

  auto cmd_high = buildWriteFrame(Register::TAG_SPEED_H, (raw >> 16) & 0xFFFF);
  auto resp_high = retryCommandWithResponse(
      motor_id_, cmd_high.data(), cmd_high.size(),
      motor_id_ + RESPONSE_ID_OFFSET, timeout_ms_);
  return !resp_high.empty();
}

bool CanControlNode::setTargetCurrent(int32_t current_ma) {
  auto cmd_low = buildWriteFrame(Register::TAG_CURRENT_L, current_ma & 0xFFFF);
  auto resp_low = retryCommandWithResponse(
      motor_id_, cmd_low.data(), cmd_low.size(),
      motor_id_ + RESPONSE_ID_OFFSET, timeout_ms_);
  if (resp_low.empty()) return false;

  std::this_thread::sleep_for(std::chrono::milliseconds(5));

  auto cmd_high =
      buildWriteFrame(Register::TAG_CURRENT_H, (current_ma >> 16) & 0xFFFF);
  auto resp_high = retryCommandWithResponse(
      motor_id_, cmd_high.data(), cmd_high.size(),
      motor_id_ + RESPONSE_ID_OFFSET, timeout_ms_);
  return !resp_high.empty();
}

float CanControlNode::getPosition() {
  auto cmd = buildReadFrame(Register::CUR_POSITION_L, 2);
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  if (resp.size() >= 6) {
    uint16_t low = resp[2] | (resp[3] << 8);
    uint16_t high = resp[4] | (resp[5] << 8);
    int32_t raw = toInt32(low, high);
    return raw * POS_SCALE;
  }
  return std::numeric_limits<float>::quiet_NaN();
}

whj_can_interfaces::msg::WhjState CanControlNode::readFullState() {
  whj_can_interfaces::msg::WhjState state_msg;
  state_msg.motor_id = motor_id_;
  state_msg.position_deg = std::numeric_limits<float>::quiet_NaN();
  state_msg.speed_rpm = std::numeric_limits<float>::quiet_NaN();
  state_msg.current_ma = std::numeric_limits<float>::quiet_NaN();
  state_msg.voltage_v = std::numeric_limits<float>::quiet_NaN();
  state_msg.temperature_c = std::numeric_limits<float>::quiet_NaN();
  state_msg.error_code = 0;
  state_msg.is_enabled = false;
  state_msg.work_mode = static_cast<uint8_t>(WorkMode::POSITION_MODE);

  // Read current/speed/position feedback (6 registers)
  auto cmd = buildReadFrame(Register::CUR_CURRENT_L, 6);
  RCLCPP_INFO(node_->get_logger(), "Sending read state command: [%02X %02X %02X]", 
               cmd[0], cmd[1], cmd[2]);
  auto resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                       motor_id_ + RESPONSE_ID_OFFSET,
                                       timeout_ms_);
  RCLCPP_INFO(node_->get_logger(), "Read state response: size=%zu", resp.size());
  if (resp.size() > 0) {
    std::string hex;
    for (size_t i = 0; i < resp.size() && i < 16; i++) {
      char buf[4];
      snprintf(buf, sizeof(buf), "%02X ", resp[i]);
      hex += buf;
    }
    RCLCPP_INFO(node_->get_logger(), "Response data: %s", hex.c_str());
  }
  if (resp.size() >= 14 && resp[0] == CMD_READ &&
      resp[1] == static_cast<uint8_t>(Register::CUR_CURRENT_L)) {
    uint16_t cur_low = resp[2] | (resp[3] << 8);
    uint16_t cur_high = resp[4] | (resp[5] << 8);
    uint16_t spd_low = resp[6] | (resp[7] << 8);
    uint16_t spd_high = resp[8] | (resp[9] << 8);
    uint16_t pos_low = resp[10] | (resp[11] << 8);
    uint16_t pos_high = resp[12] | (resp[13] << 8);

    state_msg.current_ma = static_cast<float>(toInt32(cur_low, cur_high));
    state_msg.speed_rpm = static_cast<float>(toInt32(spd_low, spd_high)) *
                          ACTUAL_SPEED_SCALE;
    state_msg.position_deg = static_cast<float>(toInt32(pos_low, pos_high)) *
                             POS_SCALE;
  }

  // Read system info (model, fw, voltage, temp, redu_ratio)
  cmd = buildReadFrame(Register::SYS_MODEL_TYPE, 6);
  resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                  motor_id_ + RESPONSE_ID_OFFSET,
                                  timeout_ms_);
  if (resp.size() >= 14 && resp[0] == CMD_READ &&
      resp[1] == static_cast<uint8_t>(Register::SYS_MODEL_TYPE)) {
    uint16_t voltage_raw = resp[6] | (resp[7] << 8);
    uint16_t temp_raw = resp[8] | (resp[9] << 8);
    state_msg.voltage_v = voltage_raw * VOLTAGE_SCALE;
    state_msg.temperature_c = temp_raw * TEMP_SCALE;
  }

  // Read error code
  cmd = buildReadFrame(Register::SYS_ERROR, 1);
  resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                  motor_id_ + RESPONSE_ID_OFFSET,
                                  timeout_ms_);
  if (resp.size() >= 4 && resp[0] == CMD_READ &&
      resp[1] == static_cast<uint8_t>(Register::SYS_ERROR)) {
    state_msg.error_code = resp[2] | (resp[3] << 8);
  }

  // Read enabled status
  cmd = buildReadFrame(Register::SYS_ENABLE_DRIVER, 1);
  resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                  motor_id_ + RESPONSE_ID_OFFSET,
                                  timeout_ms_);
  if (resp.size() >= 4 && resp[0] == CMD_READ &&
      resp[1] == static_cast<uint8_t>(Register::SYS_ENABLE_DRIVER)) {
    state_msg.is_enabled = (resp[2] | (resp[3] << 8)) == 1;
  }

  // Read work mode
  cmd = buildReadFrame(Register::TAG_WORK_MODE, 1);
  resp = retryCommandWithResponse(motor_id_, cmd.data(), cmd.size(),
                                  motor_id_ + RESPONSE_ID_OFFSET,
                                  timeout_ms_);
  if (resp.size() >= 4 && resp[0] == CMD_READ &&
      resp[1] == static_cast<uint8_t>(Register::TAG_WORK_MODE)) {
    state_msg.work_mode = resp[2] | (resp[3] << 8);
  }

  return state_msg;
}

void CanControlNode::whjCmdCallback(
    const whj_can_interfaces::msg::WhjCmd::SharedPtr msg) {
  if (msg->motor_id != motor_id_) {
    RCLCPP_WARN(node_->get_logger(),
                "Received command for motor %d, but this node controls motor %d",
                msg->motor_id, motor_id_);
    return;
  }

  if (msg->clear_error) {
    if (!clearError()) {
      RCLCPP_WARN(node_->get_logger(), "Failed to clear error");
    }
  }

  if (msg->set_zero) {
    if (!setZeroPosition()) {
      RCLCPP_WARN(node_->get_logger(), "Failed to set zero position");
    }
  }

  if (msg->work_mode <= 3) {
    if (!setWorkMode(static_cast<WorkMode>(msg->work_mode))) {
      RCLCPP_WARN(node_->get_logger(), "Failed to set work mode to %d",
                  msg->work_mode);
    }
  }

  if (!std::isnan(msg->target_speed_rpm) && msg->target_speed_rpm != 0.0f) {
    if (!setTargetSpeed(msg->target_speed_rpm)) {
      RCLCPP_WARN(node_->get_logger(), "Failed to set target speed");
    }
  }

  if (!std::isnan(msg->target_current_ma) && msg->target_current_ma != 0.0f) {
    if (!setTargetCurrent(static_cast<int32_t>(msg->target_current_ma))) {
      RCLCPP_WARN(node_->get_logger(), "Failed to set target current");
    }
  }

  if (!std::isnan(msg->target_position_deg)) {
    if (!setTargetPosition(msg->target_position_deg)) {
      RCLCPP_WARN(node_->get_logger(), "Failed to set target position");
    }
  }

  // Enable/disable should be applied last
  if (msg->enable) {
    enableMotor(true);
  }
}

void CanControlNode::timerLoop() {
  auto interval = std::chrono::milliseconds(
      static_cast<int>(1000.0 / state_publish_rate_));

  while (running_) {
    auto state = readFullState();
    state.header.stamp = node_->now();
    state.header.frame_id = "whj_link";
    state_pub_->publish(state);

    std::this_thread::sleep_for(interval);
  }
}

}  // namespace whj

int main(int argc, char* argv[]) {
  rclcpp::init(argc, argv);
  auto node = std::make_shared<rclcpp::Node>("whj_can_control_node");

  whj::CanControlNode controller(node);
  if (!controller.run()) {
    RCLCPP_ERROR(node->get_logger(),
                 "Failed to initialize whj_can_control_node");
    rclcpp::shutdown();
    return 1;
  }

  RCLCPP_INFO(node->get_logger(), "whj_can_control_node initialized successfully");

  rclcpp::spin(node);

  controller.stop();
  RCLCPP_INFO(node->get_logger(), "whj_can_control_node stopped");
  rclcpp::shutdown();

  return 0;
}
