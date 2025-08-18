#!/bin/bash
# Start ydotoold daemon if not running

if ! pgrep -x ydotoold >/dev/null; then
    echo "Starting ydotoold daemon..."
    echo "You may need to enter your password:"
    sudo ydotoold &
    sleep 2
    echo "ydotoold started"
else
    echo "ydotoold is already running"
fi