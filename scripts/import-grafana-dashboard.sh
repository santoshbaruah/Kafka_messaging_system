#!/bin/bash
set -e

# Script to import the enhanced Kafka dashboard into Grafana

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Importing Enhanced Kafka Dashboard into Grafana ===${RESET}"

# Check if running in Kubernetes or local environment
if kubectl get pods -n kafka | grep -q "grafana"; then
    echo -e "${YELLOW}Importing in Kubernetes environment...${RESET}"
    
    # Get the Grafana pod name
    GRAFANA_POD=$(kubectl get pods -n kafka -l app=grafana -o jsonpath='{.items[0].metadata.name}')
    
    if [ -z "$GRAFANA_POD" ]; then
        echo -e "${RED}Error: Grafana pod not found${RESET}"
        exit 1
    fi
    
    echo -e "${YELLOW}Grafana pod: $GRAFANA_POD${RESET}"
    
    # Set up port forwarding to Grafana
    echo -e "${YELLOW}Setting up port forwarding to Grafana...${RESET}"
    kubectl port-forward -n kafka $GRAFANA_POD 3000:3000 &
    PORT_FORWARD_PID=$!
    
    # Wait for port forwarding to be established
    sleep 5
    
    # Import the dashboard
    echo -e "${YELLOW}Importing the dashboard...${RESET}"
    curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Basic $(echo -n "admin:${GRAFANA_ADMIN_PASSWORD:-admin@Grafana123!}" | base64)" -d @k8s/monitoring/enhanced-kafka-dashboard.yaml http://localhost:3000/api/dashboards/db
    
    # Kill the port forwarding process
    kill $PORT_FORWARD_PID
    
    echo -e "${GREEN}Dashboard imported successfully.${RESET}"
    echo -e "${YELLOW}Access Grafana at: kubectl port-forward -n kafka svc/grafana 3000:3000${RESET}"
    
else
    echo -e "${YELLOW}Importing in local environment...${RESET}"
    
    # Check if Grafana is running
    if ! curl -s http://localhost:3000 &>/dev/null; then
        echo -e "${RED}Error: Grafana is not running at http://localhost:3000${RESET}"
        exit 1
    fi
    
    # Import the dashboard
    echo -e "${YELLOW}Importing the dashboard...${RESET}"
    curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Basic $(echo -n "admin:${GRAFANA_ADMIN_PASSWORD:-admin@Grafana123!}" | base64)" -d @k8s/monitoring/enhanced-kafka-dashboard.yaml http://localhost:3000/api/dashboards/db
    
    echo -e "${GREEN}Dashboard imported successfully.${RESET}"
    echo -e "${YELLOW}Access Grafana at: http://localhost:3000${RESET}"
fi

echo -e "${BLUE}=== Dashboard Import Completed ===${RESET}"
