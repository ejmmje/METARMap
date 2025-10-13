#!/bin/bash

# METARMap Lights Off Script
# This script kills any existing METARMap processes and runs the LED shutdown script.
# It is used by cron to turn off the LEDs at night or when shutting down.

# Kill any existing processes using their PID files
# This ensures clean shutdown before turning off LEDs
pkill -F ./offpid.pid  # Kill any existing pixelsoff.py process
pkill -F ./metarpid.pid  # Kill any existing metar.py process

# Run the LED shutdown script in the background
# Save the process ID to a file for future killing
./metarmap_env/bin/python3 ./pixelsoff.py & echo $! > ./offpid.pid
