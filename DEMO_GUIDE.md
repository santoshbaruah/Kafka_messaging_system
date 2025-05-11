# Kafka Messaging System Demo Guide

This guide provides step-by-step instructions for demonstrating the Kafka messaging system, including starting the system, sending messages, viewing logs, and monitoring the system.

## Table of Contents

1. [Starting the System](#starting-the-system)
2. [Accessing the Components](#accessing-the-components)
3. [Demonstrating Kafka Messaging](#demonstrating-kafka-messaging)
4. [Monitoring with Grafana](#monitoring-with-grafana)
5. [Troubleshooting](#troubleshooting)

## Starting the System

### Option 1: Use the Demo Script

The easiest way to start the demo is to use the provided script:

./scripts/run-demo.sh

This script will:

1. Start the enhanced local development environment
2. Wait for all services to be ready
3. Open the Kafka Topics UI in your browser
4. Open the Advanced Kafka Messaging Dashboard in Grafana
5. Show producer logs
6. Show consumer logs
7. Show consumer metrics

### Option 2: Manual Setup

#### Step 1: Start the Enhanced Local Development Environment

# Start the enhanced local development environment
make enhanced-local-dev

This command will:

- Start all containers defined in `docker-compose.enhanced.yaml`
- Wait for services to be ready
- Display access information for all components

You should see output similar to this:

=== Starting Enhanced Local Development Environment ===
Starting Docker Compose environment...
[+] Running 15/15
 ✔ Container prometheus          Healthy                                                                                0.5s
 ✔ Container zookeeper           Healthy                                                                                0.5s
 ✔ Container grafana             Running                                                                                0.0s
 ✔ Container kafka-manager       Running                                                                                0.0s
 ✔ Container kafka-2             Healthy                                                                                1.8s
 ✔ Container kafka-3             Healthy                                                                                1.8s
 ✔ Container kafka-1             Healthy                                                                                1.6s
 ✔ Container kafka-setup         Exited                                                                                21.3s
 ✔ Container schema-registry     Healthy                                                                                1.6s
 ✔ Container kcat                Started                                                                                1.5s
 ✔ Container kafka-rest          Running                                                                                0.0s
 ✔ Container kafka-producer      Running                                                                                0.0s
 ✔ Container kafka-topics-ui     Running                                                                                0.0s
 ✔ Container kafka-consumer      Running                                                                                0.0s
 ✔ Container schema-registry-ui  Running                                                                                0.0s
Waiting for services to be ready...
=== Environment Started Successfully ===
Access the following services:
Kafka Manager: http://localhost:9000
Schema Registry UI: http://localhost:8001
Kafka Topics UI: http://localhost:8002
Prometheus: http://localhost:9090
Grafana: http://localhost:3000 (admin/admin123)
Consumer Metrics: http://localhost:8000/metrics
=== Environment is ready for development ===

### Step 2: Verify All Components Are Running

# Check if all containers are running
docker ps

You should see all the containers running, including:

- Kafka brokers (kafka-1, kafka-2, kafka-3)
- Zookeeper
- Schema Registry
- Kafka REST Proxy
- Kafka Topics UI
- Schema Registry UI
- Kafka Manager
- Prometheus
- Grafana
- Producer
- Consumer

## Accessing the Components

### Kafka Manager

Open [http://localhost:9000](http://localhost:9000) in your browser to access the Kafka Manager.

1. Click on "Cluster" in the top menu
2. Click on "Add Cluster"
3. Fill in the form:
   - Cluster Name: `kafka-cluster`
   - Cluster Zookeeper Hosts: `zookeeper:2181`
   - Kafka Version: `2.4.0` (or the version you're using)
4. Click "Save"
5. Click on the cluster name to view details

### Kafka Topics UI

Open [http://localhost:8002](http://localhost:8002) in your browser to access the Kafka Topics UI.

1. You should see the list of topics, including `posts` and `posts.dlq`
2. Click on a topic to view its details, including partitions and messages

### Schema Registry UI

Open [http://localhost:8001](http://localhost:8001) in your browser to access the Schema Registry UI.

### Prometheus

Open [http://localhost:9090](http://localhost:9090) in your browser to access Prometheus.

1. Click on "Status" > "Targets" to verify that all targets are "UP"
2. Click on "Alerts" to view configured alerts

### Grafana

Open [http://localhost:3000](http://localhost:3000) in your browser to access Grafana.

1. Log in with username `admin` and password `admin123`
2. Navigate to the "Advanced Kafka Messaging Dashboard" to view real-time metrics

### Consumer Metrics

Open [http://localhost:8000/metrics](http://localhost:8000/metrics) in your browser to view the raw consumer metrics.

## Demonstrating Kafka Messaging

### Step 1: Send Test Messages

You can send test messages using the provided script:

```bash
./scripts/direct-message-sender.sh "Test message $(date)"
```

This will send a test message and three additional messages to the Kafka topic.

### Step 2: View Messages Being Consumed

To see the messages being consumed:

```bash
./scripts/view-kafka-messages.sh --topic posts --from-beginning
```

You should see messages flowing through the system. Press Ctrl+C to stop viewing messages.

### Step 3: Test Circuit Breaker Functionality

To test the circuit breaker functionality:

```bash
./scripts/test-circuit-breaker.sh
```

This script will:
1. Send multiple messages to trigger the circuit breaker
2. Check consumer logs for circuit breaker events
3. Verify that the circuit breaker opens and closes as expected

### Step 4: View Messages in Kafka Topics UI

1. Open [http://localhost:8002](http://localhost:8002) in your browser
2. Click on the "posts" topic
3. Click on "View Messages" to see the messages in the topic
4. You can also view messages in the DLQ topic by clicking on "posts.dlq"

### Step 5: Send Custom Messages

You can use the Kafka console producer to send custom messages:

# Send custom messages to the posts topic
docker exec -it kafka-1 kafka-console-producer --broker-list localhost:9092 --topic posts

Type your messages, one per line, and press Ctrl+D when done. For example:
json
{"sender":"demo-user","content":"This is a test message","timestamp":"2025-04-21T15:00:00Z"}
{"sender":"demo-user","content":"Another test message","timestamp":"2025-04-21T15:01:00Z"}

### Step 6: View Messages in the DLQ

The consumer is configured to randomly fail processing some messages, which will be sent to the DLQ:

# View messages in the DLQ
docker exec -it kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic posts.dlq --from-beginning --max-messages 5

You should see failed messages with error information.

## Monitoring with Grafana

### Step 1: Access the Advanced Kafka Messaging Dashboard

1. Open [http://localhost:3000](http://localhost:3000) in your browser
2. Log in with username `admin` and password `admin123`
3. Navigate to the "Advanced Kafka Messaging Dashboard"

### Step 2: Explore the Dashboard

The dashboard shows various real-time metrics about the Kafka messaging system:

1. **Message Throughput**: Rate of messages processed per second
2. **Failed Messages**: Rate of messages sent to DLQ
3. **Consumer Lag**: Difference between produced and consumed messages
4. **System Health**: Overall health status of the consumer
5. **Total Failed Messages**: Count of messages in the DLQ
6. **Message Processing Time**: Average time to process a message
7. **Message Retries**: Rate of message retries
8. **Kafka Broker Metrics**: Metrics from the Kafka brokers
9. **Message Success vs Failure Rate**: Comparison of successful and failed messages
10. **Message Processing Distribution**: Pie chart showing the distribution of message processing outcomes

### Step 3: Observe Real-Time Changes

To observe real-time changes in the dashboard:

1. Send test messages using the direct-message-sender.sh script
2. Run the test-circuit-breaker.sh script to trigger circuit breaker events
3. Watch the dashboard update in real-time as messages are processed

### Step 3: View Prometheus Alerts

1. Open [http://localhost:9090/alerts](http://localhost:9090/alerts) in your browser
2. You should see alerts for:
   - Kafka broker down
   - Under-replicated partitions
   - DLQ messages
   - Consumer errors
   - High message failure rate

## Troubleshooting

### Grafana Login Issues

If you can't log in to Grafana with the provided credentials, reset the password:

./scripts/reset-grafana-password.sh

### No Data in Grafana Dashboards

If the Grafana dashboards show "No data" for all panels:

1. Check if Prometheus is running:

  
   docker ps | grep prometheus


2. Check if Prometheus can access the metrics:

bash
   curl -s http://localhost:9090/api/v1/targets | grep consumer


3. Check if the consumer metrics endpoint is accessible:

bash
   curl -s http://localhost:8000/metrics | grep kafka


4. Restart Grafana:

bash
   docker restart grafana


### Producer or Consumer Not Working

If the producer or consumer is not working:

1. Check the logs:

bash
   docker logs kafka-producer
   docker logs kafka-consumer


2. Restart the container:

bash
   docker restart kafka-producer
   docker restart kafka-consumer


3. Rebuild the container:

bash
   cd local-dev && docker compose -f docker-compose.enhanced.yaml stop producer
   cd local-dev && docker compose -f docker-compose.enhanced.yaml rm -f producer
   cd local-dev && docker compose -f docker-compose.enhanced.yaml build producer
   cd local-dev && docker compose -f docker-compose.enhanced.yaml up -d producer


Replace `producer` with `consumer` to rebuild the consumer container.

## Conclusion

This demo guide provides a comprehensive walkthrough of the Kafka messaging system, including starting the system, sending messages, viewing logs, and monitoring the system with the Advanced Kafka Messaging Dashboard. By following these steps, you can demonstrate the full functionality of the system.

For more detailed information, please refer to the TECHNICAL_GUIDE.md file.
