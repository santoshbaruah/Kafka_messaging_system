#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Fixing ZooKeeper Nodes for Kafka ===${RESET}"

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${RESET}"
    exit 1
fi

# Get the ZooKeeper container ID
ZOOKEEPER_CONTAINER=$(docker ps | grep zookeeper | awk '{print $1}')
if [ -z "$ZOOKEEPER_CONTAINER" ]; then
    echo -e "${RED}Error: ZooKeeper container not found${RESET}"
    exit 1
fi

echo -e "${YELLOW}ZooKeeper container: $ZOOKEEPER_CONTAINER${RESET}"

# Delete the broker IDs from ZooKeeper
echo -e "${YELLOW}Deleting broker IDs from ZooKeeper...${RESET}"
docker exec $ZOOKEEPER_CONTAINER /usr/bin/zookeeper-shell localhost:2181 deleteall /brokers/ids

echo -e "${GREEN}Broker IDs deleted from ZooKeeper${RESET}"

# Delete the topics from ZooKeeper
echo -e "${YELLOW}Deleting topics from ZooKeeper...${RESET}"
docker exec $ZOOKEEPER_CONTAINER /usr/bin/zookeeper-shell localhost:2181 deleteall /brokers/topics

echo -e "${GREEN}Topics deleted from ZooKeeper${RESET}"

# Delete the consumer groups from ZooKeeper
echo -e "${YELLOW}Deleting consumer groups from ZooKeeper...${RESET}"
docker exec $ZOOKEEPER_CONTAINER /usr/bin/zookeeper-shell localhost:2181 deleteall /consumers

echo -e "${GREEN}Consumer groups deleted from ZooKeeper${RESET}"

echo -e "${GREEN}ZooKeeper nodes fixed${RESET}"
echo -e "${YELLOW}Now restart the Kafka containers with:${RESET}"
echo -e "docker-compose -f local-dev/docker-compose.enhanced.yaml down"
echo -e "docker-compose -f local-dev/docker-compose.enhanced.yaml up -d"
echo -e "${BLUE}=== ZooKeeper Fix Complete ===${RESET}"
