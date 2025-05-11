#!/bin/bash
set -e

# Script to reset the Grafana admin password

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Default password
DEFAULT_PASSWORD="admin123"

# Get the new password from the command line or use the default
NEW_PASSWORD=${1:-$DEFAULT_PASSWORD}

echo -e "${BLUE}=== Resetting Grafana Admin Password ===${RESET}"

# Check if Grafana container is running
if ! docker ps | grep -q grafana; then
    echo -e "${YELLOW}Grafana container is not running. Starting it...${RESET}"
    cd ../local-dev && docker compose -f docker-compose.enhanced.yaml up -d grafana
    sleep 5
fi

# Reset the password
echo -e "${YELLOW}Resetting Grafana admin password to: ${NEW_PASSWORD}${RESET}"
docker exec -it grafana grafana-cli admin reset-admin-password ${NEW_PASSWORD}

echo -e "${GREEN}=== Grafana Admin Password Reset Successfully ===${RESET}"
echo -e "${GREEN}You can now log in to Grafana at http://localhost:3000 with:${RESET}"
echo -e "${YELLOW}Username:${RESET} admin"
echo -e "${YELLOW}Password:${RESET} ${NEW_PASSWORD}"
