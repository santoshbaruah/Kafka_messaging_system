#!/bin/bash
set -e

# Script to test Kafka connection

echo "Testing Kafka connection..."
echo "Checking if Kafka brokers are accessible..."

# Check if Kafka is running
if nc -z localhost 9092 2>/dev/null; then
    echo "✅ Kafka broker is accessible on localhost:9092"
else
    echo "❌ Kafka broker is NOT accessible on localhost:9092"
    echo "Make sure Kafka is running."
    exit 1
fi

# Check if topics exist
echo "Checking Kafka topics..."
TOPICS=$(docker exec kafka-1 kafka-topics --list --bootstrap-server localhost:9092 2>/dev/null)

if echo "$TOPICS" | grep -q "posts"; then
    echo "✅ Topic 'posts' exists"
else
    echo "❌ Topic 'posts' does NOT exist"
fi

if echo "$TOPICS" | grep -q "posts.dlq"; then
    echo "✅ Topic 'posts.dlq' exists"
else
    echo "❌ Topic 'posts.dlq' does NOT exist"
fi

# Send a test message
echo "Sending a test message to 'posts' topic..."
TEST_MESSAGE="{\"sender\":\"test-script\",\"content\":\"test message\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
echo "$TEST_MESSAGE" | docker exec -i kafka-1 kafka-console-producer --bootstrap-server localhost:9092 --topic posts > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo "✅ Test message sent successfully"
else
    echo "❌ Failed to send test message"
    exit 1
fi

echo "Kafka connection test completed successfully!"
