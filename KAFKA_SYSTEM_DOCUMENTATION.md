# Kafka System Documentation

This document provides comprehensive information about the Kafka messaging system, including how to access all components, how to update the system, and how to troubleshoot common issues.

## Table of Contents

1. [System Overview](#system-overview)
2. [Accessing Components](#accessing-components)
3. [Starting and Stopping the System](#starting-and-stopping-the-system)
4. [Updating the System](#updating-the-system)
5. [Monitoring and Metrics](#monitoring-and-metrics)
6. [Troubleshooting](#troubleshooting)
7. [Advanced Operations](#advanced-operations)

## System Overview

The Kafka messaging system consists of the following components:

- Kafka Cluster: 3 Kafka brokers for high availability
- Zookeeper: For Kafka cluster coordination
- Schema Registry: For managing Avro schemas
- Kafka REST Proxy: For HTTP access to Kafka
- Producer Application: Generates and sends messages to Kafka
- Consumer Application: Processes messages from Kafka
- Monitoring Stack: Prometheus and Grafana for monitoring
- Management UIs: Kafka Manager, Schema Registry UI, and Kafka Topics UI

## Accessing Components

### Kafka Cluster

The Kafka cluster is accessible at:
- Internal: `kafka-1:9092`, `kafka-2:9092`, `kafka-3:9092`
- External: `localhost:9093`, `localhost:9094`, `localhost:9095`

### Management UIs

| Component | URL | Default Credentials |
|-----------|-----|---------------------|
| Kafka Manager | http://localhost:9000 | N/A |
| Schema Registry UI | http://localhost:8001 | N/A |
| Kafka Topics UI | http://localhost:8002 | N/A |
| Prometheus | http://localhost:9090 | N/A |
| Grafana | http://localhost:3000 | Username: `admin`<br>Password: `admin123` |

### Metrics Endpoints

| Component | URL |
|-----------|-----|
| Consumer Metrics | http://localhost:8000/metrics |
| Kafka JMX Metrics | http://localhost:9999/metrics |

## Starting and Stopping the System

### Starting the System

To start the enhanced local development environment:

make enhanced-local-dev

This command will:
1. Start all containers defined in `docker-compose.enhanced.yaml`
2. Wait for services to be ready
3. Display access information for all components

### Stopping the System

To stop the system:

cd local-dev && docker compose -f docker-compose.enhanced.yaml down

Or use the clean target:

make clean

## Updating the System

### Updating Docker Images

To update the producer and consumer applications:

1. Modify the code in the `producer/` or `consumer/` directories
2. Rebuild the Docker images:

# Rebuild producer
docker build -t kafka-producer:latest -f producer/Dockerfile.improved producer/

# Rebuild consumer
docker build -t kafka-consumer:latest -f consumer/Dockerfile.fixed consumer/

3. Restart the containers:

cd local-dev && docker compose -f docker-compose.enhanced.yaml stop producer consumer
cd local-dev && docker compose -f docker-compose.enhanced.yaml rm -f producer consumer
cd local-dev && docker compose -f docker-compose.enhanced.yaml up -d producer consumer

### Updating Kafka Configuration

To update Kafka configuration:

1. Modify the configuration in `local-dev/docker-compose.enhanced.yaml`
2. Restart the Kafka containers:

cd local-dev && docker compose -f docker-compose.enhanced.yaml stop kafka-1 kafka-2 kafka-3
cd local-dev && docker compose -f docker-compose.enhanced.yaml rm -f kafka-1 kafka-2 kafka-3
cd local-dev && docker compose -f docker-compose.enhanced.yaml up -d kafka-1 kafka-2 kafka-3

### Updating Monitoring Configuration

To update Prometheus or Grafana configuration:

1. Modify the configuration in `local-dev/prometheus/prometheus.yml` or `local-dev/grafana/provisioning/`
2. Restart the monitoring containers:

cd local-dev && docker compose -f docker-compose.enhanced.yaml restart prometheus grafana

## Monitoring and Metrics

### Grafana Dashboards

The following Grafana dashboards are available:

1. Kafka Consumer Metrics: Shows consumer metrics like messages processed, DLQ messages, consumer lag, processing errors, message retries, and throughput.

To access the dashboards:
1. Open http://localhost:3000 in your browser
2. Log in with username `admin` and password `admin123`
3. Navigate to Dashboards -> Browse

### Prometheus Metrics

Prometheus collects metrics from:
- Kafka brokers (via JMX exporter)
- Consumer application (via Prometheus client)

To query metrics:
1. Open http://localhost:9090 in your browser
2. Use the Query interface to run PromQL queries

Important metrics:
- `kafka_consumer_messages_processed_total`: Total number of messages processed
- `kafka_consumer_dlq_messages_total`: Total number of messages sent to DLQ
- `kafka_consumer_processing_errors_total`: Total number of processing errors
- `kafka_consumer_message_retries_total`: Total number of message retries
- `kafka_consumer_lag`: Consumer lag in messages

### Alerts

Prometheus is configured with alerts for:
- Kafka broker down
- Under-replicated partitions
- DLQ messages
- Consumer errors
- High message failure rate

To view alerts:
1. Open http://localhost:9090/alerts in your browser

## Troubleshooting

### Common Issues

#### Consumer Can't Connect to Kafka

Symptoms: Consumer logs show connection errors to Kafka

Solution:
1. Check if Kafka brokers are running:
docker ps | grep kafka

2. Check if consumer can reach Kafka:
docker exec -it kafka-consumer bash -c "echo > /dev/tcp/kafka-1/9092"

3. Check Kafka broker logs:
docker logs kafka-1

#### Producer Not Sending Messages

Symptoms: No new messages in Kafka topics

Solution:
1. Check producer logs:
docker logs kafka-producer

2. Check if producer can connect to Kafka:
docker exec -it kafka-producer bash -c "echo > /dev/tcp/kafka-1/9092"

#### Prometheus Not Scraping Metrics

Symptoms: No data in Grafana dashboards

Solution:
1. Check Prometheus targets:
   - Open http://localhost:9090/targets in your browser
   - Verify that all targets are "UP"

2. Check if metrics endpoints are accessible:
curl -s http://localhost:8000/metrics | head

3. Check Prometheus configuration:
docker exec -it prometheus cat /etc/prometheus/prometheus.yml

#### Grafana Not Showing Data

Symptoms: Grafana dashboards show "No data" for all panels

Solution:
1. Check Prometheus data source in Grafana:
   - Open http://localhost:3000/datasources in your browser
   - Verify that Prometheus data source is configured correctly

2. Check dashboard queries:
   - Open the dashboard in edit mode
   - Check that the queries are using the correct metrics

3. Restart Grafana:
docker restart grafana

### Grafana Login Issues

Symptoms: Unable to log in to Grafana with the provided credentials

Solution:

1. Reset the Grafana admin password:

./scripts/reset-grafana-password.sh

This will reset the admin password to `admin123`. You can also specify a custom password:

./scripts/reset-grafana-password.sh mynewpassword

### Viewing Logs

To view logs for a specific container:

docker logs <container-name>

For example:

docker logs kafka-consumer
docker logs kafka-producer
docker logs kafka-1

To follow logs in real-time:

docker logs -f <container-name>

### Restarting Components

To restart a specific component:

docker restart <container-name>

For example:

docker restart kafka-consumer
docker restart kafka-producer
docker restart grafana

## Advanced Operations

### Managing Kafka Topics

#### List Topics

docker exec -it kafka-1 kafka-topics --list --bootstrap-server localhost:9092

#### Create a Topic

docker exec -it kafka-1 kafka-topics --create --topic new-topic --partitions 6 --replication-factor 3 --bootstrap-server localhost:9092

#### Describe a Topic

docker exec -it kafka-1 kafka-topics --describe --topic posts --bootstrap-server localhost:9092

#### Delete a Topic

docker exec -it kafka-1 kafka-topics --delete --topic new-topic --bootstrap-server localhost:9092

### Consuming Messages

#### Consume Messages from a Topic

docker exec -it kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic posts --from-beginning --max-messages 10

#### Consume Messages from DLQ

docker exec -it kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic posts.dlq --from-beginning --max-messages 5

### Producing Test Messages

docker exec -it kafka-1 kafka-console-producer --broker-list localhost:9092 --topic posts

Then type messages, one per line, and press Ctrl+D when done.

### Checking Consumer Groups

docker exec -it kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --list

docker exec -it kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group kafka-consumer-group

### Backup and Restore

#### Backup a Topic

docker exec -it kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic posts --from-beginning --timeout-ms 10000 > posts-backup.json

#### Restore a Topic

cat posts-backup.json | docker exec -i kafka-1 kafka-console-producer --broker-list localhost:9092 --topic posts

---

This documentation provides a comprehensive guide to the Kafka messaging system. For more detailed information about specific components, refer to their respective documentation.
