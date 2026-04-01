std_msgs/Header header
uint8 node_id
float64 position_deg
float64 speed_rpm
bool is_enabled
uint16 error_code
bool target_reached
bool limit_reached

# Target tracking
float64 target_position_deg   # Commanded target position
float64 remaining_distance_deg  # Distance to target (target - current)
