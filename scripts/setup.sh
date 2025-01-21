#!/bin/bash

# You need to specify a MODE: docker, system, standalone.

set -e # Exit on any error

ENV_FILE='~/.env'

# Set environment variables
for ARGUMENT in "$@"; do
  IFS='=' read -r KEY VALUE <<<"$ARGUMENT"
  export "$KEY"="$VALUE"
done

if [ "$MODE" == "standalone" ]; then
  echo "Installing Prometheus, Grafana, and Loki as standalone executables..."

  # Determine OS
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')

  # Create a subdirectory for installations
  INSTALL_DIR="local"
  mkdir -p "$INSTALL_DIR"

  if [ "$ROLE" == "server" ]; then
    # Install Prometheus
    PROMETHEUS_LATEST=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -LO "https://github.com/prometheus/prometheus/releases/download/$PROMETHEUS_LATEST/prometheus-${PROMETHEUS_LATEST#v}.$OS-amd64.tar.gz"
    tar xvf "prometheus-${PROMETHEUS_LATEST#v}.$OS-amd64.tar.gz" -C "$INSTALL_DIR"
    rm -rf "prometheus-${PROMETHEUS_LATEST#v}.$OS-amd64.tar.gz"

    # Install Grafana
    GRAFANA_LATEST=$(curl -s https://api.github.com/repos/grafana/grafana/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed 's/^v//')
    curl -LO "https://dl.grafana.com/oss/release/grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"
    tar -zxvf "grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz" -C "$INSTALL_DIR"
    rm -rf "grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"

    # Install Loki
    LOKI_LATEST=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -LO "https://github.com/grafana/loki/releases/download/$LOKI_LATEST/loki-$OS-amd64.zip"
    unzip "loki-$OS-amd64.zip" -d "$INSTALL_DIR"
    rm -rf "loki-$OS-amd64.zip"
  elif [ "$ROLE" == "client" ]; then
    # Install Node Exporter
    NODE_EXPORTER_LATEST=$(curl -s https://api.github.com/repos/prometheus/node_exporter/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -LO "https://github.com/prometheus/node_exporter/releases/download/$NODE_EXPORTER_LATEST/node_exporter-${NODE_EXPORTER_LATEST#v}.$OS-amd64.tar.gz"
    tar xvf "node_exporter-${NODE_EXPORTER_LATEST#v}.$OS-amd64.tar.gz" -C "$INSTALL_DIR"
    rm -rf "node_exporter-${NODE_EXPORTER_LATEST#v}.$OS-amd64.tar.gz"

    # Install GPU Metrics Exporter
    if command -v dcgmi &>/dev/null; then
      # TODO: untested
      echo "DCGM is available. Installing dcgm-exporter..."
      DCGM_EXPORTER_LATEST=$(curl -s https://api.github.com/repos/NVIDIA/dcgm-exporter/releases/latest | grep 'tag_name' | cut -d\" -f4)
      DCGM_EXPORTER_URL="https://github.com/NVIDIA/dcgm-exporter/archive/refs/tags/$DCGM_EXPORTER_LATEST.tar.gz"
      curl -LO "$DCGM_EXPORTER_URL"
      tar -xzf "$DCGM_EXPORTER_LATEST.tar.gz" -C "$INSTALL_DIR"
      rm -rf "$DCGM_EXPORTER_LATEST.tar.gz"
    else
      echo "DCGM is not available. Installing nvml-exporter..."
      NVML_EXPORTER_LATEST=$(curl -s https://api.github.com/repos/p-doom/nvml_exporter/releases/latest | grep 'tag_name' | cut -d\" -f4)
      NVML_EXPORTER_URL="https://github.com/p-doom/nvidia_gpu_prometheus_exporter/releases/download/$NVML_EXPORTER_LATEST/nvml_exporter-$NVML_EXPORTER_LATEST-x86_64.tar.gz"
      curl -LO "$NVML_EXPORTER_URL"
      tar -xzf "nvml_exporter-$NVML_EXPORTER_LATEST-x86_64.tar.gz" -C "$INSTALL_DIR"
      rm -rf "nvml_exporter-$NVML_EXPORTER_LATEST-x86_64.tar.gz"
    fi
  else
    echo "Error: Unsupported role. Please use 'server' or 'client'."
    exit 1
  fi

  echo "Standalone installation complete!"
elif [ "$MODE" == "system" ]; then
  # Install using package manager
  echo "Installing Prometheus, Grafana, and Loki using package manager..."
  sudo apt-get update
  sudo apt-get install -y prometheus grafana loki

  # Restart services
  echo "Configuring Prometheus..."
  sudo systemctl restart prometheus

  echo "Configuring Loki..."
  sudo systemctl restart loki

  echo "Configuring Grafana..."
  sudo systemctl restart grafana

  echo "Installation complete!"
elif [ "$MODE" == "docker" ]; then
  # TODO: add Docker support
  echo "Error: Docker is currently not supported. Please use 'standalone' or 'system'."
  exit 1
else
  echo "Error: Unsupported mode. Please use 'standalone', 'system', or 'docker'."
  exit 1
fi

if [ "$ROLE" == "server" ]; then
  # Executing configuration script
  echo "Executing config.sh..."
  bash scripts/config.sh MODE=$MODE
fi

if [ "$ROLE" == "client" ]; then
  echo "Setting up reverse SSH tunnel to server..."
  export $(cat $(eval echo $ENV_FILE) | xargs)
  ssh -i "$ORCHESTRATOR_KEY" \
    -f -N \
    -R 9100:localhost:9100 \
    -R 9445:localhost:9445 \
    "$ORCHESTRATOR_ADDRESS"
fi
