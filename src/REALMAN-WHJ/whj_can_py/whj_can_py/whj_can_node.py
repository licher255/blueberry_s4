#!/usr/bin/env python3
"""
ROS2 Node for RealMan WHJ Motor using Python SocketCAN Driver

This node wraps the Python driver and exposes ROS2 topics:
- Publishers:
  - /whj_state (whj_can_interfaces/msg/WhjState): Motor state feedback
- Subscribers:
  - /whj_cmd (whj_can_interfaces/msg/WhjCmd): Motor command

Usage:
    ros2 run whj_can_py whj_can_node
    ros2 launch whj_can_py whj_can_py.launch.py
"""

import rclpy
from rclpy.node import Node
from rclpy.qos import QoSProfile, ReliabilityPolicy, HistoryPolicy
import threading
import time
import math

from whj_can_interfaces.msg import WhjState, WhjCmd

# Import our Python driver (using SocketCAN)
from .core.socketcan_driver import SocketCanDriver
from .drivers.whj_driver import WHJDriver, WorkMode, MotionProfile


class WHJCanNode(Node):
    """ROS2 node for WHJ motor control using Python SocketCAN driver"""
    
    def __init__(self):
        super().__init__('whj_can_py_node')
        
        # Parameters
        self.declare_parameter('can_interface', 'can_fd')  # SocketCAN interface name
        self.declare_parameter('motor_id', 7)
        self.declare_parameter('state_publish_rate', 10.0)  # Hz
        self.declare_parameter('auto_enable', True)
        self.declare_parameter('init_timeout_ms', 2000)
        # Motion profile parameters (for smooth trajectory)
        self.declare_parameter('max_velocity', 1000.0)  # degrees/s
        self.declare_parameter('max_acceleration', 2000.0)  # degrees/s^2
        
        self.can_interface = self.get_parameter('can_interface').value
        self.motor_id = self.get_parameter('motor_id').value
        self.publish_rate = self.get_parameter('state_publish_rate').value
        self.auto_enable = self.get_parameter('auto_enable').value
        self.init_timeout_ms = self.get_parameter('init_timeout_ms').value
        self.max_velocity = self.get_parameter('max_velocity').value
        self.max_acceleration = self.get_parameter('max_acceleration').value
        
        # CAN driver and motor driver
        self.can_driver: SocketCanDriver = None
        self.motor: WHJDriver = None
        
        # State
        self.running = False
        self.publish_thread = None
        self.motion_thread = None
        self._motion_stop_event = threading.Event()
        # Track enabled state (since reading it can fail)
        self._is_enabled_cached = False
        
        # QoS
        qos = QoSProfile(
            reliability=ReliabilityPolicy.RELIABLE,
            history=HistoryPolicy.KEEP_LAST,
            depth=10
        )
        
        # Publishers
        self.state_pub = self.create_publisher(WhjState, 'whj_state', qos)
        
        # Subscribers
        self.cmd_sub = self.create_subscription(
            WhjCmd, 'whj_cmd', self.cmd_callback, qos)
        
        # Initialize
        if not self.init_can():
            self.get_logger().error("Failed to initialize CAN")
            return
        
        if not self.init_motor():
            self.get_logger().error("Failed to initialize motor")
            return
        
        # Start publish thread
        self.running = True
        self.publish_thread = threading.Thread(target=self.publish_loop)
        self.publish_thread.start()
        
        self.get_logger().info(f"WHJ Python Node initialized (motor_id={self.motor_id})")
    
    def init_can(self) -> bool:
        """Initialize SocketCAN interface"""
        try:
            self.can_driver = SocketCanDriver(self.can_interface)
            
            # Open interface
            if not self.can_driver.open():
                self.get_logger().error(f"Failed to open {self.can_interface}")
                return False
            
            # Initialize CAN-FD: 1M nominal, 5M data bitrate
            if not self.can_driver.init_canfd(
                    nominal_bitrate=1000000,  # 1M
                    data_bitrate=5000000,     # 5M
                    use_brs=True):            # Bitrate switching
                self.get_logger().error("Failed to initialize CAN-FD")
                return False
            
            self.get_logger().info(f"SocketCAN-FD initialized on {self.can_interface}")
            return True
            
        except Exception as e:
            self.get_logger().error(f"CAN init exception: {e}")
            return False
    
    def init_motor(self) -> bool:
        """Initialize WHJ motor"""
        try:
            # Create motion profile with conservative parameters
            # This prevents errors when moving large distances
            profile = MotionProfile(
                max_velocity=self.max_velocity,       # degrees/s
                max_acceleration=self.max_acceleration,  # degrees/s^2
                max_deceleration=self.max_acceleration
            )
            self.motor = WHJDriver(self.can_driver, self.motor_id, profile=profile)
            self.get_logger().info(f"Motion profile: max_vel={self.max_velocity}°/s, max_acc={self.max_acceleration}°/s²")
            
            # Initialize (ping)
            self.get_logger().info(f"Pinging motor {self.motor_id}...")
            if not self.motor.initialize():
                self.get_logger().error("Motor initialization failed - check:")
                self.get_logger().error("  1. CAN interface is up: sudo ip link set can_fd up")
                self.get_logger().error("  2. Motor is powered on")
                self.get_logger().error("  3. Motor ID is correct")
                return False
            
            # Auto-enable if requested
            if self.auto_enable:
                self.get_logger().info("Auto-enabling motor...")
                
                # First set work mode to position mode
                self.get_logger().info("Setting position mode...")
                if self.motor.set_work_mode(WorkMode.POSITION_MODE):
                    time.sleep(0.2)
                    # Then enable
                    if self.motor.enable():
                        self._is_enabled_cached = True
                        self.get_logger().info("Motor enabled in position mode")
                        time.sleep(0.1)
                    else:
                        self.get_logger().warn("Failed to enable motor")
                else:
                    self.get_logger().warn("Failed to set position mode")
            
            return True
            
        except Exception as e:
            self.get_logger().error(f"Motor init exception: {e}")
            import traceback
            self.get_logger().debug(traceback.format_exc())
            return False
    
    def publish_loop(self):
        """Background thread for publishing state"""
        period = 1.0 / self.publish_rate
        
        while self.running and rclpy.ok():
            try:
                state_msg = self.read_state()
                if state_msg:
                    state_msg.header.stamp = self.get_clock().now().to_msg()
                    state_msg.header.frame_id = 'whj_link'
                    self.state_pub.publish(state_msg)
                
                time.sleep(period)
                
            except Exception as e:
                self.get_logger().error(f"Publish loop error: {e}")
                time.sleep(0.1)
    
    def read_state(self) -> WhjState:
        """Read full state from motor"""
        msg = WhjState()
        msg.motor_id = self.motor_id
        
        # Default values (NaN for unknown) - Web dashboard will ignore NaN
        msg.position_deg = float('nan')
        msg.speed_rpm = float('nan')
        msg.current_ma = float('nan')
        msg.voltage_v = float('nan')
        msg.temperature_c = float('nan')
        msg.error_code = 0
        # Use cached enabled status as default (not False)
        msg.is_enabled = self._is_enabled_cached
        msg.work_mode = 0
        
        if not self.motor:
            return msg
        
        try:
            from .core.protocol import WHJProtocol, Register
            
            # Read enabled status FIRST (before other operations)
            # This ensures we get the actual state even if other reads fail
            enabled = self.motor.is_enabled()
            if enabled is not None:
                msg.is_enabled = enabled
                self._is_enabled_cached = enabled  # Update cache
            else:
                # Keep cached value if read fails
                msg.is_enabled = self._is_enabled_cached
            
            # Read position
            cmd = WHJProtocol.build_read_frame(self.motor_id, Register.CUR_POSITION_L, 2)
            resp, err = self.motor.send_command(cmd)
            if resp and len(resp) >= 6:
                pos_low = resp[2] | (resp[3] << 8)
                pos_high = resp[4] | (resp[5] << 8)
                pos_raw = (pos_high << 16) | pos_low
                if pos_raw & 0x80000000:
                    pos_raw -= 0x100000000
                msg.position_deg = pos_raw * 0.0001
            
            # Read current
            cmd = WHJProtocol.build_read_frame(self.motor_id, Register.CUR_CURRENT_L, 2)
            resp, err = self.motor.send_command(cmd)
            if resp and len(resp) >= 6:
                cur_low = resp[2] | (resp[3] << 8)
                cur_high = resp[4] | (resp[5] << 8)
                cur_raw = (cur_high << 16) | cur_low
                if cur_raw & 0x80000000:
                    cur_raw -= 0x100000000
                msg.current_ma = float(cur_raw)
            
            # Read speed
            cmd = WHJProtocol.build_read_frame(self.motor_id, Register.CUR_SPEED_L, 2)
            resp, err = self.motor.send_command(cmd)
            if resp and len(resp) >= 6:
                spd_low = resp[2] | (resp[3] << 8)
                spd_high = resp[4] | (resp[5] << 8)
                spd_raw = (spd_high << 16) | spd_low
                if spd_raw & 0x80000000:
                    spd_raw -= 0x100000000
                msg.speed_rpm = (spd_raw * 0.02) / 6.0
            
            # Read voltage and temperature
            cmd = WHJProtocol.build_read_frame(self.motor_id, Register.SYS_VOLTAGE, 2)
            resp, err = self.motor.send_command(cmd)
            if resp and len(resp) >= 6:
                voltage_raw = resp[2] | (resp[3] << 8)
                temp_raw = resp[4] | (resp[5] << 8)
                msg.voltage_v = voltage_raw * 0.01
                msg.temperature_c = temp_raw * 0.1
            
            # Read error code
            cmd = WHJProtocol.build_read_frame(self.motor_id, Register.SYS_ERROR, 1)
            resp, err = self.motor.send_command(cmd)
            if resp and len(resp) >= 4:
                msg.error_code = resp[2] | (resp[3] << 8)
            
        except Exception as e:
            self.get_logger().debug(f"Read state error: {e}")
        
        return msg
    
    def cmd_callback(self, msg: WhjCmd):
        """Handle command messages"""
        if msg.motor_id != self.motor_id:
            self.get_logger().warn(f"Command for motor {msg.motor_id}, we are {self.motor_id}")
            return
        
        if not self.motor:
            self.get_logger().error("Motor not initialized")
            return
        
        try:
            # Clear error
            if msg.clear_error:
                if self.motor.clear_error():
                    self.get_logger().info("Error cleared")
                else:
                    self.get_logger().warn("Failed to clear error")
            
            # Set zero position
            if msg.set_zero:
                self.get_logger().info("Set zero position requested")
                from .core.protocol import WHJProtocol, Register
                cmd = WHJProtocol.build_write_frame(self.motor_id, 
                                                     Register.SYS_SET_ZERO_POS, 1)
                resp, err = self.motor.send_command(cmd)
                if resp:
                    self.get_logger().info("Zero position set")
                else:
                    self.get_logger().warn(f"Failed to set zero: {err}")
            
            # Set work mode (only if explicitly set, 0 is a valid mode so check if it was intentional)
            # We consider it intentional if work_mode > 0 or if it's the only field set
            if msg.work_mode > 0 and msg.work_mode <= 3:
                mode = WorkMode(msg.work_mode)
                self.get_logger().info(f"Setting work mode to {mode.name} ({msg.work_mode})...")
                if self.motor.set_work_mode(mode):
                    self.get_logger().info(f"Work mode set to {mode.name}")
                else:
                    self.get_logger().warn("Failed to set work mode")
            
            # Set target position
            if msg.target_position_deg == msg.target_position_deg:  # Not NaN
                self.get_logger().info(f"Commanded position {msg.target_position_deg}°")
                # Use trajectory planning for smooth motion (non-blocking)
                # This prevents errors when target is far from current position
                self._start_motion(msg.target_position_deg)
            
            # Enable/disable (only if explicitly requested)
            # Note: msg.enable defaults to false, so we only act if it's explicitly set
            # We detect this by checking if other fields are set (indicating intentional command)
            is_intentional_command = (
                msg.target_position_deg == msg.target_position_deg or  # Not NaN
                msg.target_speed_rpm == msg.target_speed_rpm or
                msg.target_current_ma == msg.target_current_ma or
                msg.clear_error or
                msg.set_zero or
                msg.work_mode > 0
            )
            
            # Handle enable/disable
            if msg.enable:
                # Enable request
                if self.motor.enable():
                    self._is_enabled_cached = True
                    self.get_logger().info("Motor enabled")
                else:
                    self.get_logger().warn("Failed to enable motor")
            elif not msg.enable and not is_intentional_command:
                # This is a disable-only command (enable=false, nothing else set)
                self.motor.disable()
                self._is_enabled_cached = False
                self.get_logger().info("Motor disabled")
                        
        except Exception as e:
            self.get_logger().error(f"Command error: {e}")
    
    def _start_motion(self, target_deg: float):
        """Start motion in background thread with trajectory planning"""
        # Stop any existing motion
        if self.motion_thread and self.motion_thread.is_alive():
            self._motion_stop_event.set()
            self.motion_thread.join(timeout=1.0)
        
        self._motion_stop_event.clear()
        self.motion_thread = threading.Thread(
            target=self._motion_worker, 
            args=(target_deg,),
            daemon=True
        )
        self.motion_thread.start()
    
    def _motion_worker(self, target_deg: float):
        """Background thread for smooth motion with trapezoidal trajectory"""
        try:
            # Get current position
            current_pos = self.motor.get_position()
            if current_pos is None:
                self.get_logger().error("Cannot read current position for motion planning")
                return
            
            distance = target_deg - current_pos
            if abs(distance) < 0.5:
                self.get_logger().info("Already at target position")
                return
            
            # Trapezoidal profile parameters
            max_vel = self.max_velocity  # deg/s
            max_acc = self.max_acceleration  # deg/s^2
            update_rate = 100  # Hz
            
            # Calculate trajectory timing
            t_acc = max_vel / max_acc
            d_acc = 0.5 * max_acc * t_acc * t_acc
            abs_dist = abs(distance)
            
            if 2 * d_acc >= abs_dist:
                # Triangular profile (cannot reach max velocity)
                t_total = 2 * math.sqrt(abs_dist / max_acc)
            else:
                # Trapezoidal profile
                t_const = (abs_dist - 2 * d_acc) / max_vel
                t_total = 2 * t_acc + t_const
            
            self.get_logger().info(
                f"Trajectory: {current_pos:.1f}° -> {target_deg:.1f}° "
                f"(dist={abs_dist:.1f}°, time={t_total:.2f}s)"
            )
            
            start_time = time.time()
            direction = 1 if distance > 0 else -1
            
            while not self._motion_stop_event.is_set():
                t = time.time() - start_time
                if t >= t_total:
                    # Send final position
                    self.motor.set_target_position(target_deg)
                    self.get_logger().info(f"Motion complete: {target_deg:.2f}°")
                    break
                
                # Calculate interpolated position
                if t < t_acc:
                    # Acceleration phase
                    s = 0.5 * max_acc * t * t
                elif t < (t_total - t_acc):
                    # Constant velocity phase
                    s = d_acc + max_vel * (t - t_acc)
                else:
                    # Deceleration phase
                    remaining_t = t_total - t
                    s = abs_dist - 0.5 * max_acc * remaining_t * remaining_t
                
                current_target = current_pos + direction * s
                
                # Send position command (high rate, no wait for response)
                self.motor.set_target_position(current_target)
                
                time.sleep(1.0 / update_rate)
            
            # Final position set
            time.sleep(0.05)
            final_pos = self.motor.get_position()
            if final_pos:
                err = abs(final_pos - target_deg)
                self.get_logger().info(f"Final position: {final_pos:.2f}° (error: {err:.2f}°)")
                
        except Exception as e:
            self.get_logger().error(f"Motion error: {e}")
    
    def destroy_node(self):
        """Cleanup on shutdown"""
        self.get_logger().info("Shutting down...")
        self.running = False
        
        # Stop motion thread
        if self.motion_thread and self.motion_thread.is_alive():
            self._motion_stop_event.set()
            self.motion_thread.join(timeout=2.0)
        
        if self.publish_thread:
            self.publish_thread.join(timeout=2.0)
        
        if self.motor:
            try:
                self.motor.disable()
            except:
                pass
        
        if self.can_driver:
            try:
                self.can_driver.close()
            except:
                pass
        
        super().destroy_node()


def main(args=None):
    rclpy.init(args=args)
    node = WHJCanNode()
    
    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        node.get_logger().info("Interrupted by user")
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()
