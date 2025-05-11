#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Testing Grafana Dashboard with Real Data ===${RESET}"

# Check if Docker is running
if ! docker ps &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${RESET}"
    exit 1
fi

# Check if the consumer container is running
if ! docker ps | grep -q "kafka-consumer"; then
    echo -e "${RED}Error: Consumer container not running${RESET}"
    exit 1
fi

# Get the Kafka container ID
KAFKA_CONTAINER=$(docker ps | grep kafka-1 | awk '{print $1}')
if [ -z "$KAFKA_CONTAINER" ]; then
    echo -e "${RED}Error: Kafka container not found${RESET}"
    exit 1
fi

echo -e "${YELLOW}Kafka container: $KAFKA_CONTAINER${RESET}"

# Send a batch of messages to generate metrics
echo -e "${YELLOW}Sending messages to generate metrics...${RESET}"

# Create a temporary file for messages
TMP_FILE=$(mktemp)

# Generate 100 messages with various patterns
for i in {1..100}; do
    # Every 10th message will have force_failure=true to trigger circuit breaker
    if [ $((i % 10)) -eq 0 ]; then
        echo "{\"sender\":\"dashboard-test\",\"content\":\"dashboard test $i\",\"created_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"metadata\":{\"test_id\":$RANDOM,\"force_failure\":true}}" >> $TMP_FILE
    else
        echo "{\"sender\":\"dashboard-test\",\"content\":\"dashboard test $i\",\"created_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"metadata\":{\"test_id\":$RANDOM}}" >> $TMP_FILE
    fi
done

# Send all messages at once
echo -e "${YELLOW}Sending all messages at once...${RESET}"

# Count the number of messages
MESSAGE_COUNT=$(wc -l < $TMP_FILE)
echo -e "${YELLOW}Sending $MESSAGE_COUNT messages...${RESET}"

# Create the messages directory with proper permissions if it doesn't exist
docker exec $KAFKA_CONTAINER sh -c "mkdir -p /tmp/kafka-messages && chmod 777 /tmp/kafka-messages"

# Copy the file to the container
docker cp $TMP_FILE $KAFKA_CONTAINER:/tmp/kafka-messages/dashboard_messages.txt

# Make sure the file is readable
docker exec $KAFKA_CONTAINER sh -c "chmod 666 /tmp/kafka-messages/dashboard_messages.txt"

# Use a simple command without JMX to send the messages
docker exec -e KAFKA_JMX_OPTS="" -e JMX_PORT="" $KAFKA_CONTAINER sh -c "cat /tmp/kafka-messages/dashboard_messages.txt | kafka-console-producer --bootstrap-server localhost:9092 --topic posts"

# Clean up
rm $TMP_FILE

echo -e "${GREEN}Sent 100 test messages to Kafka${RESET}"
echo -e "${YELLOW}Now check the Grafana dashboard at http://localhost:3000${RESET}"
echo -e "${YELLOW}Login with admin/admin123${RESET}"

echo -e "${BLUE}=== Test Complete ===${RESET}"
echo -e "${YELLOW}If you don't see data in the dashboard, try the following:${RESET}"
echo -e "1. Run ./fix-kafka-jmx.sh to fix JMX issues"
echo -e "2. Run ./restart-monitoring.sh to restart monitoring services"
echo -e "3. Run ./auto-test-fix.sh for comprehensive diagnostics and fixes"
echo -e "4. Check the logs of the services for errors"
