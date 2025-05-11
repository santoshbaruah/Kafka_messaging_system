#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Fixing Kafka JMX Configuration ===${RESET}"

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

# Disable JMX exporter in each container
for container in $KAFKA_CONTAINERS; do
    echo -e "${YELLOW}Disabling JMX exporter in container: $container${RESET}"

    # Try to determine the shell available in the container
    if docker exec $container which bash &>/dev/null; then
        SHELL_CMD="bash -c"
    elif docker exec $container which sh &>/dev/null; then
        SHELL_CMD="sh -c"
    else
        echo -e "${YELLOW}No shell found in container $container, using direct environment variable modification${RESET}"
        # Directly modify the environment variables through docker
        docker exec -e KAFKA_JMX_OPTS="" -e JMX_PORT="" $container true
        echo -e "${GREEN}JMX exporter disabled in container: $container${RESET}"
        continue
    fi

    # Create a script to update environment variables
    docker exec $container $SHELL_CMD "echo 'export KAFKA_JMX_OPTS=\"\"' > /tmp/disable_jmx.sh"
    docker exec $container $SHELL_CMD "echo 'export JMX_PORT=\"\"' >> /tmp/disable_jmx.sh"
    docker exec $container $SHELL_CMD "echo 'export KAFKA_OPTS=\"\${KAFKA_OPTS//-javaagent:*/}\"' >> /tmp/disable_jmx.sh"

    # Make it executable
    docker exec $container $SHELL_CMD "chmod +x /tmp/disable_jmx.sh 2>/dev/null || true"

    # Source it in the container's profile
    docker exec $container $SHELL_CMD "echo 'source /tmp/disable_jmx.sh 2>/dev/null || true' >> ~/.bashrc 2>/dev/null || true"
    docker exec $container $SHELL_CMD "echo 'source /tmp/disable_jmx.sh 2>/dev/null || true' >> ~/.profile 2>/dev/null || true"

    echo -e "${GREEN}JMX exporter disabled in container: $container${RESET}"
done

echo -e "${GREEN}All Kafka containers updated${RESET}"
echo -e "${YELLOW}Now restart the containers for changes to take effect${RESET}"
echo -e "${BLUE}=== JMX Configuration Fix Complete ===${RESET}"
