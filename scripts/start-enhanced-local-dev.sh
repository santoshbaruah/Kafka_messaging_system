#!/bin/bash
set -e

# Script to start the enhanced local development environment

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}=== Starting Enhanced Local Development Environment ===${RESET}"

# Check if JMX exporter JAR exists, download if not
if [ ! -f "./local-dev/jmx-exporter/jmx_prometheus_javaagent-0.16.1.jar" ]; then
    echo -e "${YELLOW}JMX exporter JAR not found, downloading...${RESET}"
    ./scripts/download-jmx-exporter.sh
fi

# Start the environment
echo -e "${BLUE}Starting Docker Compose environment...${RESET}"
cd ./local-dev && docker compose -f docker-compose.enhanced.yaml up -d
# If the above command fails, try the legacy docker-compose command
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}Docker Compose plugin failed, trying legacy docker-compose command...${RESET}"
    cd ./local-dev && docker-compose -f docker-compose.enhanced.yaml up -d
fi

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${RESET}"
sleep 10

# Print access information
echo -e "${GREEN}=== Environment Started Successfully ===${RESET}"
echo -e "${GREEN}Access the following services:${RESET}"
echo -e "${YELLOW}Kafka Manager:${RESET} http://localhost:9000"
echo -e "${YELLOW}Schema Registry UI:${RESET} http://localhost:8001"
echo -e "${YELLOW}Kafka Topics UI:${RESET} http://localhost:8002"
echo -e "${YELLOW}Prometheus:${RESET} http://localhost:9090"
echo -e "${YELLOW}Grafana:${RESET} http://localhost:3000 (admin/${GRAFANA_ADMIN_PASSWORD:-admin123})"
echo -e "${YELLOW}Consumer Metrics:${RESET} http://localhost:8000/metrics"

echo -e "${BLUE}=== Environment is ready for development ===${RESET}"
