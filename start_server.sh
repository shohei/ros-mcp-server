#!/bin/bash
source /opt/ros/jazzy/setup.bash
export ROS_DOMAIN_ID=7
cd /home/parallels/ros-mcp-server
exec /home/parallels/.local/bin/uv run server.py
