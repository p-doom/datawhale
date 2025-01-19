#!/bin/bash

set -e # Exit on any error

# Set environment variables
for ARGUMENT in "$@"; do
  IFS='=' read -r KEY VALUE <<<"$ARGUMENT"
  export "$KEY"="$VALUE"
done

# Check if MODE is standalone
if [ "$MODE" != "standalone" ]; then
  echo "Error: Only 'standalone' mode is currently supported."
  exit 1
fi

LOCAL_DIR=./local # FIXME: this only works for the standalone setup
GRAFANA_FOLDER=$(find $LOCAL_DIR -maxdepth 1 -type d -name "grafana-v*" | head -n 1)
GRAFANA_CONFIG=configs/grafana/grafana.ini
GRAFANA_HTTP_PORT=$(grep -oP '(?<=http_port = )\d+' $GRAFANA_CONFIG)
GRAFANA_URL="http://localhost:$GRAFANA_HTTP_PORT/"
GRAFANA_DASHBOARD_API="${GRAFANA_URL}api/dashboards/db"
GRAFANA_ADMIN_USER="admin"
GRAFANA_ADMIN_PASSWORD="admin" # TODO: change the default password

NODE_EXPORTER_DASHBOARD_ID=1860
DCGM_EXPORTER_DASHBOARD_ID=12239
NVML_EXPORTER_DASHBOARD_PATH=dashboards/nvml_exporter/nvml_exporter_dashboard.json
EXPERIMENT_DASHBOARD_DIR="dashboards/experiment"

add_dashboard_by_id() {
  local dashboard_id=$1
  local dashboard_url="https://grafana.com/api/dashboards/$dashboard_id/revisions/latest/download"
  local dashboard_json_file=$(mktemp)
  local payload_file=$(mktemp)

  curl -s $dashboard_url -o $dashboard_json_file

  jq -n --slurpfile dashboard "$dashboard_json_file" '{"dashboard": $dashboard[0], "overwrite": true}' >$payload_file

  curl -s -X POST $GRAFANA_DASHBOARD_API \
    -H "Content-Type: application/json" \
    -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD \
    --data-binary "@$payload_file"

  rm $dashboard_json_file
  rm $payload_file
}

add_dashboard_by_file() {
  local dashboard_json_file=$1
  local payload_file=$(mktemp)

  DASHBOARD_JSON=$(cat "$dashboard_json_file")

  jq -n --argjson dashboard "$DASHBOARD_JSON" '{"dashboard": $dashboard, "overwrite": true}' >$payload_file

  curl -s -X POST $GRAFANA_DASHBOARD_API \
    -H "Content-Type: application/json" \
    -u $GRAFANA_ADMIN_USER:$GRAFANA_ADMIN_PASSWORD \
    --data-binary "@$payload_file"

  rm $payload_file
}

# Check if Grafana is running
if ! pgrep -x "grafana" >/dev/null; then
  echo "Grafana is not running. Starting Grafana..."
  nohup $GRAFANA_FOLDER/bin/grafana server --homepath $GRAFANA_FOLDER --config=$GRAFANA_CONFIG &>/dev/null &
else
  echo "Grafana is already running."
fi
echo "Waiting for Grafana to become ready..."
until curl -s "${GRAFANA_URL}api/health" | grep -q "ok"; do
  sleep 1
done
echo "Grafana started and is ready."

echo "Adding example dashboards to grafana..."
for DASHBOARD_JSON_PATH in $EXPERIMENT_DASHBOARD_DIR/*.json; do
  add_dashboard_by_file "$DASHBOARD_JSON_PATH"
done

# Add node_exporter dashboard
echo "Adding node_exporter dashboard to grafana..."
add_dashboard_by_id "$NODE_EXPORTER_DASHBOARD_ID"

# Add dcgm_exporter || nvml_exporter dashboard
if command -v dcgmi &>/dev/null; then
  echo "Adding dcgm_exporter dashboard to grafana..."
  add_dashboard_by_id "$DCGM_EXPORTER_DASHBOARD_ID"
else
  echo "Adding nvml_exporter dashboard to grafana..."
  add_dashboard_by_file "$NVML_EXPORTER_DASHBOARD_PATH"
fi

