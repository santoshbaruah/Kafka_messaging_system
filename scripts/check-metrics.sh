#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Checking Metrics Collection ===${RESET}"

# Check if curl is installed
if ! command -v curl &> /dev/null; then
    echo -e "${RED}Error: curl is not installed${RESET}"
    exit 1
fi

# Check Prometheus metrics
echo -e "${YELLOW}Checking Prometheus metrics...${RESET}"
PROMETHEUS_METRICS=$(curl -s http://localhost:9090/api/v1/targets | grep "state\":\"up\"" | wc -l)
if [ "$PROMETHEUS_METRICS" -gt 0 ]; then
    echo -e "${GREEN}Prometheus has $PROMETHEUS_METRICS targets up${RESET}"
else
    echo -e "${RED}No Prometheus targets are up${RESET}"
fi

# Check consumer metrics
echo -e "${YELLOW}Checking consumer metrics...${RESET}"
CONSUMER_METRICS=$(curl -s http://localhost:8000/metrics | grep -c "kafka_consumer")
if [ "$CONSUMER_METRICS" -gt 0 ]; then
    echo -e "${GREEN}Consumer is exposing $CONSUMER_METRICS Kafka metrics${RESET}"
    
    # Show some sample metrics
    echo -e "${YELLOW}Sample metrics:${RESET}"
    curl -s http://localhost:8000/metrics | grep "kafka_consumer" | head -5
else
    echo -e "${RED}No Kafka consumer metrics found${RESET}"
fi

# Check Grafana
echo -e "${YELLOW}Checking Grafana...${RESET}"
GRAFANA_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)
if [ "$GRAFANA_STATUS" = "200" ]; then
    echo -e "${GREEN}Grafana is running${RESET}"
    
    # Check if Prometheus datasource is configured
    DATASOURCES=$(curl -s -u admin:admin123 http://localhost:3000/api/datasources)
    if [[ $DATASOURCES == *"prometheus"* ]]; then
        echo -e "${GREEN}Prometheus datasource is configured in Grafana${RESET}"
    else
        echo -e "${RED}Prometheus datasource is not configured in Grafana${RESET}"
    fi
else
    echo -e "${RED}Grafana is not running (status code: $GRAFANA_STATUS)${RESET}"
fi

echo -e "${BLUE}=== Metrics Check Complete ===${RESET}"
echo -e "${YELLOW}If metrics are not being collected, try running:${RESET}"
echo -e "1. ./fix-kafka-jmx.sh"
echo -e "2. ./restart-monitoring.sh"
echo -e "3. ./generate-metrics.sh"
