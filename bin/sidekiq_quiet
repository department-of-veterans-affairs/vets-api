#!/bin/bash

# Find Pid
SIDEKIQ_PID=$(ps aux | grep sidekiq | grep busy | awk '{ print $2 }')
# Send TSTP signal
kill -SIGTSTP $SIDEKIQ_PID
