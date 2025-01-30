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

if [ "$ROLE" != "server" ] && [ "$ROLE" != "client" ]; then
  echo "Error: Unsupported role. Please use 'server' or 'client'."
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

# TODO: Add datawhale_dcgm.json
# An integrated dashboard visualizing DCGM metrics is on the roadmap.
# For now you can use nvidia's dcgm dashboard with the following dashboard id
DCGM_EXPORTER_DASHBOARD_ID=12239
DATAWHALE_NVML_DASHBOARD=dashboards/datawhale_nvml.json

ENV_FILE=~/.env

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

if [ "$ROLE" == "server" ]; then
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

  echo "Adding datawhale dashboard to grafana..."
  if command -v dcgmi &>/dev/null; then
    echo "An integrated datawhale DCGM dashboard is on the roadmap. Please manually add nvidia's DCGM dashboard for now:"
    echo "dashboard_id: $DCGM_EXPORTER_DASHBOARD_ID"
  else
    add_dashboard_by_file "$DATAWHALE_NVML_DASHBOARD"
  fi
elif [ "$ROLE" == "client" ]; then
  echo "[Grafana, Prometheus] Setting up reverse SSH tunnel to server..."
  source $ENV_FILE
  # FIXME: This is an ad-hoc workaround
  check_remote_port() {
    local port=$1
    ssh -o StrictHostKeyChecking=no -i "$ORCHESTRATOR_KEY" "$ORCHESTRATOR_ADDRESS" "nc -z localhost $port" &>/dev/null
    return $?
  }

  setup_ssh_tunnel() {
    local remote_port_1=9100
    local remote_port_2=9445

    while true; do
      if ! check_remote_port $remote_port_1 && ! check_remote_port $remote_port_2; then
        ssh -o StrictHostKeyChecking=no -i "$ORCHESTRATOR_KEY" \
          -f -N \
          -R $remote_port_1:localhost:9100 \
          -R $remote_port_2:localhost:9445 \
          "$ORCHESTRATOR_ADDRESS"
        break
      else
        echo "Remote ports $remote_port_1 or $remote_port_2 are occupied. Incrementing ports and retrying..."
        remote_port_1=$((remote_port_1 + 1))
        remote_port_2=$((remote_port_2 + 1))
      fi
    done
  }

  setup_ssh_tunnel
  echo "[Loki] Setting up SSH tunnel to server..."
  # TODO: Change loki-push to loki-pull & remove connection from client to server
  ssh -o StrictHostKeyChecking=no -f -N -i $ORCHESTRATOR_KEY $ORCHESTRATOR_ADDRESS -L 3100:localhost:3100
fi
