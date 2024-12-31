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
    PROMETHEUS_LATEST=$(curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed 's/^v//')
    curl -LO "https://github.com/prometheus/prometheus/releases/download/$PROMETHEUS_LATEST/prometheus-$PROMETHEUS_LATEST.$OS-amd64.tar.gz"
    tar xvf "prometheus-$PROMETHEUS_LATEST.$OS-amd64.tar.gz"
    sudo cp -r "prometheus-$PROMETHEUS_LATEST.$OS-amd64" /usr/local/prometheus
    rm -rf "prometheus-$PROMETHEUS_LATEST.$OS-amd64"*

    # Create symbolic link for Prometheus
    sudo ln -s /usr/local/prometheus/prometheus /usr/local/bin/prometheus

    # Install Grafana
    GRAFANA_LATEST=$(curl -s https://api.github.com/repos/grafana/grafana/releases/latest | grep 'tag_name' | cut -d\" -f4 | sed 's/^v//')
    curl -LO "https://dl.grafana.com/oss/release/grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"
    tar -zxvf "grafana-$GRAFANA_LATEST.$OS-amd64.tar.gz"
    sudo cp -r "grafana-$GRAFANA_LATEST" /usr/local/grafana
    rm -rf "grafana-$GRAFANA_LATEST"*

    # Create symbolic link for Grafana
    sudo ln -s /usr/local/grafana/bin/grafana /usr/local/bin/grafana

    # Install Loki
    LOKI_LATEST=$(curl -s https://api.github.com/repos/grafana/loki/releases/latest | grep 'tag_name' | cut -d\" -f4)
    curl -LO "https://github.com/grafana/loki/releases/download/$LOKI_LATEST/loki-$OS-amd64.zip"
    unzip "loki-$OS-amd64.zip"
    sudo cp "loki-$OS-amd64" /usr/local/bin/loki
    rm "loki-$OS-amd64.zip"
    rm "loki-$OS-amd64"

    # Copy configuration files to /usr/local
    # TODO: the configs don't exist yet
    echo "Copying configuration files to /usr/local..."
    sudo mkdir -p /usr/local/prometheus/configs
    sudo cp ./configs/prometheus/prometheus.yml /usr/local/prometheus/configs/prometheus.yml

    sudo mkdir -p /usr/local/loki/configs
    sudo cp ./configs/loki/loki-config.yaml /usr/local/loki/configs/loki-config.yaml

    sudo mkdir -p /usr/local/grafana/configs
    sudo cp ./configs/grafana/datasources.yml /usr/local/grafana/configs/datasources.yml
    sudo cp -r ./configs/grafana/dashboards /usr/local/grafana/configs/dashboards/

    echo "Standalone installation complete!"
elif [ "$MODE" == "system" ]; then
    # Install using package manager
    echo "Installing Prometheus, Grafana, and Loki using package manager..."
    sudo apt-get update
    sudo apt-get install -y prometheus grafana loki

    # Copy configuration files to /etc
    echo "Copying configuration files to /etc..."
    sudo cp ./configs/prometheus/prometheus.yml /etc/prometheus/prometheus.yml
    sudo cp ./configs/loki/loki-config.yaml /etc/loki/config.yaml
    sudo cp ./configs/grafana/datasources.yml /etc/grafana/provisioning/datasources/datasources.yml
    sudo cp -r ./configs/grafana/dashboards /etc/grafana/provisioning/dashboards/

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