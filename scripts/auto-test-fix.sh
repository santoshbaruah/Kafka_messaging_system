#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Kafka System Auto-Test and Auto-Fix Tool ===${RESET}"

# Function to check if a service is running
check_service() {
    local service_name=$1
    local container_pattern=$2
    local container_count=$(docker ps | grep -c "$container_pattern")

    if [ "$container_count" -gt 0 ]; then
        echo -e "${GREEN}✓ $service_name is running ($container_count containers)${RESET}"
        return 0
    else
        echo -e "${RED}✗ $service_name is not running${RESET}"
        return 1
    fi
}

# Function to check if a port is open
check_port() {
    local service_name=$1
    local port=$2

    if nc -z localhost $port &>/dev/null; then
        echo -e "${GREEN}✓ $service_name port $port is open${RESET}"
        return 0
    else
        echo -e "${RED}✗ $service_name port $port is not open${RESET}"
        return 1
    fi
}

# Function to check Prometheus targets
check_prometheus_targets() {
    local up_targets=$(curl -s http://localhost:9090/api/v1/targets | grep "state\":\"up\"" | wc -l)

    if [ "$up_targets" -gt 0 ]; then
        echo -e "${GREEN}✓ Prometheus has $up_targets targets up${RESET}"
        return 0
    else
        echo -e "${RED}✗ No Prometheus targets are up${RESET}"
        return 1
    fi
}

# Function to check Kafka topics
check_kafka_topics() {
    local kafka_container=$(docker ps | grep kafka-1 | awk '{print $1}')

    if [ -z "$kafka_container" ]; then
        echo -e "${RED}✗ Kafka container not found${RESET}"
        return 1
    fi

    local topics=$(docker exec $kafka_container kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null)

    if [[ $topics == *"posts"* ]]; then
        echo -e "${GREEN}✓ Kafka topic 'posts' exists${RESET}"
        return 0
    else
        echo -e "${RED}✗ Kafka topic 'posts' does not exist${RESET}"
        return 1
    fi
}

# Function to check consumer metrics
check_consumer_metrics() {
    local metrics=$(curl -s http://localhost:8000/metrics | grep -c "kafka_consumer")

    if [ "$metrics" -gt 0 ]; then
        echo -e "${GREEN}✓ Consumer is exposing $metrics Kafka metrics${RESET}"
        return 0
    else
        echo -e "${RED}✗ No Kafka consumer metrics found${RESET}"
        return 1
    fi
}

# Function to check Grafana
check_grafana() {
    local status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health)

    if [ "$status" = "200" ]; then
        echo -e "${GREEN}✓ Grafana is running${RESET}"

        # Check if Prometheus datasource is configured
        local datasources=$(curl -s -u admin:admin123 http://localhost:3000/api/datasources)
        if [[ $datasources == *"prometheus"* ]]; then
            echo -e "${GREEN}✓ Prometheus datasource is configured in Grafana${RESET}"
            return 0
        else
            echo -e "${RED}✗ Prometheus datasource is not configured in Grafana${RESET}"
            return 1
        fi
    else
        echo -e "${RED}✗ Grafana is not running (status code: $status)${RESET}"
        return 1
    fi
}

# Function to check if messages can be sent to Kafka
test_kafka_messaging() {
    echo -e "${YELLOW}Testing Kafka messaging...${RESET}"

    # Create a test message
    local test_message="{\"sender\":\"auto-test\",\"content\":\"Test message\",\"created_at\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\",\"metadata\":{\"test_id\":1}}"
    local kafka_container=$(docker ps | grep kafka-1 | awk '{print $1}')

    if [ -z "$kafka_container" ]; then
        echo -e "${RED}✗ Kafka container not found${RESET}"
        return 1
    fi

    # Create the messages directory with proper permissions if it doesn't exist
    docker exec $kafka_container sh -c "mkdir -p /tmp/kafka-messages && chmod 777 /tmp/kafka-messages"

    # Send the test message
    echo "$test_message" > /tmp/test_message.txt
    docker cp /tmp/test_message.txt $kafka_container:/tmp/kafka-messages/test_message.txt
    docker exec $kafka_container sh -c "chmod 666 /tmp/kafka-messages/test_message.txt"

    if docker exec -e KAFKA_JMX_OPTS="" -e JMX_PORT="" $kafka_container sh -c "cat /tmp/kafka-messages/test_message.txt | kafka-console-producer --bootstrap-server localhost:9092 --topic posts" &>/dev/null; then
        echo -e "${GREEN}✓ Successfully sent test message to Kafka${RESET}"
        rm -f /tmp/test_message.txt
        return 0
    else
        echo -e "${RED}✗ Failed to send test message to Kafka${RESET}"
        rm -f /tmp/test_message.txt
        return 1
    fi
}

# Function to fix JMX issues
fix_jmx_issues() {
    echo -e "${YELLOW}Fixing JMX issues...${RESET}"
    ./scripts/fix-kafka-jmx.sh
    return $?
}

# Function to restart monitoring
restart_monitoring() {
    echo -e "${YELLOW}Restarting monitoring services...${RESET}"
    ./scripts/restart-monitoring.sh
    return $?
}

# Function to generate metrics
generate_metrics() {
    echo -e "${YELLOW}Generating metrics...${RESET}"
    ./scripts/generate-metrics.sh
    return $?
}

# Function to restart the entire environment
restart_environment() {
    echo -e "${YELLOW}Restarting the entire environment...${RESET}"

    # Stop all containers
    docker-compose -f local-dev/docker-compose.enhanced.yaml down

    # Start the environment again
    docker-compose -f local-dev/docker-compose.enhanced.yaml up -d

    echo -e "${GREEN}Environment restarted${RESET}"
    echo -e "${YELLOW}Waiting for services to start...${RESET}"
    sleep 30

    return 0
}

# Main testing function
run_tests() {
    echo -e "${BLUE}=== Running System Tests ===${RESET}"

    local tests_passed=0
    local tests_failed=0

    # Check Docker
    if docker ps &>/dev/null; then
        echo -e "${GREEN}✓ Docker is running${RESET}"
        ((tests_passed++))
    else
        echo -e "${RED}✗ Docker is not running${RESET}"
        ((tests_failed++))
        echo -e "${YELLOW}Please start Docker and try again${RESET}"
        exit 1
    fi

    # Check Kafka
    if check_service "Kafka" "kafka"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Zookeeper
    if check_service "Zookeeper" "zookeeper"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Prometheus
    if check_service "Prometheus" "prometheus"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Grafana
    if check_service "Grafana" "grafana"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Producer
    if check_service "Producer" "kafka-producer"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Consumer
    if check_service "Consumer" "kafka-consumer"; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Kafka ports
    if check_port "Kafka" 9092; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Grafana port
    if check_port "Grafana" 3000; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Prometheus port
    if check_port "Prometheus" 9090; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Consumer metrics port
    if check_port "Consumer metrics" 8000; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Kafka topics
    if check_kafka_topics; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Prometheus targets
    if check_prometheus_targets; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Consumer metrics
    if check_consumer_metrics; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Check Grafana
    if check_grafana; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    # Test Kafka messaging
    if test_kafka_messaging; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi

    echo -e "${BLUE}=== Test Results ===${RESET}"
    echo -e "${GREEN}Tests passed: $tests_passed${RESET}"
    echo -e "${RED}Tests failed: $tests_failed${RESET}"

    if [ "$tests_failed" -gt 0 ]; then
        return 1
    else
        return 0
    fi
}

# Function to create Kafka topics
create_kafka_topics() {
    echo -e "${YELLOW}Creating Kafka topics...${RESET}"
    ./scripts/create-kafka-topic.sh
    return $?
}

# Function to fix permissions
fix_permissions() {
    echo -e "${YELLOW}Fixing permissions...${RESET}"
    ./scripts/fix-permissions.sh
    return $?
}

# Main auto-fix function
auto_fix() {
    echo -e "${BLUE}=== Running Auto-Fix ===${RESET}"

    # Fix JMX issues
    fix_jmx_issues

    # Fix permissions
    fix_permissions

    # Create Kafka topics
    create_kafka_topics

    # Restart monitoring
    restart_monitoring

    # Generate metrics
    generate_metrics

    echo -e "${GREEN}Auto-fix completed${RESET}"

    # Run tests again to verify fixes
    echo -e "${YELLOW}Verifying fixes...${RESET}"
    run_tests

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}All issues have been fixed!${RESET}"
        return 0
    else
        echo -e "${YELLOW}Some issues still remain. Trying more aggressive fixes...${RESET}"

        # More aggressive fix: restart the entire environment
        restart_environment

        # Run tests again
        echo -e "${YELLOW}Verifying fixes after environment restart...${RESET}"
        run_tests

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}All issues have been fixed after environment restart!${RESET}"
            return 0
        else
            echo -e "${RED}Some issues could not be fixed automatically.${RESET}"
            echo -e "${YELLOW}Please check the logs and try manual troubleshooting.${RESET}"
            return 1
        fi
    fi
}

# Main execution
echo -e "${YELLOW}Running initial tests...${RESET}"
run_tests

if [ $? -eq 0 ]; then
    echo -e "${GREEN}All systems are working correctly!${RESET}"
else
    echo -e "${YELLOW}Would you like to run the auto-fix? (y/n)${RESET}"
    read -r response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        auto_fix
    else
        echo -e "${YELLOW}Auto-fix skipped. You can run it later with:${RESET}"
        echo -e "./auto-test-fix.sh --fix"
    fi
fi

echo -e "${BLUE}=== Auto-Test and Auto-Fix Complete ===${RESET}"
