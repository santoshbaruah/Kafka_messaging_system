#!/bin/bash
set -e

# Script to view Kafka messages using kubectl exec or docker exec
# This script works with both Kubernetes and Docker environments

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

# Default values
TOPIC=${KAFKA_TOPIC:-posts}
FROM_BEGINNING=${FROM_BEGINNING:-false}
MAX_MESSAGES=${MAX_MESSAGES:-0}
ENVIRONMENT="docker" # Default to docker environment

# Function to print usage
usage() {
  echo -e "${BLUE}Usage:${RESET} $0 [options]"
  echo -e "\nOptions:"
  echo -e "  --topic TOPIC       Kafka topic to view (default: posts)"
  echo -e "  --from-beginning    View messages from the beginning of the topic"
  echo -e "  --max NUMBER        Maximum number of messages to view"
  echo -e "  --k8s               Use Kubernetes environment"
  echo -e "  --namespace NS      Kubernetes namespace (default: kafka)"
  echo -e "  --pod POD           Kubernetes pod name (default: kafka-0)"
  echo -e "  --help              Show this help message"
  echo -e "\nExamples:"
  echo -e "  $0 --topic posts --from-beginning"
  echo -e "  $0 --topic posts.dlq --max 10"
  echo -e "  $0 --k8s --namespace kafka --pod kafka-0 --topic posts"
  exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --topic)
      TOPIC="$2"
      shift 2
      ;;
    --namespace)
      NAMESPACE="$2"
      shift 2
      ;;
    --pod)
      POD="$2"
      shift 2
      ;;
    --from-beginning)
      FROM_BEGINNING=true
      shift
      ;;
    --max)
      MAX_MESSAGES="$2"
      shift 2
      ;;
    --k8s)
      ENVIRONMENT="kubernetes"
      shift
      ;;
    --help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${RESET}"
      usage
      ;;
  esac
done

# Set default values for Kubernetes environment
if [ "$ENVIRONMENT" = "kubernetes" ]; then
  NAMESPACE=${NAMESPACE:-kafka}
  POD=${POD:-kafka-0}
fi

# Build the command
CMD="kafka-console-consumer --bootstrap-server kafka-1:29092 --topic $TOPIC"

# Add from-beginning flag if requested
if [ "$FROM_BEGINNING" = "true" ]; then
  CMD="$CMD --from-beginning"
fi

# Add max-messages flag if specified
if [ "$MAX_MESSAGES" -gt 0 ]; then
  CMD="$CMD --max-messages $MAX_MESSAGES"
fi

# Print information
echo -e "${BLUE}=== Kafka Message Viewer ===${RESET}"
echo -e "${YELLOW}Environment:${RESET} $ENVIRONMENT"
echo -e "${YELLOW}Topic:${RESET} $TOPIC"
echo -e "${YELLOW}From beginning:${RESET} $FROM_BEGINNING"
if [ "$MAX_MESSAGES" -gt 0 ]; then
  echo -e "${YELLOW}Max messages:${RESET} $MAX_MESSAGES"
fi
echo -e "${GREEN}Press Ctrl+C to stop${RESET}"
echo -e "${BLUE}----------------------------------------${RESET}"

# Execute the command based on environment
if [ "$ENVIRONMENT" = "kubernetes" ]; then
  # Check if kubectl is installed
  if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Error: kubectl is not installed${RESET}"
    exit 1
  fi

  # Check if the pod exists
  if ! kubectl get pod -n "$NAMESPACE" "$POD" &> /dev/null; then
    echo -e "${RED}Error: Pod $POD not found in namespace $NAMESPACE${RESET}"
    exit 1
  fi

  echo -e "${YELLOW}Namespace:${RESET} $NAMESPACE"
  echo -e "${YELLOW}Pod:${RESET} $POD"
  kubectl exec -it -n "$NAMESPACE" "$POD" -- $CMD
else
  # Check if docker is installed
  if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: docker is not installed${RESET}"
    exit 1
  fi

  # Find the first Kafka container
  KAFKA_CONTAINER=$(docker ps | grep kafka-1 | awk '{print $1}')
  if [ -z "$KAFKA_CONTAINER" ]; then
    echo -e "${RED}Error: No Kafka container found${RESET}"
    exit 1
  fi

  echo -e "${YELLOW}Container:${RESET} $KAFKA_CONTAINER"
  # Use a different approach to avoid JMX exporter issues
  docker exec -it $KAFKA_CONTAINER bash -c "unset KAFKA_JMX_OPTS && unset JMX_PORT && $CMD"
fi

# Print a separator after the command completes
echo -e "${BLUE}----------------------------------------${RESET}"
echo -e "${GREEN}Viewer stopped${RESET}"
