#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Fixing Permissions for Kafka Message Files ===${RESET}"

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${RESET}"
    exit 1
fi

# Get all Kafka containers
KAFKA_CONTAINERS=$(docker ps | grep kafka | awk '{print $1}')
if [ -z "$KAFKA_CONTAINERS" ]; then
    echo -e "${RED}Error: No Kafka containers found${RESET}"
    exit 1
fi

echo -e "${YELLOW}Found Kafka containers:${RESET}"
echo "$KAFKA_CONTAINERS"

# Fix permissions in each container
for container in $KAFKA_CONTAINERS; do
    echo -e "${YELLOW}Fixing permissions in container: $container${RESET}"
    
    # Create a test directory with proper permissions
    docker exec $container sh -c "mkdir -p /tmp/kafka-messages && chmod 777 /tmp/kafka-messages"
    
    # Create a test file with proper permissions
    docker exec $container sh -c "echo 'test' > /tmp/kafka-messages/test.txt && chmod 666 /tmp/kafka-messages/test.txt"
    
    echo -e "${GREEN}Permissions fixed in container: $container${RESET}"
done

echo -e "${GREEN}All containers updated${RESET}"
echo -e "${YELLOW}Now you can use /tmp/kafka-messages/ directory for message files${RESET}"
echo -e "${BLUE}=== Permissions Fix Complete ===${RESET}"
