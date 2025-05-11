#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Creating Kafka Topic ===${RESET}"

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${RESET}"
    exit 1
fi

# Get the Kafka container ID
KAFKA_CONTAINER=$(docker ps | grep kafka-1 | awk '{print $1}')
if [ -z "$KAFKA_CONTAINER" ]; then
    echo -e "${RED}Error: Kafka container not found${RESET}"
    exit 1
fi

echo -e "${YELLOW}Kafka container: $KAFKA_CONTAINER${RESET}"

# Check if the topic already exists
TOPICS=$(docker exec $KAFKA_CONTAINER kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null)
if [[ $TOPICS == *"posts"* ]]; then
    echo -e "${YELLOW}Topic 'posts' already exists${RESET}"
else
    # Create the topic
    echo -e "${YELLOW}Creating topic 'posts'...${RESET}"
    docker exec $KAFKA_CONTAINER kafka-topics --create --bootstrap-server localhost:9092 --topic posts --partitions 3 --replication-factor 1
    echo -e "${GREEN}Topic 'posts' created successfully${RESET}"
fi

# Check if the DLQ topic already exists
if [[ $TOPICS == *"posts.dlq"* ]]; then
    echo -e "${YELLOW}Topic 'posts.dlq' already exists${RESET}"
else
    # Create the DLQ topic
    echo -e "${YELLOW}Creating topic 'posts.dlq'...${RESET}"
    docker exec $KAFKA_CONTAINER kafka-topics --create --bootstrap-server localhost:9092 --topic posts.dlq --partitions 3 --replication-factor 1
    echo -e "${GREEN}Topic 'posts.dlq' created successfully${RESET}"
fi

echo -e "${BLUE}=== Kafka Topic Creation Complete ===${RESET}"
