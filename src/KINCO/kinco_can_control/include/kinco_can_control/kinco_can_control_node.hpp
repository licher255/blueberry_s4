#ifndef __KINCO_CAN_CONTROL_NODE_H__
#define __KINCO_CAN_CONTROL_NODE_H__

#include <linux/can.h>
#include <linux/can/raw.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <cmath>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include "rclcpp/rclcpp.hpp"
#include "kinco_can_interfaces/msg/kinco_cmd.hpp"
#include "kinco_can_interfaces/msg/kinco_state.hpp"

#define READ_PARAM(TYPE, NAME, VAR, VALUE) \
  VAR = VALUE; \
  node->declare_parameter<TYPE>(NAME, VAR); \
  node->get_parameter(NAME, VAR);

namespace kinco {

class CanControlNode {
 public:
  explicit CanControlNode(rclcpp::Node::SharedPtr node);
  ~CanControlNode();

  bool run();
  void stop();

 private:
  rclcpp::Node::SharedPtr node_;

  // Parameters
  std::string if_name_;
  uint8_t node_id_;
  double state_publish_rate_;

  // CAN
  int can_socket_;
  std::thread recv_thread_;
  std::thread timer_thread_;
  bool running_;

  // State cache (protected by mutex)
  std::mutex state_mutex_;
  kinco_can_interfaces::msg::KincoState state_msg_;
  bool state_updated_;
  double target_position_cmd_;  // Target position from command

  // ROS interfaces
  rclcpp::Subscription<kinco_can_interfaces::msg::KincoCmd>::SharedPtr cmd_sub_;
  rclcpp::Publisher<kinco_can_interfaces::msg::KincoState>::SharedPtr state_pub_;

  // Protocol constants
  static constexpr uint32_t NMT_ID = 0x000;
  static constexpr uint32_t RPDO1_ID = 0x201;
  static constexpr uint32_t RPDO2_ID = 0x301;
  static constexpr uint32_t TPDO1_ID = 0x181;      // Status/Alarm
  static constexpr uint32_t TPDO2_ID = 0x281;      // Position/Velocity (per protocol doc)
  static constexpr uint32_t EMCY_ID_BASE = 0x081;
  static constexpr double GEAR_RATIO = 16380.0;    // 182 * 90 (per protocol doc)
  static constexpr double RPM_TO_UNITS = (65536.0 * 512.0) / 1875.0;

  // CAN I/O
  bool sendCanFrame(uint32_t can_id, const uint8_t* data, uint8_t len);
  void canDataRecvCallback();
  void timerLoop();

  // Motor control
  bool startNode();
  bool sendRpdo1(uint8_t control_low, uint8_t control_high, uint8_t mode);
  bool enableAbsoluteMode();
  bool disable();
  bool clearFault();
  bool setOrigin();
  bool moveToPosition(double degree, double rpm);
  bool stopMotion();

  // Callbacks
  void kincoCmdCallback(const kinco_can_interfaces::msg::KincoCmd::SharedPtr msg);
};

}  // namespace kinco

#endif
