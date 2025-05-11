#!/bin/bash

# Exit on error
set -e

echo "Setting up local development environment for Kafka testing..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose first."
    exit 1
fi

# Create docker-compose.yml file for local development
cat > docker-compose.yml << 'EOF'
version: '3'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.3.2
    container_name: zookeeper
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"
    healthcheck:
      test: ["CMD", "bash", "-c", "echo ruok | nc localhost 2181"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    image: confluentinc/cp-kafka:7.3.2
    container_name: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
      - "9093:9093"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092,PLAINTEXT_HOST://localhost:9093
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_INTER_BROKER_LISTENER_NAME: PLAINTEXT
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: "false"
      KAFKA_JMX_PORT: 9999
      KAFKA_JMX_HOSTNAME: localhost
    healthcheck:
      test: ["CMD", "kafka-topics", "--bootstrap-server", "localhost:9092", "--list"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka-setup:
    image: confluentinc/cp-kafka:7.3.2
    container_name: kafka-setup
    depends_on:
      - kafka
    command: >
      bash -c "
        echo 'Waiting for Kafka to be ready...' &&
        cub kafka-ready -b kafka:9092 1 30 &&
        kafka-topics --create --if-not-exists --bootstrap-server kafka:9092 --topic posts --partitions 6 --replication-factor 1 --config retention.ms=604800000 &&
        kafka-topics --create --if-not-exists --bootstrap-server kafka:9092 --topic posts.dlq --partitions 3 --replication-factor 1 --config retention.ms=1209600000 --config cleanup.policy=compact,delete &&
        echo 'Topics created successfully'
      "
    environment:
      KAFKA_BROKER_ID: ignored
      KAFKA_ZOOKEEPER_CONNECT: ignored

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
      KAFKA_CLUSTERS_0_ZOOKEEPER: zookeeper:2181

  prometheus:
    image: prom/prometheus:v2.42.0
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'

  grafana:
    image: grafana/grafana:9.3.6
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
    depends_on:
      - prometheus
EOF

# Create Prometheus configuration
mkdir -p grafana/provisioning/datasources grafana/provisioning/dashboards
cat > prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'kafka'
    static_configs:
      - targets: ['kafka:9999']
EOF

# Create Grafana datasource
cat > grafana/provisioning/datasources/datasource.yml << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
EOF

# Create Grafana dashboard provider
cat > grafana/provisioning/dashboards/dashboard.yml << 'EOF'
apiVersion: 1

providers:
  - name: 'Kafka'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /etc/grafana/provisioning/dashboards
EOF

# Create a simple Python consumer example
mkdir -p examples
cat > examples/consumer.py << 'EOF'
#!/usr/bin/env python3
import json
import os
import traceback
from datetime import datetime
from kafka import KafkaConsumer, KafkaProducer

def main():
    # Configure the consumer
    consumer = KafkaConsumer(
        'posts',
        bootstrap_servers=os.getenv('KAFKA_BROKER_URL', 'localhost:9093'),
        auto_offset_reset='earliest',
        group_id='local-consumer-group',
        value_deserializer=lambda m: json.loads(m.decode('utf-8')),
        enable_auto_commit=False
    )

    # Configure the producer for DLQ
    producer = KafkaProducer(
        bootstrap_servers=os.getenv('KAFKA_BROKER_URL', 'localhost:9093'),
        value_serializer=lambda m: json.dumps(m).encode('utf-8')
    )

    print(f"Connected to Kafka broker at {os.getenv('KAFKA_BROKER_URL', 'localhost:9093')}")
    print("Listening for messages on topic 'posts'...")

    # Process messages
    for message in consumer:
        try:
            print(f"Received message: {message.value}")

            # Simulate random failures for testing DLQ
            import random
            if random.random() < 0.1:  # 10% chance of failure
                raise ValueError("Simulated random processing failure")

            # Process the message (your business logic here)

            # Commit the offset after successful processing
            consumer.commit()

        except Exception as e:
            print(f"Error processing message: {e}")
            print(traceback.format_exc())

            # Send to DLQ
            dlq_message = {
                'original_message': message.value,
                'topic': message.topic,
                'partition': message.partition,
                'offset': message.offset,
                'timestamp': datetime.now().isoformat(),
                'error': str(e),
                'stacktrace': traceback.format_exc()
            }

            try:
                producer.send('posts.dlq', dlq_message).get(timeout=10)
                print(f"Message sent to DLQ topic 'posts.dlq'")
                consumer.commit()
            except Exception as dlq_error:
                print(f"Failed to send message to DLQ: {dlq_error}")

if __name__ == "__main__":
    main()
EOF

# Create a simple Python producer example
cat > examples/producer.py << 'EOF'
#!/usr/bin/env python3
import json
import os
import time
import uuid
from datetime import datetime
from kafka import KafkaProducer

def main():
    # Configure the producer
    producer = KafkaProducer(
        bootstrap_servers=os.getenv('KAFKA_BROKER_URL', 'localhost:9093'),
        value_serializer=lambda m: json.dumps(m).encode('utf-8')
    )

    print(f"Connected to Kafka broker at {os.getenv('KAFKA_BROKER_URL', 'localhost:9093')}")

    # Send messages every 5 seconds
    counter = 0
    while True:
        # Create a message
        message = {
            'sender': 'local-producer',
            'content': f'message {counter}',
            'created_at': datetime.now().isoformat(),
            'metadata': {
                'producer_id': f'local-{uuid.uuid4()}',
                'sequence': counter
            }
        }

        # Send the message
        future = producer.send('posts', message)
        result = future.get(timeout=60)
        print(f"Message {counter} sent to {result.topic} partition {result.partition} offset {result.offset}")

        counter += 1
        time.sleep(5)

if __name__ == "__main__":
    main()
EOF

# Make the Python scripts executable
chmod +x examples/consumer.py examples/producer.py

# Create a README file
cat > examples/README.md << 'EOF'
# Kafka Local Development Environment

This directory contains example Python scripts for interacting with the local Kafka cluster.

## Prerequisites

- Python 3.6+
- Install required packages:
  
  pip install kafka-python
  

## Running the Consumer


python consumer.py


This will start a consumer that listens for messages on the 'posts' topic.

## Running the Producer


python producer.py


This will start a producer that sends a message to the 'posts' topic every 5 seconds.

## Environment Variables

- `KAFKA_BROKER_URL`: The Kafka broker URL (default: localhost:9093)
EOF

echo "Local development environment setup complete!"
echo "To start the environment, run: docker-compose up -d"
echo "To view the Kafka UI, open: http://localhost:8080"
echo "To view Grafana, open: http://localhost:3000 (admin/admin)"
echo "Example Python scripts are in the 'examples' directory"
echo "See examples/README.md for more information"
