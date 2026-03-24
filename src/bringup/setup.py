from setuptools import find_packages, setup
import os
from glob import glob

package_name = 'bringup'

setup(
    name=package_name,
    version='0.1.0',
    packages=find_packages(exclude=['test']),
    py_modules=[],
    data_files=[
        ('share/ament_index/resource_index/packages',
            ['resource/' + package_name]),
        ('share/' + package_name, ['package.xml']),
        # 包含 launch 文件
        (os.path.join('share', package_name, 'launch'), 
         glob('launch/*.py')),
        # 包含 config 文件
        (os.path.join('share', package_name, 'config'), 
         glob('config/*.yaml')),
        # 包含 layouts 文件
        (os.path.join('share', package_name, 'layouts'), 
         glob('layouts/*.json')),
    ],
    install_requires=['setuptools'],
    zip_safe=True,
    maintainer='Blueberry Team',
    maintainer_email='your@email.com',
    description='S4 Bringup Package',
    license='MIT',
    extras_require={
        'test': ['pytest'],
    },
    entry_points={
        'console_scripts': [
        ],
    },
)
