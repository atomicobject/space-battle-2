#!/bin/bash
trap "exit" INT TERM
trap "kill 0" EXIT
ruby explore_client_9090.rb &
$(cd server && ruby src/app.rb) &
wait
