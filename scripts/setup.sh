#!/bin/bash

# You need to specify a MODE: docker, system, standalone.

set -e  # Exit on any error

# Set environment variables
for ARGUMENT in "$@"; do
    IFS='=' read -r KEY VALUE <<< "$ARGUMENT"
    export "$KEY"="$VALUE"
done

if [ "$MODE" == "standalone" ]; then
    echo "Installing Prometheus, Grafana, and Loki as standalone executables..."

    # Determine OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')

    # Install Prometheus
    PROMETHEUS_LATEST=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -LO "https://github.com/prometheus/prometheus/releases/download/$PROMETHEUS_LATEST/prometheus-${PROMETHEUS_LATEST#v}.$OS-amd64.tar.gz"
    tar xvf "prometheus-${PROMETHEUS_LATEST#v}.$OS-amd64.tar.gz"
    rm -rf "prometheus-${PROMETHEUS_LATEST#v}.$OS-amd64.tar.gz"

    # Install Grafana
    GRAFANA_LATEST=$(curl -s https://api.github.com/repos/grafana/grafana/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed 's/^v//')
    curl -LO "https://dl.grafana.com/oss/release/grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"
    tar -zxvf "grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"
    rm -rf "grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"

    # Install Loki
    LOKI_LATEST=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -LO "https://github.com/grafana/loki/releases/download/$LOKI_LATEST/loki-$OS-amd64.zip"
    unzip "loki-$OS-amd64.zip"
    rm -rf "loki-$OS-amd64.zip"

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

# Executing configuration script
echo "Executing config.sh..."
bash scripts/config.sh