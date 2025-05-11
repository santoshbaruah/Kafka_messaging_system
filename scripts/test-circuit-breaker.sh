#!/bin/bash

# Script to test the circuit breaker functionality

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

# Error handling function
handle_error() {
    echo -e "${RED}ERROR: $1${RESET}"
    exit 1
}

echo -e "${BLUE}=== Testing Circuit Breaker Functionality ===${RESET}"

# Check if running in Kubernetes or local environment
if kubectl get pods -n kafka &>/dev/null; then
    echo -e "${YELLOW}Testing in Kubernetes environment...${RESET}"

    # Get the consumer pod name
    echo -e "${YELLOW}Looking for consumer pods...${RESET}"

    # Check if we have the circuit breaker consumer deployment
    if kubectl get pods -n kafka -l app=kafka-consumer-circuit-breaker &>/dev/null; then
        echo -e "${YELLOW}Found kafka-consumer-circuit-breaker deployment${RESET}"
        CONSUMER_POD=$(kubectl get pods -n kafka -l app=kafka-consumer-circuit-breaker -o jsonpath='{.items[0].metadata.name}')
    # Check if we have the fixed consumer deployment
    elif kubectl get pods -n kafka -l app=kafka-consumer-fixed &>/dev/null; then
        echo -e "${YELLOW}Found kafka-consumer-fixed deployment${RESET}"
        CONSUMER_POD=$(kubectl get pods -n kafka -l app=kafka-consumer-fixed -o jsonpath='{.items[0].metadata.name}')
    else
        # Fall back to the original consumer deployment
        echo -e "${YELLOW}Looking for original kafka-consumer deployment${RESET}"
        CONSUMER_POD=$(kubectl get pods -n kafka -l app=kafka-consumer -o jsonpath='{.items[0].metadata.name}')
    fi

    if [ -z "$CONSUMER_POD" ]; then
        echo -e "${RED}Error: Consumer pod not found. Available pods in kafka namespace:${RESET}"
        kubectl get pods -n kafka
        exit 1
    fi

    echo -e "${YELLOW}Consumer pod: $CONSUMER_POD${RESET}"

    # Send messages that will trigger the external service call
    echo -e "${YELLOW}Sending messages to trigger the circuit breaker...${RESET}"

    # Send 20 messages to increase the chance of triggering the circuit breaker
    for i in {1..20}; do
        echo -e "${YELLOW}Sending message $i...${RESET}"
        kubectl exec -n kafka kafka-0 -- kafka-console-producer --bootstrap-server localhost:9092 --topic posts <<< "{\"message\":\"test circuit breaker $i\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"id\":$RANDOM}"
        sleep 1
    done

    # Check the consumer logs for circuit breaker events
    echo -e "${YELLOW}Checking consumer logs for circuit breaker events...${RESET}"

    # Get logs but handle the case where 'circuit' might not be found
    if ! kubectl logs -n kafka $CONSUMER_POD | grep -i "circuit" > /tmp/circuit_logs; then
        echo -e "${YELLOW}No circuit breaker events found in logs. Showing recent logs instead:${RESET}"
        kubectl logs -n kafka $CONSUMER_POD --tail=20
    else
        echo -e "${GREEN}Found circuit breaker events:${RESET}"
        cat /tmp/circuit_logs | tail -n 10
        rm /tmp/circuit_logs
    fi

    echo -e "${GREEN}Test completed. Check the logs above for circuit breaker events.${RESET}"
    echo -e "${YELLOW}If you see 'Circuit breaker prevented external service call' messages, the circuit breaker is working.${RESET}"

else
    echo -e "${YELLOW}Testing in local environment...${RESET}"

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

    # Get the consumer container ID
    CONSUMER_CONTAINER=$(docker ps | grep "kafka-consumer" | awk '{print $1}')

    if [ -z "$CONSUMER_CONTAINER" ]; then
        handle_error "Consumer container not found. Available containers:"
        docker ps
        exit 1
    fi

    echo -e "${YELLOW}Consumer container: $CONSUMER_CONTAINER${RESET}"

    # Send messages that will trigger the external service call
    echo -e "${YELLOW}Sending messages to trigger the circuit breaker...${RESET}"

    # Create a temporary file for messages
    TMP_FILE=$(mktemp)

    # Generate 20 messages to trigger the circuit breaker
    for i in {1..20}; do
        echo -e "${YELLOW}Sending message $i...${RESET}"
        # Create a message that will more likely trigger failures
        echo "{\"sender\":\"circuit-test\",\"content\":\"test circuit breaker $i\",\"created_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"metadata\":{\"test_id\":$RANDOM,\"force_failure\":true}}" >> $TMP_FILE
    done

    # Get Kafka container
    KAFKA_CONTAINER=$(docker ps | grep kafka-1 | awk '{print $1}')
    if [ -z "$KAFKA_CONTAINER" ]; then
        handle_error "Kafka container not found"
    fi

    # Send all messages at once
    echo -e "${YELLOW}Sending all messages at once...${RESET}"

    # Copy the file to the container
    docker cp $TMP_FILE $KAFKA_CONTAINER:/tmp/circuit_messages.txt

    # Use a simple command without JMX to send the messages
    docker exec $KAFKA_CONTAINER bash -c "unset KAFKA_JMX_OPTS && unset JMX_PORT && cat /tmp/circuit_messages.txt | kafka-console-producer --bootstrap-server localhost:9092 --topic posts"

    # Clean up
    rm $TMP_FILE

    # Wait for circuit breaker to trigger
    echo -e "${YELLOW}Waiting for circuit breaker to trigger...${RESET}"
    sleep 5

    # Check the consumer logs for circuit breaker events
    echo -e "${YELLOW}Checking consumer logs for circuit breaker events...${RESET}"
    if ! docker logs $CONSUMER_CONTAINER | grep -i "circuit" > /tmp/circuit_logs_local; then
        echo -e "${YELLOW}No circuit breaker events found in logs. Showing recent logs instead:${RESET}"
        docker logs $CONSUMER_CONTAINER --tail=20
    else
        echo -e "${GREEN}Found circuit breaker events:${RESET}"
        cat /tmp/circuit_logs_local | tail -n 10
        rm /tmp/circuit_logs_local
    fi

    echo -e "${GREEN}Test completed. Check the logs above for circuit breaker events.${RESET}"
    echo -e "${YELLOW}If you see 'Circuit breaker prevented external service call' messages, the circuit breaker is working.${RESET}"
fi

echo -e "${BLUE}=== Circuit Breaker Test Completed ===${RESET}"
