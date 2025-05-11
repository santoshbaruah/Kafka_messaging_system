# Troubleshooting Guide

This guide provides solutions for common issues you might encounter with the Kafka messaging system.

## Table of Contents

- [Automated Diagnostics and Fixes](#automated-diagnostics-and-fixes)
- [Kafka Issues](#kafka-issues)
- [Monitoring Issues](#monitoring-issues)
- [Grafana Dashboard Issues](#grafana-dashboard-issues)
- [Message Sending/Receiving Issues](#message-sendingreceiving-issues)
- [Common Error Messages](#common-error-messages)

## Automated Diagnostics and Fixes

The system includes an automated diagnostic and fix tool that can identify and resolve many common issues:


# Run the auto-test and auto-fix tool
./scripts/auto-test-fix.sh


This script will:
1. Test all components of the system
2. Identify any issues
3. Offer to automatically fix the issues it finds

## Kafka Issues

### Kafka Containers Restarting

If Kafka containers are constantly restarting:


# Check the logs
docker logs kafka-1

# Fix JMX configuration issues
./scripts/fix-kafka-jmx.sh

# Restart the containers
./scripts/restart-monitoring.sh


### Topic Creation Failures

If topics aren't being created:


# Check if Zookeeper is running
docker ps | grep zookeeper

# Manually create the topics
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic posts --partitions 6 --replication-factor 3 --config min.insync.replicas=2
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic posts.dlq --partitions 6 --replication-factor 3 --config min.insync.replicas=2


## Monitoring Issues

### Prometheus Not Collecting Metrics

If Prometheus isn't collecting metrics:


# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | grep "state"

# Fix JMX configuration
./scripts/fix-kafka-jmx.sh

# Restart monitoring
./scripts/restart-monitoring.sh


### Consumer Metrics Not Available

If consumer metrics aren't available:


# Check if the consumer is running
docker ps | grep kafka-consumer

# Check the consumer logs
docker logs kafka-consumer

# Restart the consumer
docker restart kafka-consumer


## Grafana Dashboard Issues

### No Data in Dashboards

If Grafana dashboards aren't showing data:


# Check if Prometheus is configured as a data source
curl -s -u admin:admin123 http://localhost:3000/api/datasources

# Generate test metrics
./scripts/test-grafana-dashboard.sh

# Check if metrics are being collected
curl -s http://localhost:9090/api/v1/query?query=kafka_server_brokertopicmetrics_messagesin_total


### Grafana Login Issues

If you can't log in to Grafana:


# Reset the Grafana admin password
docker exec -it grafana grafana-cli admin reset-admin-password admin123


## Message Sending/Receiving Issues

### Can't Send Messages

If you can't send messages to Kafka:


# Check if Kafka is running
docker ps | grep kafka

# Test sending a message
./scripts/send-test-message.sh

# Check Kafka logs
docker logs kafka-1


### Can't Receive Messages

If the consumer isn't receiving messages:


# Check consumer logs
docker logs kafka-consumer

# Restart the consumer
docker restart kafka-consumer

# Check if messages are in the topic
docker exec kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic posts --from-beginning --max-messages 5


## Common Error Messages

### "OCI runtime exec failed: exec failed: unable to start container process: exec: 'bash': executable file not found in $PATH"

This error occurs when trying to execute bash in a container that doesn't have bash installed.

**Solution:**

# Use the auto-fix script
./scripts/auto-test-fix.sh

# Or manually fix the JMX configuration
./scripts/fix-kafka-jmx.sh


### "Address already in use"

This error occurs when JMX tries to bind to a port that's already in use.

**Solution:**

# Fix JMX configuration
./scripts/fix-kafka-jmx.sh

# Restart the containers
./scripts/restart-monitoring.sh


### "cat: /tmp/all_messages.txt: Permission denied"

This error occurs when the Kafka container can't read the message file.

**Solution:**

# Use the auto-fix script
./scripts/auto-test-fix.sh

# Or manually fix the permissions
docker exec kafka-1 chmod 644 /tmp/all_messages.txt


### "No Prometheus targets are up"

This error indicates that Prometheus can't scrape metrics from any targets.

**Solution:**

# Fix JMX configuration
./scripts/fix-kafka-jmx.sh

# Restart monitoring
./scripts/restart-monitoring.sh

# Generate metrics
./scripts/generate-metrics.sh

