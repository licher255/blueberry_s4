#ifndef __WHJ_CAN_CONTROL_NODE_H__
#define __WHJ_CAN_CONTROL_NODE_H__

#include <linux/can.h>
#include <linux/can/raw.h>
#include <net/if.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

#include "rclcpp/rclcpp.hpp"
#include "whj_can_interfaces/msg/whj_cmd.hpp"
#include "whj_can_interfaces/msg/whj_state.hpp"

#define READ_PARAM(TYPE, NAME, VAR, VALUE) \
  VAR = VALUE;                             \
  node->declare_parameter<TYPE>(NAME, VAR); \
  node->get_parameter(NAME, VAR);

namespace whj {

enum class Register : uint8_t {
  SYS_ID = 0x01,
  SYS_MODEL_TYPE = 0x02,
  SYS_FW_VERSION = 0x03,
  SYS_ERROR = 0x04,
  SYS_VOLTAGE = 0x05,
  SYS_TEMP = 0x06,
  SYS_REDU_RATIO = 0x07,
  SYS_ENABLE_DRIVER = 0x0A,
  SYS_ENABLE_ON_POWER = 0x0B,
  SYS_SAVE_TO_FLASH = 0x0C,
  SYS_SET_ZERO_POS = 0x0E,
  SYS_CLEAR_ERROR = 0x0F,
  CUR_CURRENT_L = 0x10,
  CUR_CURRENT_H = 0x11,
  CUR_SPEED_L = 0x12,
  CUR_SPEED_H = 0x13,
  CUR_POSITION_L = 0x14,
  CUR_POSITION_H = 0x15,
  TAG_WORK_MODE = 0x30,
  TAG_OPEN_PWM = 0x31,
  TAG_CURRENT_L = 0x32,
  TAG_CURRENT_H = 0x33,
  TAG_SPEED_L = 0x34,
  TAG_SPEED_H = 0x35,
  TAG_POSITION_L = 0x36,
  TAG_POSITION_H = 0x37,
  LIT_MAX_CURRENT = 0x40,
  LIT_MAX_SPEED = 0x41,
  LIT_MAX_ACC = 0x42,
  LIT_MAX_DEC = 0x43,
};

enum class WorkMode : uint8_t {
  OPEN_LOOP = 0,
  CURRENT_MODE = 1,
  SPEED_MODE = 2,
  POSITION_MODE = 3,
};

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
  uint8_t motor_id_;
  double state_publish_rate_;
  int timeout_ms_;
  int retry_count_;

  // CAN
  int can_socket_;
  std::thread timer_thread_;
  bool running_;



  // ROS interfaces
  rclcpp::Subscription<whj_can_interfaces::msg::WhjCmd>::SharedPtr cmd_sub_;
  rclcpp::Publisher<whj_can_interfaces::msg::WhjState>::SharedPtr state_pub_;

  // Protocol helpers
  static std::vector<uint8_t> buildReadFrame(Register reg, uint8_t count);
  static std::vector<uint8_t> buildWriteFrame(Register reg, uint16_t value);
  static int32_t toInt32(uint16_t low, uint16_t high);

  // CAN I/O
  bool sendCanFdFrame(uint32_t can_id, const uint8_t* data, uint8_t len);
  void clearReceiveBuffer();
  std::vector<uint8_t> sendCommandWithResponse(
      uint32_t can_id, const uint8_t* data, uint8_t len,
      uint32_t resp_id, int timeout_ms);
  std::vector<uint8_t> retryCommandWithResponse(
      uint32_t can_id, const uint8_t* data, uint8_t len,
      uint32_t resp_id, int timeout_ms);

  // Motor control
  bool initializeMotor();
  bool enableMotor(bool enable);
  bool clearError();
  bool setWorkMode(WorkMode mode);
  bool setZeroPosition();
  bool setTargetPosition(float position_deg);
  bool setTargetSpeed(float speed_rpm);
  bool setTargetCurrent(int32_t current_ma);
  float getPosition();
  whj_can_interfaces::msg::WhjState readFullState();

  // Callbacks
  void whjCmdCallback(const whj_can_interfaces::msg::WhjCmd::SharedPtr msg);
  void timerLoop();
};

}  // namespace whj

#endif
