#!/bin/bash
trap 'kill -TERM $PID1 $PID2' TERM INT
ruby explore_client_9090.rb &
PID1=$!
$(cd server && ruby app.rb) &
PID2=$!
wait $PID1 $PID2 
trap - TERM INT
wait $PID1 $PID2 
EXIT_STATUS=$?

