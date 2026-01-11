#!/bin/bash

# **Purpose**: Provides auto-reconnecting port-forward for the application.

# **Features**:
# - Automatically restarts when connection drops
# - Survives pod restarts during ArgoCD syncs
# - Filters out "Handling connection" spam
# - Shows timestamp for each reconnection

NAMESPACE="dev"
SERVICE="wil-playground-service"
PORT="8888"

echo "Starting auto-reconnecting port-forward on port $PORT..."
echo "Press Ctrl+C to stop"
echo ""

while true; do
    echo "[$(date +%H:%M:%S)] Starting port-forward..."
    kubectl port-forward -n $NAMESPACE svc/$SERVICE $PORT:$PORT 2>&1 | grep -v "Handling connection"

    # If we get here, port-forward died
    echo "[$(date +%H:%M:%S)] Port-forward disconnected, reconnecting in 3 seconds..."
    sleep 3
done
