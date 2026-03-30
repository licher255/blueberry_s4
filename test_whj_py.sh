#!/bin/bash
# Test script for WHJ Python driver

cd ~/Blueberry_s4
source install/setup.bash

echo "=== Building whj_can_py ==="
colcon build --packages-select whj_can_py --symlink-install

echo ""
echo "=== Starting WHJ Python Node ==="
echo "Interface: can2, Motor ID: 7"
echo ""

# Run node with timeout for testing
timeout 15 bash -c '
ros2 launch whj_can_py whj_can_py.launch.py can_interface:=can2 motor_id:=7 &
PID=$!

sleep 4
echo ""
echo "=== Initial State ==="
ros2 topic echo /whj_state --once 2>/dev/null

echo ""
echo "=== Testing Position Command ==="
TARGET=570.0
echo "Moving to $TARGET degrees..."
ros2 topic pub /whj_cmd whj_can_interfaces/msg/WhjCmd "{motor_id: 7, target_position_deg: $TARGET}" --once 2>/dev/null

sleep 0.5
echo ""
echo "=== Monitoring (5 seconds) ==="
for i in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.5
    state=$(ros2 topic echo /whj_state --once 2>/dev/null | grep -E "position_deg:")
    echo "  $state"
done

kill $PID 2>/dev/null
wait $PID 2>/dev/null
'

echo ""
echo "=== Test Complete ==="
