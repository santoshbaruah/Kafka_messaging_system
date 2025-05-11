#!/bin/bash

# This script sends a JSON message to a Kafka topic

# Set variables
NAMESPACE="kafka"
POD_NAME="kafka-0"
TOPIC="posts"
BOOTSTRAP_SERVER="localhost:9092"

# Create JSON message
MESSAGE="{\"message\":\"test message\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"

# Echo the message being sent
echo "Sending message to Kafka: $MESSAGE"

# Use printf to avoid TTY issues with echo and redirection
kubectl exec -n $NAMESPACE $POD_NAME -- bash -c "printf '$MESSAGE' | kafka-console-producer --bootstrap-server $BOOTSTRAP_SERVER --topic $TOPIC"

echo -e "\nMessage sent!"