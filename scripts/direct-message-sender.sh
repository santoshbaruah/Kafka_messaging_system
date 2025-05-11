#!/bin/bash

# Script to send JSON messages directly to Kafka without TTY issues
# This works with both Kubernetes and Docker environments

set -e  # Exit on error

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

# Default values
TOPIC="posts"
BOOTSTRAP_SERVER="kafka-1:29092"
ENVIRONMENT="docker"  # Default to docker environment

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --topic)
      TOPIC="$2"
      shift 2
      ;;
    --k8s)
      ENVIRONMENT="kubernetes"
      shift
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --pod)
      POD_NAME="$2"
      shift 2
      ;;
    --help)
      echo "Usage: $0 [--topic TOPIC] [--k8s] [--namespace NAMESPACE] [--pod POD_NAME]"
      echo "  --topic TOPIC      Kafka topic to send messages to (default: posts)"
      echo "  --k8s             Use Kubernetes environment (default: docker)"
      echo "  --namespace NS    Kubernetes namespace (default: kafka)"
      echo "  --pod POD         Kubernetes pod name (default: kafka-0)"
      exit 0
      ;;
    *)
      handle_error "Unknown option: $1"
      ;;
  esac
done

# Set default values for Kubernetes environment
if [ "$ENVIRONMENT" = "kubernetes" ]; then
  NAMESPACE=${NAMESPACE:-kafka}
  POD_NAME=${POD_NAME:-kafka-0}

  # Check if the Kafka pod exists
  if ! kubectl get pod -n $NAMESPACE $POD_NAME &>/dev/null; then
    echo -e "${YELLOW}Available pods in namespace '$NAMESPACE':${RESET}"
    kubectl get pods -n $NAMESPACE
    handle_error "Kafka pod '$POD_NAME' not found in namespace '$NAMESPACE'"
  fi
fi

# Create a temporary file for the message
MESSAGE_FILE=$(mktemp)
trap "rm -f $MESSAGE_FILE" EXIT

# Write the JSON message to the file
cat > $MESSAGE_FILE << EOF
{"message":"test message","timestamp":"$(date -u +"%Y-%m-%dT%H:%M:%SZ")","id":$(date +%s)}
EOF

echo -e "${BLUE}Sending message to Kafka:${RESET} $(cat $MESSAGE_FILE)"

# Send the message based on environment
if [ "$ENVIRONMENT" = "kubernetes" ]; then
  # Copy the file to the pod
  kubectl cp $MESSAGE_FILE $NAMESPACE/$POD_NAME:/tmp/message.json

  # Use a simple command without JMX to send the message
  if ! kubectl exec -n $NAMESPACE $POD_NAME -- bash -c "unset KAFKA_JMX_OPTS && unset JMX_PORT && cat /tmp/message.json | kafka-console-producer --bootstrap-server $BOOTSTRAP_SERVER --topic $TOPIC"; then
    handle_error "Failed to send message to Kafka"
  fi
else
  # Find the first Kafka container
  KAFKA_CONTAINER=$(docker ps | grep kafka-1 | awk '{print $1}')
  if [ -z "$KAFKA_CONTAINER" ]; then
    handle_error "No Kafka container found"
  fi

  # Send the message directly without copying to the container
  if ! cat $MESSAGE_FILE | docker exec -i $KAFKA_CONTAINER bash -c "unset KAFKA_JMX_OPTS && unset JMX_PORT && kafka-console-producer --bootstrap-server $BOOTSTRAP_SERVER --topic $TOPIC"; then
    handle_error "Failed to send message to Kafka"
  fi
fi

echo -e "${GREEN}Message sent successfully!${RESET}"

# Send a few more messages with different IDs to test the consumer
for i in {1..3}; do
  sleep 2
  MESSAGE_ID=$(($(date +%s) + $i))
  echo "{\"message\":\"test message $i\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"id\":$MESSAGE_ID}" > $MESSAGE_FILE
  echo -e "${BLUE}Sending additional message:${RESET} $(cat $MESSAGE_FILE)"

  # Send the message based on environment
  if [ "$ENVIRONMENT" = "kubernetes" ]; then
    kubectl cp $MESSAGE_FILE $NAMESPACE/$POD_NAME:/tmp/message.json
    if ! kubectl exec -n $NAMESPACE $POD_NAME -- bash -c "unset KAFKA_JMX_OPTS && unset JMX_PORT && cat /tmp/message.json | kafka-console-producer --bootstrap-server $BOOTSTRAP_SERVER --topic $TOPIC"; then
      handle_error "Failed to send additional message $i to Kafka"
    fi
  else
    if ! cat $MESSAGE_FILE | docker exec -i $KAFKA_CONTAINER bash -c "unset KAFKA_JMX_OPTS && unset JMX_PORT && kafka-console-producer --bootstrap-server $BOOTSTRAP_SERVER --topic $TOPIC"; then
      handle_error "Failed to send additional message $i to Kafka"
    fi
  fi

  echo -e "${GREEN}Additional message $i sent!${RESET}"
done

echo -e "${BLUE}=== Message Sending Complete ===${RESET}"
echo -e "${YELLOW}To view messages, run:${RESET} ./view-kafka-messages.sh"