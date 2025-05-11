# Grafana Dashboard Guide

This guide explains how to use and test the Grafana dashboards for monitoring the Kafka messaging system.

## Accessing Grafana

1. Start the enhanced local development environment:
   
   make enhanced-local-dev
   

2. Access Grafana at: http://localhost:3000
   - Username: `admin`
   - Password: `admin123`

## Available Dashboards

### Advanced Kafka Messaging Dashboard

This dashboard provides comprehensive monitoring of the Kafka messaging system, including:

- Message throughput
- Failed messages
- Consumer lag
- Message processing time
- Message retries
- Kafka broker metrics
- Message success vs. failure rates
- Message processing distribution

## Generating Test Data

To see real data in the dashboards, you can use the provided test scripts:

### 1. Test Grafana Dashboard Script

This script sends 100 test messages to Kafka with various patterns to generate diverse metrics:


./scripts/test-grafana-dashboard.sh


### 2. Test Circuit Breaker Script

This script specifically tests the circuit breaker functionality by sending messages that are likely to trigger failures:


./scripts/test-circuit-breaker.sh


## Troubleshooting

If you don't see data in the dashboards:

1. Restart the environment:
   
   ./scripts/restart-environment.sh
   

2. Run both test scripts to generate more data:
   
   ./scripts/test-grafana-dashboard.sh
   ./scripts/test-circuit-breaker.sh
   

3. Check Prometheus metrics directly at: http://localhost:9090
   - Go to "Graph" tab
   - Enter queries like `kafka_consumer_messages_processed_total` to verify metrics are being collected

4. Check consumer logs:
   
   docker logs $(docker ps | grep kafka-consumer | awk '{print $1}')
   

## Dashboard Metrics Explained

### Message Throughput
Shows the rate of messages being processed by the consumer.

### Failed Messages
Displays the rate of messages that failed processing and were sent to the Dead Letter Queue (DLQ).

### Consumer Lag
Indicates how far behind the consumer is from the latest messages in the Kafka topic.

### Message Processing Time
Shows the average time taken to process each message.

### Message Retries
Displays the rate of message processing retries.

### Kafka Broker Metrics
Shows metrics from the Kafka brokers themselves, including messages in/out and bytes in/out.

### Message Success vs. Failure Rate
Compares the number of successfully processed messages to failed messages.

### Message Processing Distribution
Shows the distribution of message processing outcomes (success, retry, failure).
