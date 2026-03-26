#include "whj_can_control/whj_can_control_node.hpp"

namespace whj
{

CanControl::CanControl(rclcpp::Node::SharedPtr node)
    : node_(node), if_name_("can1"), can_socket_(-1), canfd_enabled_(true)
{
    // Read parameters
    READ_PARAM(std::string, "can_name", if_name_, "can1");
    READ_PARAM(bool, "canfd_enabled", canfd_enabled_, true);

    // Create subscribers
    position_cmd_subscriber_ = node_->create_subscription<whj_can_interfaces::msg::PositionCmd>(
        "whj/position_cmd", 10,
        std::bind(&CanControl::position_cmd_callback, this, std::placeholders::_1));

    velocity_cmd_subscriber_ = node_->create_subscription<whj_can_interfaces::msg::VelocityCmd>(
        "whj/velocity_cmd", 10,
        std::bind(&CanControl::velocity_cmd_callback, this, std::placeholders::_1));

    // Create publishers
    state_fb_publisher_ = node_->create_publisher<whj_can_interfaces::msg::StateFb>("whj/state_fb", 10);
    position_fb_publisher_ = node_->create_publisher<whj_can_interfaces::msg::PositionFb>("whj/position_fb", 10);
    status_fb_publisher_ = node_->create_publisher<whj_can_interfaces::msg::StatusFb>("whj/status_fb", 10);

    RCLCPP_INFO(node_->get_logger(), "WHJ CAN control node initialized");
    RCLCPP_INFO(node_->get_logger(), "CAN interface: %s, CAN-FD: %s", 
                if_name_.c_str(), canfd_enabled_ ? "enabled" : "disabled");
}

CanControl::~CanControl()
{
}

void CanControl::position_cmd_callback(const whj_can_interfaces::msg::PositionCmd::SharedPtr msg)
{
    // TODO: Implement according to WHJ protocol
    // This is a placeholder implementation
    uint8_t data[8] = {0};
    
    // Pack position command (example format)
    int16_t position_mm = static_cast<int16_t>(msg->target_position);
    int16_t speed_mm_s = static_cast<int16_t>(msg->target_speed);
    
    data[0] = 0x01;  // Command ID for position control
    data[1] = msg->control_mode;
    data[2] = position_mm & 0xFF;
    data[3] = (position_mm >> 8) & 0xFF;
    data[4] = speed_mm_s & 0xFF;
    data[5] = (speed_mm_s >> 8) & 0xFF;
    
    // Send frame
    if (canfd_enabled_) {
        send_canfd_frame(0x01, data, 6);
    } else {
        send_can_frame(0x01, data, 6);
    }
    
    RCLCPP_DEBUG(node_->get_logger(), "Position cmd: pos=%.1f mm, speed=%.1f mm/s, mode=%d",
                 msg->target_position, msg->target_speed, msg->control_mode);
}

void CanControl::velocity_cmd_callback(const whj_can_interfaces::msg::VelocityCmd::SharedPtr msg)
{
    // TODO: Implement according to WHJ protocol
    uint8_t data[8] = {0};
    
    int16_t velocity = static_cast<int16_t>(msg->target_velocity);
    
    data[0] = 0x02;  // Command ID for velocity control
    data[1] = msg->direction;
    data[2] = velocity & 0xFF;
    data[3] = (velocity >> 8) & 0xFF;
    
    if (canfd_enabled_) {
        send_canfd_frame(0x02, data, 4);
    } else {
        send_can_frame(0x02, data, 4);
    }
    
    RCLCPP_DEBUG(node_->get_logger(), "Velocity cmd: vel=%.1f mm/s, dir=%d",
                 msg->target_velocity, msg->direction);
}

bool CanControl::send_can_frame(uint32_t can_id, const uint8_t* data, uint8_t len)
{
    if (can_socket_ < 0) {
        RCLCPP_ERROR(node_->get_logger(), "CAN socket not open");
        return false;
    }
    
    struct can_frame frame;
    frame.can_id = can_id;
    frame.can_dlc = len;
    memcpy(frame.data, data, len);
    
    int ret = write(can_socket_, &frame, sizeof(frame));
    if (ret <= 0) {
        RCLCPP_ERROR(node_->get_logger(), "Failed to send CAN frame: %s", strerror(errno));
        return false;
    }
    
    return true;
}

bool CanControl::send_canfd_frame(uint32_t can_id, const uint8_t* data, uint8_t len)
{
    if (can_socket_ < 0) {
        RCLCPP_ERROR(node_->get_logger(), "CAN socket not open");
        return false;
    }
    
    struct canfd_frame frame;
    frame.can_id = can_id;
    frame.len = len;
    memcpy(frame.data, data, len);
    
    int ret = write(can_socket_, &frame, sizeof(frame));
    if (ret <= 0) {
        RCLCPP_ERROR(node_->get_logger(), "Failed to send CAN-FD frame: %s", strerror(errno));
        return false;
    }
    
    return true;
}

void CanControl::parse_position_fb(const uint8_t* data, uint8_t len)
{
    if (len < 6) return;
    
    auto msg = whj_can_interfaces::msg::PositionFb();
    
    // Parse position feedback (example format)
    int16_t current_pos = data[0] | (data[1] << 8);
    int16_t target_pos = data[2] | (data[3] << 8);
    int16_t current_spd = data[4] | (data[5] << 8);
    
    msg.current_position = static_cast<float>(current_pos);
    msg.target_position = static_cast<float>(target_pos);
    msg.current_speed = static_cast<float>(current_spd);
    
    position_fb_publisher_->publish(msg);
}

void CanControl::parse_status_fb(const uint8_t* data, uint8_t len)
{
    if (len < 4) return;
    
    auto msg = whj_can_interfaces::msg::StatusFb();
    
    msg.error_code = data[0] | (data[1] << 8);
    msg.work_mode = data[2];
    msg.is_moving = (data[3] & 0x01) != 0;
    msg.is_homed = (data[3] & 0x02) != 0;
    msg.is_stalled = (data[3] & 0x04) != 0;
    msg.upper_limit = (data[3] & 0x10) != 0;
    msg.lower_limit = (data[3] & 0x20) != 0;
    
    status_fb_publisher_->publish(msg);
}

bool CanControl::wait_for_can_frame()
{
    struct timeval tv;
    fd_set rdfs;
    FD_ZERO(&rdfs);
    FD_SET(can_socket_, &rdfs);
    tv.tv_sec = 0;
    tv.tv_usec = 10000; // 10ms timeout

    int ret = select(can_socket_ + 1, &rdfs, NULL, NULL, &tv);
    if (ret == -1) {
        RCLCPP_ERROR(node_->get_logger(), "Error waiting for CAN frame: %s", strerror(errno));
        return false;
    } else if (ret == 0) {
        return false;  // Timeout
    }
    return true;
}

void CanControl::can_data_recv_callback()
{
    RCLCPP_INFO(node_->get_logger(), "CAN receiver thread started");
    
    while (rclcpp::ok()) {
        if (!wait_for_can_frame()) {
            continue;
        }
        
        if (canfd_enabled_) {
            struct canfd_frame recv_frame;
            int nbytes = read(can_socket_, &recv_frame, sizeof(recv_frame));
            
            if (nbytes < 0) {
                RCLCPP_ERROR(node_->get_logger(), "Error reading CAN-FD frame: %s", strerror(errno));
                continue;
            }
            
            if (nbytes != CANFD_MTU && nbytes != CAN_MTU) {
                RCLCPP_WARN(node_->get_logger(), "Unexpected frame size: %d", nbytes);
                continue;
            }
            
            // Parse based on CAN ID
            switch (recv_frame.can_id) {
                case 0x101:  // Position feedback
                    parse_position_fb(recv_frame.data, recv_frame.len);
                    break;
                case 0x102:  // Status feedback
                    parse_status_fb(recv_frame.data, recv_frame.len);
                    break;
                default:
                    RCLCPP_DEBUG(node_->get_logger(), "Unknown CAN ID: 0x%X", recv_frame.can_id);
                    break;
            }
        } else {
            struct can_frame recv_frame;
            int nbytes = read(can_socket_, &recv_frame, sizeof(recv_frame));
            
            if (nbytes < 0) {
                RCLCPP_ERROR(node_->get_logger(), "Error reading CAN frame: %s", strerror(errno));
                continue;
            }
            
            if (nbytes != CAN_MTU) {
                RCLCPP_WARN(node_->get_logger(), "Unexpected frame size: %d", nbytes);
                continue;
            }
            
            // Parse based on CAN ID
            switch (recv_frame.can_id) {
                case 0x101:  // Position feedback
                    parse_position_fb(recv_frame.data, recv_frame.can_dlc);
                    break;
                case 0x102:  // Status feedback
                    parse_status_fb(recv_frame.data, recv_frame.can_dlc);
                    break;
                default:
                    RCLCPP_DEBUG(node_->get_logger(), "Unknown CAN ID: 0x%X", recv_frame.can_id);
                    break;
            }
        }
    }
    
    RCLCPP_INFO(node_->get_logger(), "CAN receiver thread stopped");
}

bool CanControl::run()
{
    RCLCPP_INFO(node_->get_logger(), "Opening CAN interface: %s", if_name_.c_str());
    
    // Create socket
    can_socket_ = socket(PF_CAN, SOCK_RAW, CAN_RAW);
    if (can_socket_ < 0) {
        RCLCPP_ERROR(node_->get_logger(), "Failed to create socket: %s", strerror(errno));
        return false;
    }
    
    // Enable CAN-FD if needed
    if (canfd_enabled_) {
        int enable_canfd = 1;
        if (setsockopt(can_socket_, SOL_CAN_RAW, CAN_RAW_FD_FRAMES, 
                       &enable_canfd, sizeof(enable_canfd)) < 0) {
            RCLCPP_ERROR(node_->get_logger(), "Failed to enable CAN-FD: %s", strerror(errno));
            close(can_socket_);
            can_socket_ = -1;
            return false;
        }
        RCLCPP_INFO(node_->get_logger(), "CAN-FD mode enabled");
    }
    
    // Get interface index
    struct ifreq ifr;
    strncpy(ifr.ifr_name, if_name_.c_str(), IFNAMSIZ - 1);
    ifr.ifr_name[IFNAMSIZ - 1] = '\0';
    
    if (ioctl(can_socket_, SIOCGIFINDEX, &ifr) < 0) {
        RCLCPP_ERROR(node_->get_logger(), "Failed to get interface index for %s: %s", 
                     if_name_.c_str(), strerror(errno));
        close(can_socket_);
        can_socket_ = -1;
        return false;
    }
    
    // Bind socket
    struct sockaddr_can addr;
    memset(&addr, 0, sizeof(addr));
    addr.can_family = AF_CAN;
    addr.can_ifindex = ifr.ifr_ifindex;
    
    if (bind(can_socket_, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        RCLCPP_ERROR(node_->get_logger(), "Failed to bind socket: %s", strerror(errno));
        close(can_socket_);
        can_socket_ = -1;
        return false;
    }
    
    RCLCPP_INFO(node_->get_logger(), "CAN socket bound to %s (ifindex=%d)", 
                if_name_.c_str(), ifr.ifr_ifindex);
    
    // Start receiver thread
    thread_ = std::thread(&CanControl::can_data_recv_callback, this);
    
    return true;
}

void CanControl::stop()
{
    RCLCPP_INFO(node_->get_logger(), "Stopping CAN control...");
    
    if (can_socket_ >= 0) {
        close(can_socket_);
        can_socket_ = -1;
    }
    
    if (thread_.joinable()) {
        thread_.join();
    }
    
    RCLCPP_INFO(node_->get_logger(), "CAN control stopped");
}

} // namespace whj

int main(int argc, char *argv[])
{
    rclcpp::init(argc, argv);
    auto node = std::make_shared<rclcpp::Node>("whj_can_control_node");

    whj::CanControl cancontrol(node);
    if (!cancontrol.run()) {
        RCLCPP_ERROR(node->get_logger(), "Failed to initialize WHJ CAN control node");
        return 1;
    }

    RCLCPP_INFO(node->get_logger(), "WHJ CAN control node running");
    
    rclcpp::spin(node);

    cancontrol.stop();
    RCLCPP_INFO(node->get_logger(), "WHJ CAN control node stopped");

    rclcpp::shutdown();
    return 0;
}
