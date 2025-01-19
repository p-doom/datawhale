#!/bin/bash

# Function to start a service if it's not already running
start_service() {
  local service_name=$1
  local start_command=$2
  local health_check_url=$3
  local log_file=$4

  if ! pgrep -f "$service_name" >/dev/null; then
    echo "$service_name is not running. Starting $service_name..."
    mkdir -p "$(dirname "$log_file")"
    touch "$log_file"
    nohup $start_command &>"$log_file" &
    echo "Waiting for $service_name to become ready..."
    if [ "$service_name" == "grafana" ]; then
      until curl -s $health_check_url | grep -q "ok"; do
        sleep 1
      done
    elif [ "$service_name" == "prometheus" ]; then
      until curl -s -o /dev/null -w "%{http_code}" $health_check_url | grep -q "200"; do
        sleep 1
      done
    elif [ "$service_name" == "loki-linux-amd64" ]; then
      until curl -s $health_check_url | grep -q "ready"; do
        sleep 1
      done
    fi
    echo "$service_name started and is ready. Logs can be found in $log_file."
  else
    echo "$service_name is already running."
  fi
}

stop_service() {
  local service_name=$1

  if pgrep -f "$service_name" >/dev/null; then
    echo "Stopping $service_name..."
    pkill -f "$service_name"
    echo "$service_name stopped."
  else
    echo "$service_name is not running."
  fi
}

# Set environment variables
for ARGUMENT in "$@"; do
  if [[ "$ARGUMENT" == *"="* ]]; then
    IFS='=' read -r KEY VALUE <<<"$ARGUMENT"
    export "$KEY"="$VALUE"
  fi
done

set -e # Exit on any error

# Check for stop option
if [ "$1" == "stop" ]; then
  if [ "$ROLE" == "server" ]; then
    stop_service "grafana"
    stop_service "loki-linux-amd64"
    stop_service "prometheus"
  elif [ "$ROLE" == "client" ]; then
    stop_service "node_exporter"
    stop_service "dcgm-exporter"
    stop_service "nvml_exporter"
  else
    echo "Error: Unsupported role. Please use 'server' or 'client'."
    exit 1
  fi
  echo "All services have been stopped."
  exit 0
fi

# Check if MODE is standalone
if [ "$MODE" != "standalone" ]; then
  echo "Error: Only 'standalone' mode is currently supported."
  exit 1
fi

LOCAL_DIR=./local

if [ "$ROLE" == "server" ]; then
  # Start Grafana
  GRAFANA_FOLDER=$(find $LOCAL_DIR -maxdepth 1 -type d -name "grafana-v*" | head -n 1)
  GRAFANA_CONFIG=configs/grafana/grafana.ini
  GRAFANA_HTTP_PORT=$(grep -oP '(?<=http_port = )\d+' $GRAFANA_CONFIG)
  start_service "grafana" "$GRAFANA_FOLDER/bin/grafana server --homepath $GRAFANA_FOLDER --config=$GRAFANA_CONFIG" "http://localhost:$GRAFANA_HTTP_PORT/api/health" "logs/grafana.log"

  # Start Loki
  # TODO: debug loki starting not working
  LOKI_EXECUTABLE=$(find $LOCAL_DIR -maxdepth 1 -type f -name "loki-linux-amd64" | head -n 1)
  start_service "loki-linux-amd64" "$LOKI_EXECUTABLE -config.file=configs/loki/loki-config.yml" "http://localhost:3100/ready" "logs/loki.log"

  # Start Prometheus
  PROMETHEUS_FOLDER=$(find $LOCAL_DIR -maxdepth 1 -type d -name "prometheus-*" | head -n 1)
  # We never delete data, which is not an issue since we only collect metrics
  # during experiments. For our current use-case, writing to local disk is
  # enough, but we would need to configure remote write (or Thanos/Mimir) if our
  # metrics do not fit onto disk any more.
  PROMETHEUS_RETENTION_TIME=99999d
  start_service "prometheus" "$PROMETHEUS_FOLDER/prometheus --config.file=configs/prometheus/prometheus.yml --storage.tsdb.retention.time=$PROMETHEUS_RETENTION_TIME" "http://localhost:9090/-/ready" "logs/prometheus.log"
elif [ "$ROLE" == "client" ]; then
  # Start Node Exporter
  NODE_EXPORTER_FOLDER=$(find $LOCAL_DIR -maxdepth 1 -type d -name "node_exporter-*" | head -n 1)
  start_service "node_exporter" "$NODE_EXPORTER_FOLDER/node_exporter" "" "logs/node_exporter.log"

  # Add logic to start GPU Metrics Exporter
  if command -v dcgmi &>/dev/null; then
    # TODO: untested
    DCGM_EXPORTER_FOLDER=$(find $LOCAL_DIR -maxdepth 1 -type d -name "dcgm-exporter-*" | head -n 1)
    start_service "dcgm-exporter" "$DCGM_EXPORTER_FOLDER/dcgm-exporter" "" "logs/dcgm-exporter.log"
  else
    NVML_EXPORTER_EXECUTABLE=$(find $LOCAL_DIR -maxdepth 1 -type f -name "nvml_exporter-*" | head -n 1)
    start_service "nvml_exporter" "$NVML_EXPORTER_EXECUTABLE" "" "logs/nvml_exporter.log"
  fi
else
  echo "Error: Unsupported role. Please use 'server' or 'client'."
  exit 1
fi

echo "All services have been started."
