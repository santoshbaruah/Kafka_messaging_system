#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Generating Metrics for Grafana Dashboard ===${RESET}"

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

# Create a temporary file for all messages
MESSAGE_FILE=$(mktemp)
trap "rm -f $MESSAGE_FILE" EXIT

# Function to add a message to the file
add_message() {
    local message_type=$1
    local id=$2
    local force_failure=$3

    if [ "$force_failure" = "true" ]; then
        echo "{\"sender\":\"metrics-test\",\"content\":\"$message_type message $id\",\"created_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"metadata\":{\"test_id\":$id,\"force_failure\":true}}" >> $MESSAGE_FILE
    else
        echo "{\"sender\":\"metrics-test\",\"content\":\"$message_type message $id\",\"created_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"metadata\":{\"test_id\":$id}}" >> $MESSAGE_FILE
    fi
}

# Generate regular messages
echo -e "${YELLOW}Generating regular messages...${RESET}"
for i in {1..20}; do
    echo -e "${YELLOW}Generating regular message $i...${RESET}"
    add_message "regular" $i "false"
done

# Generate messages that will trigger circuit breaker
echo -e "${YELLOW}Generating circuit breaker test messages...${RESET}"
for i in {1..10}; do
    echo -e "${YELLOW}Generating circuit breaker test message $i...${RESET}"
    add_message "circuit-breaker" $i "true"
done

# Generate more regular messages
echo -e "${YELLOW}Generating more regular messages...${RESET}"
for i in {21..30}; do
    echo -e "${YELLOW}Generating regular message $i...${RESET}"
    add_message "regular" $i "false"
done

# Send all messages at once
echo -e "${YELLOW}Sending all messages to Kafka...${RESET}"

# Create the messages directory with proper permissions if it doesn't exist
docker exec $KAFKA_CONTAINER sh -c "mkdir -p /tmp/kafka-messages && chmod 777 /tmp/kafka-messages"

# Copy the file to the container
docker cp $MESSAGE_FILE $KAFKA_CONTAINER:/tmp/kafka-messages/all_messages.txt

# Make sure the file is readable
docker exec $KAFKA_CONTAINER sh -c "chmod 666 /tmp/kafka-messages/all_messages.txt"

# Use a simple command without JMX to send the messages
docker exec -e KAFKA_JMX_OPTS="" -e JMX_PORT="" $KAFKA_CONTAINER sh -c "cat /tmp/kafka-messages/all_messages.txt | kafka-console-producer --bootstrap-server localhost:9092 --topic posts"

echo -e "${GREEN}Sent 40 test messages to Kafka${RESET}"
echo -e "${YELLOW}Now check the Grafana dashboard at http://localhost:3000${RESET}"
echo -e "${YELLOW}Login with admin/admin123${RESET}"

echo -e "${BLUE}=== Metrics Generation Complete ===${RESET}"
echo -e "${YELLOW}Wait a few minutes for metrics to be collected and displayed in Grafana${RESET}"
