#!/bin/bash

GRAFANA_FOLDER=$(find . -maxdepth 1 -type d -name "grafana-v*" | head -n 1)

# Check if Grafana is running
if ! pgrep -x "grafana" > /dev/null; then
    echo "Grafana is not running. Starting Grafana..."
    nohup $GRAFANA_FOLDER/bin/grafana server --homepath $GRAFANA_FOLDER &> /dev/null &
    echo "Waiting for Grafana to become ready..."
    # FIXME: this is hardcoded
    until curl -s http://localhost:3000/api/health | grep -q "ok"; do
        sleep 1
    done
    echo "Grafana started and is ready."
else
    echo "Grafana is already running."
fi

echo "Adding example dashboards to grafana..."
# Define variables
# FIXME: this is hardcoded
GRAFANA_URL="http://localhost:3000/api/dashboards/db"
ADMIN_USER="admin"
# TODO: change the default password
ADMIN_PASSWORD="admin"
DASHBOARD_DIR="examples/example_dashboards"

# Loop through each JSON file in the directory
for DASHBOARD_JSON_PATH in $DASHBOARD_DIR/*.json; do
    # Read the JSON file
    DASHBOARD_JSON=$(cat $DASHBOARD_JSON_PATH)

    # Create the payload
    PAYLOAD=$(jq -n --argjson dashboard "$DASHBOARD_JSON" '{"dashboard": $dashboard, "overwrite": true}')

    # Send the POST request to Grafana API using basic authentication
    curl -X POST $GRAFANA_URL \
         -H "Content-Type: application/json" \
         -u $ADMIN_USER:$ADMIN_PASSWORD \
         -d "$PAYLOAD"
done