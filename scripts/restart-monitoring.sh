#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Restarting Monitoring Services ===${RESET}"

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${RESET}"
    exit 1
fi

# Restart Prometheus
echo -e "${YELLOW}Restarting Prometheus...${RESET}"
PROMETHEUS_CONTAINER=$(docker ps | grep prometheus | awk '{print $1}')
if [ -z "$PROMETHEUS_CONTAINER" ]; then
    echo -e "${RED}Error: Prometheus container not found${RESET}"
else
    docker restart $PROMETHEUS_CONTAINER
    echo -e "${GREEN}Prometheus restarted${RESET}"
fi

# Wait for Prometheus to start
echo -e "${YELLOW}Waiting for Prometheus to start...${RESET}"
sleep 5

# Restart Grafana
echo -e "${YELLOW}Restarting Grafana...${RESET}"
GRAFANA_CONTAINER=$(docker ps | grep grafana | awk '{print $1}')
if [ -z "$GRAFANA_CONTAINER" ]; then
    echo -e "${RED}Error: Grafana container not found${RESET}"
else
    docker restart $GRAFANA_CONTAINER
    echo -e "${GREEN}Grafana restarted${RESET}"
fi

# Wait for Grafana to start
echo -e "${YELLOW}Waiting for Grafana to start...${RESET}"
sleep 5

# Restart Kafka containers
echo -e "${YELLOW}Restarting Kafka containers...${RESET}"
KAFKA_CONTAINERS=$(docker ps | grep kafka | awk '{print $1}')
if [ -z "$KAFKA_CONTAINERS" ]; then
    echo -e "${RED}Error: No Kafka containers found${RESET}"
else
    for container in $KAFKA_CONTAINERS; do
        echo -e "${YELLOW}Restarting container: $container${RESET}"
        docker restart $container
        echo -e "${GREEN}Container $container restarted${RESET}"
        sleep 1
    done
fi

echo -e "${GREEN}All monitoring services restarted${RESET}"
echo -e "${YELLOW}You can now access:${RESET}"
echo -e "Grafana: http://localhost:3000 (admin/admin123)"
echo -e "Prometheus: http://localhost:9090"
echo -e "Consumer Metrics: http://localhost:8000/metrics"

echo -e "${BLUE}=== Restart Complete ===${RESET}"
echo -e "${YELLOW}Run the test-grafana-dashboard.sh script to generate metrics data${RESET}"
