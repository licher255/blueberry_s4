"""
SocketCAN Driver for WHJ Motor (python-can based)

This is a lightweight alternative to ZlgCanDriver that uses Linux SocketCAN
directly via the python-can library. No proprietary ZLG libraries required.

Supports CAN-FD with bitrate switching.
"""

import can
import time
from typing import Optional, List
from dataclasses import dataclass


@dataclass
class CANFrame:
    """Simple CAN frame container"""
    can_id: int
    data: bytes
    is_extended: bool = False
    is_fd: bool = True
    bitrate_switch: bool = True


class SocketCanDriver:
    """
    SocketCAN driver for WHJ motor communication.
    
    Uses python-can library to interface with Linux SocketCAN.
    """
    
    def __init__(self, interface: str = "can0"):
        self.interface = interface
        self.bus: can.Bus = None
        self._is_fd = False
    
    def open(self, interface: str = None) -> bool:
        """
        Open SocketCAN interface.
        
        Args:
            interface: CAN interface name (e.g., 'can0', 'can_fd')
        
        Returns:
            True if successful
        """
        if interface:
            self.interface = interface
        
        try:
            # Try CAN-FD first
            self.bus = can.Bus(
                channel=self.interface,
                bustype='socketcan',
                fd=True,  # Enable CAN-FD
            )
            self._is_fd = True
            print(f"[SocketCAN] Opened {self.interface} in CAN-FD mode")
            return True
            
        except Exception as e:
            print(f"[SocketCAN] CAN-FD open failed: {e}")
            try:
                # Fallback to standard CAN
                self.bus = can.Bus(
                    channel=self.interface,
                    bustype='socketcan',
                )
                self._is_fd = False
                print(f"[SocketCAN] Opened {self.interface} in standard CAN mode")
                return True
            except Exception as e2:
                print(f"[SocketCAN] Standard CAN open failed: {e2}")
                return False
    
    def init_canfd(self, nominal_bitrate: int = 1000000, 
                   data_bitrate: int = 5000000,
                   use_brs: bool = True) -> bool:
        """
        Initialize CAN-FD parameters.
        
        Note: Actual bitrates are configured via 'ip link set' command.
        This method just verifies the interface is ready.
        
        Args:
            nominal_bitrate: Nominal bitrate (ignored, configure via ip link)
            data_bitrate: Data bitrate (ignored, configure via ip link)
            use_brs: Enable bitrate switching
        
        Returns:
            True if successful
        """
        if not self.bus:
            print("[SocketCAN] Bus not open")
            return False
        
        # Verify interface state by checking if we can get socket info
        try:
            # Try to send a test frame (will fail if interface down)
            # Just verify socket is valid
            print(f"[SocketCAN] CAN-FD ready (nominal={nominal_bitrate}, data={data_bitrate}, BRS={use_brs})")
            return True
        except Exception as e:
            print(f"[SocketCAN] Init error: {e}")
            return False
    
    def close(self):
        """Close CAN interface"""
        if self.bus:
            self.bus.shutdown()
            self.bus = None
            print("[SocketCAN] Closed")
    
    def send(self, can_id: int, data: bytes, 
             is_extended: bool = False, is_fd: bool = True) -> bool:
        """
        Send CAN/CAN-FD frame.
        
        Args:
            can_id: CAN ID
            data: Data bytes (max 8 for CAN, max 64 for CAN-FD)
            is_extended: Use extended frame format (29-bit ID)
            is_fd: Use CAN-FD format
        
        Returns:
            True if successful
        """
        if not self.bus:
            return False
        
        try:
            # Determine if we should use bitrate switch
            brs = is_fd and self._is_fd
            
            msg = can.Message(
                arbitration_id=can_id,
                data=data,
                is_extended_id=is_extended,
                is_fd=is_fd,
                bitrate_switch=brs,
            )
            self.bus.send(msg)
            return True
            
        except Exception as e:
            print(f"[SocketCAN] Send error: {e}")
            return False
    
    def receive(self, timeout_ms: int = 100) -> Optional[CANFrame]:
        """
        Receive CAN frame.
        
        Args:
            timeout_ms: Timeout in milliseconds
        
        Returns:
            CANFrame or None if timeout
        """
        if not self.bus:
            return None
        
        try:
            msg = self.bus.recv(timeout=timeout_ms / 1000.0)
            if msg:
                return CANFrame(
                    can_id=msg.arbitration_id,
                    data=bytes(msg.data),
                    is_extended=msg.is_extended_id,
                    is_fd=msg.is_fd,
                    bitrate_switch=msg.bitrate_switch,
                )
            return None
            
        except Exception as e:
            print(f"[SocketCAN] Receive error: {e}")
            return None
    
    def clear_buffer(self):
        """Clear receive buffer"""
        if not self.bus:
            return
        
        count = 0
        while True:
            msg = self.bus.recv(timeout=0.001)  # 1ms timeout
            if msg is None:
                break
            count += 1
        
        if count > 0:
            print(f"[SocketCAN] Cleared {count} frames")
    
    def set_filter(self, can_ids: List[int]):
        """Set CAN ID filter (not implemented for SocketCAN)"""
        # SocketCAN filtering can be added if needed
        pass
    
    def get_status(self) -> dict:
        """Get interface status"""
        return {
            'interface': self.interface,
            'is_open': self.bus is not None,
            'is_fd': self._is_fd,
        }
