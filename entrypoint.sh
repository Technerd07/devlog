#!/bin/bash

#call the entrypoint script to invoke backend.sh to run in &
echo "Starting backend server [*]....."

bash /client-app/backend.sh &
BACKEND_PID=$!

echo "Starting client [*]....."
sleep 2
exec /client-app/cli.sh
