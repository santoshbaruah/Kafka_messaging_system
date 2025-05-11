#!/bin/bash
set -e

# Script to run the Kafka messaging system demo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}=== Kafka Messaging System Demo ===${RESET}"

# Step 1: Start the enhanced local development environment
echo -e "${YELLOW}Step 1: Starting the enhanced local development environment...${RESET}"
make enhanced-local-dev

# Step 2: Wait for all services to be ready
echo -e "${YELLOW}Step 2: Waiting for all services to be ready...${RESET}"
sleep 10

# Step 3: Open the Kafka Topics UI
echo -e "${YELLOW}Step 3: Opening the Kafka Topics UI...${RESET}"
open http://localhost:8002

# Step 4: Open the Grafana dashboard
echo -e "${YELLOW}Step 4: Opening the Grafana dashboard...${RESET}"
echo -e "${BLUE}Login with username: admin, password: admin123${RESET}"
echo -e "${BLUE}Navigate to the 'Advanced Kafka Messaging Dashboard' for real-time metrics${RESET}"
open http://localhost:3000/d/advanced-kafka-dashboard/advanced-kafka-messaging-dashboard

# Step 5: Show producer logs
echo -e "${YELLOW}Step 5: Showing producer logs...${RESET}"
docker logs kafka-producer | tail -20

# Step 6: Show consumer logs
echo -e "${YELLOW}Step 6: Showing consumer logs...${RESET}"
docker logs kafka-consumer | tail -20

# Step 7: Show consumer metrics
echo -e "${YELLOW}Step 7: Showing consumer metrics...${RESET}"
curl -s http://localhost:8000/metrics | grep kafka_consumer_messages_processed_total

echo -e "${GREEN}=== Demo Complete ===${RESET}"
echo -e "${GREEN}You can now follow the steps in the TECHNICAL_GUIDE.md file to continue the demo.${RESET}"
echo -e "${GREEN}For example, you can send custom messages to the Kafka topic:${RESET}"
echo -e "${YELLOW}docker exec -it kafka-1 kafka-console-producer --broker-list localhost:9092 --topic posts${RESET}"
echo -e "${GREEN}And view messages in the DLQ:${RESET}"
echo -e "${YELLOW}docker exec -it kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic posts.dlq --from-beginning --max-messages 5${RESET}"
