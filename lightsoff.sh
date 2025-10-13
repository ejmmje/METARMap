#!/bin/bash
# METARMap Lights Off Script
# Kills any existing METARMap processes and runs the LED shutdown script.
# Intended for use by cron to turn off LEDs at night or on shutdown.

# --- Setup ---
cd PLACEHOLDER_PROJECT_DIR || exit 1

# Environment variables (cron runs with a minimal environment)
export HOME=/home/ejmje
export PATH=/usr/local/bin:/usr/bin:/bin

# --- Logging ---
LOGFILE="PLACEHOLDER_PROJECT_DIR/off.log"
exec >> "$LOGFILE" 2>&1
echo "===== Lights Off started at $(date) ====="

# --- Kill old processes ---
pkill -F ./offpid.pid 2>/dev/null
pkill -F ./metarpid.pid 2>/dev/null

# --- Run LED shutdown script ---
# Capture both stdout and stderr from the Python process
./metarmap_env/bin/python3 ./pixelsoff.py >> pixelsoff.log 2>&1 &
echo $! > ./offpid.pid

echo "LED shutdown script started (PID $(cat ./offpid.pid))"
echo
