from setuptools import find_packages, setup
import os

package_name = 'whj_can_py'

# Create wrapper script for libexec directory (ROS2 launch compatibility)
wrapper_script = '#!/bin/bash\nexec python3 -m whj_can_py.whj_can_node "$@"\n'
os.makedirs('bin', exist_ok=True)
with open('bin/whj_can_node', 'w') as f:
    f.write(wrapper_script)
os.chmod('bin/whj_can_node', 0o755)

setup(
    name=package_name,
    version='0.1.0',
    packages=find_packages(),
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        ('share/' + package_name + '/launch', ['launch/whj_can_py.launch.py']),
        # Install wrapper to lib/<package> for ROS2 launch compatibility
        ('lib/' + package_name, ['bin/whj_can_node']),
    ],
    install_requires=['setuptools', 'python-can'],
    zip_safe=True,
    maintainer='Blueberry Team',
    maintainer_email='xuhao6815@gmail.com',
    description='RealMan WHJ motor driver using Python (SocketCAN)',
    license='MIT',
    tests_require=['pytest'],
    entry_points={
        'console_scripts': [
            'whj_can_node = whj_can_py.whj_can_node:main',
        ],
    },
)
