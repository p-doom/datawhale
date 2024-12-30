#!/bin/bash

echo "Adding example dashboards to grafana..."
# Define variables
GRAFANA_URL="http://localhost:3000/api/dashboards/db"
ADMIN_USER="admin"
# TODO: change the default password
ADMIN_PASSWORD="admin"
DASHBOARD_DIR="examples"

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