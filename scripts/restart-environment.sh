#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Restarting Enhanced Local Development Environment ===${RESET}"

# Stop the current environment
echo -e "${YELLOW}Stopping current environment...${RESET}"
cd "$(dirname "$0")/.." || exit 1
docker-compose -f local-dev/docker-compose.enhanced.yaml down

# Start the environment again
echo -e "${YELLOW}Starting environment...${RESET}"
make enhanced-local-dev

# Wait for services to be ready
echo -e "${YELLOW}Waiting for services to be ready...${RESET}"
sleep 10

echo -e "${GREEN}Environment restarted successfully!${RESET}"
echo -e "${YELLOW}You can now access:${RESET}"
echo -e "Grafana: http://localhost:3000 (admin/admin123)"
echo -e "Prometheus: http://localhost:9090"
echo -e "Kafka Manager: http://localhost:9000"

echo -e "${BLUE}=== Restart Complete ===${RESET}"
