"""
Motor Drivers

电机驱动模块，提供统一的高层控制接口。

Drivers:
    WHJDriver: RealMan WHJ关节电机驱动 (CAN FD)
"""

from .base_driver import BaseMotorDriver, MotorState
from .whj_driver import WHJDriver, MotionProfile, TrapezoidalPlanner

__all__ = [
    # Base
    'BaseMotorDriver',
    'MotorState',
    # WHJ (RealMan WHJ关节电机)
    'WHJDriver',
    'MotionProfile',
    'TrapezoidalPlanner',
]
