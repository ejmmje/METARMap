#!/bin/bash

# METARMap Refresh Script
# This script kills any existing METARMap processes and starts a new instance.
# It is used by cron to refresh the weather data and LED display periodically.

# Kill any existing processes using their PID files
# This ensures clean shutdown before starting new processes
pkill -F ./offpid.pid  # Kill pixelsoff.py process if running
pkill -F ./metarpid.pid  # Kill metar.py process if running

# Start the main METARMap script in the background
# Save the process ID to a file for future killing
sudo ./metarmap_env/bin/python3 ./metar.py & echo $! > ./metarpid.pid
