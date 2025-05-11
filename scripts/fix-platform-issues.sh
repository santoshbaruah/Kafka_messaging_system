#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Fixing Platform Issues for Docker Images ===${RESET}"

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${RESET}"
    exit 1
fi

# Update the docker-compose.enhanced.yaml file to add platform: linux/amd64 for ARM64 Macs
if [[ $(uname -m) == "arm64" ]]; then
    echo -e "${YELLOW}Detected ARM64 architecture, updating docker-compose.enhanced.yaml...${RESET}"

    # Create a backup of the original file
    cp local-dev/docker-compose.enhanced.yaml local-dev/docker-compose.enhanced.yaml.bak

    # Create a new file with platform: linux/amd64 for each service
    echo "# Enhanced Docker Compose configuration for Kafka cluster" > local-dev/docker-compose.enhanced.yaml.new
    echo "# This version includes additional development tools and monitoring" >> local-dev/docker-compose.enhanced.yaml.new
    echo "" >> local-dev/docker-compose.enhanced.yaml.new
    echo "services:" >> local-dev/docker-compose.enhanced.yaml.new

    # Extract services section and add platform: linux/amd64 to each service
    grep -A 1000 "^services:" local-dev/docker-compose.enhanced.yaml | grep -v "^services:" | while read -r line; do
        if [[ $line =~ ^[[:space:]]+[a-zA-Z0-9_-]+: ]]; then
            # This is a service definition
            echo "$line" >> local-dev/docker-compose.enhanced.yaml.new
            echo "    platform: linux/amd64" >> local-dev/docker-compose.enhanced.yaml.new
        else
            echo "$line" >> local-dev/docker-compose.enhanced.yaml.new
        fi
    done

    # Replace the original file with the new one
    mv local-dev/docker-compose.enhanced.yaml.new local-dev/docker-compose.enhanced.yaml

    echo -e "${GREEN}Updated docker-compose.enhanced.yaml with platform: linux/amd64${RESET}"
else
    echo -e "${YELLOW}Not running on ARM64, no changes needed${RESET}"
fi

echo -e "${GREEN}Platform issues fixed${RESET}"
echo -e "${YELLOW}Now restart the environment with:${RESET}"
echo -e "make enhanced-local-dev"
echo -e "${BLUE}=== Platform Fix Complete ===${RESET}"
