#!/bin/bash
cd PLACEHOLDER_PROJECT_DIR || exit 1

# Environment variables (cron runs with a minimal environment)
export HOME=/home/$USER
export PATH=/usr/local/bin:/usr/bin:/bin


LOGFILE="PLACEHOLDER_PROJECT_DIR/refresh.log"
exec >> "$LOGFILE" 2>&1
echo "===== Refresh started at $(date) ====="

pkill -F ./offpid.pid 2>/dev/null
pkill -F ./metarpid.pid 2>/dev/null

# Truncate metar.log to prevent it from growing too large
> metar.log

./metarmap_env/bin/python3 ./metar.py >> metar.log 2>&1 &
echo $! > ./metarpid.pid
