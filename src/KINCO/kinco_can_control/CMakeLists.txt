cmake_minimum_required(VERSION 3.8)
project(kinco_can_control)

if(CMAKE_COMPILER_IS_GNUCXX OR CMAKE_CXX_COMPILER_ID MATCHES "Clang")
  add_compile_options(-Wall -Wextra -Wpedantic)
endif()

set(include_directories
    include
)

find_package(ament_cmake REQUIRED)
find_package(std_msgs REQUIRED)
find_package(rclcpp REQUIRED)
find_package(kinco_can_interfaces REQUIRED)

add_executable(kinco_can_control_node src/kinco_can_control_node.cpp)
target_include_directories(kinco_can_control_node PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>
  $<INSTALL_INTERFACE:include>)
target_compile_features(kinco_can_control_node PUBLIC c_std_99 cxx_std_17)
ament_target_dependencies(
  kinco_can_control_node
  "std_msgs"
  "rclcpp"
  "kinco_can_interfaces"
)

install(TARGETS kinco_can_control_node
  DESTINATION lib/${PROJECT_NAME})

install(DIRECTORY launch params
    DESTINATION share/${PROJECT_NAME})

if(BUILD_TESTING)
  find_package(ament_lint_auto REQUIRED)
  set(ament_cmake_copyright_FOUND TRUE)
  set(ament_cmake_cpplint_FOUND TRUE)
  ament_lint_auto_find_test_dependencies()
endif()

ament_package()
