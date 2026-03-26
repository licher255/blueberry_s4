#ifndef __WHJ_CAN_CONTROL_NODE_H__
#define __WHJ_CAN_CONTROL_NODE_H__

#include <linux/can.h>
#include <linux/can/raw.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <cmath>
#include <iomanip>
#include <sstream>
#include <thread>

#include "rclcpp/rclcpp.hpp"

#include "whj_can_interfaces/msg/position_cmd.hpp"
#include "whj_can_interfaces/msg/velocity_cmd.hpp"
#include "whj_can_interfaces/msg/position_fb.hpp"
#include "whj_can_interfaces/msg/status_fb.hpp"
#include "whj_can_interfaces/msg/state_fb.hpp"

#define READ_PARAM(TYPE, NAME, VAR, VALUE) VAR = VALUE; \
        node->declare_parameter<TYPE>(NAME, VAR); \
        node->get_parameter(NAME, VAR);

namespace whj {

class CanControl
{
public:
    CanControl(rclcpp::Node::SharedPtr node);
    ~CanControl();
    
    bool run();
    void stop();
    
private:
    rclcpp::Node::SharedPtr node_;
    
    std::string if_name_;
    int can_socket_;
    std::thread thread_;
    bool canfd_enabled_;
    
    // Subscribers
    rclcpp::Subscription<whj_can_interfaces::msg::PositionCmd>::SharedPtr position_cmd_subscriber_;
    rclcpp::Subscription<whj_can_interfaces::msg::VelocityCmd>::SharedPtr velocity_cmd_subscriber_;
    
    // Publishers
    rclcpp::Publisher<whj_can_interfaces::msg::StateFb>::SharedPtr state_fb_publisher_;
    rclcpp::Publisher<whj_can_interfaces::msg::PositionFb>::SharedPtr position_fb_publisher_;
    rclcpp::Publisher<whj_can_interfaces::msg::StatusFb>::SharedPtr status_fb_publisher_;
    
    // Callbacks
    void position_cmd_callback(const whj_can_interfaces::msg::PositionCmd::SharedPtr msg);
    void velocity_cmd_callback(const whj_can_interfaces::msg::VelocityCmd::SharedPtr msg);
    
    bool wait_for_can_frame();
    void can_data_recv_callback();
    
    // CAN-FD send functions
    bool send_canfd_frame(uint32_t can_id, const uint8_t* data, uint8_t len);
    bool send_can_frame(uint32_t can_id, const uint8_t* data, uint8_t len);
    
    // Protocol helpers
    void parse_position_fb(const uint8_t* data, uint8_t len);
    void parse_status_fb(const uint8_t* data, uint8_t len);
};

} // namespace whj

#endif // __WHJ_CAN_CONTROL_NODE_H__
