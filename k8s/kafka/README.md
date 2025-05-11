# Kafka Cluster Setup

## Partition and Replication Strategy

For the `posts` topic, we've implemented the following strategy:

### Partitions: 6

Reasoning:
- Parallelism: With 6 partitions, we can have multiple consumer instances processing messages in parallel, which increases throughput.
- Scalability: This allows us to scale our consumer application horizontally up to 6 instances (one partition per consumer instance in a consumer group).
- Load Distribution: Multiple partitions distribute the load across Kafka brokers.
- Future Growth: Provides room for growth as the system scales. It's better to start with more partitions than needed since partitions cannot be easily added later without rebalancing.

### Replication Factor: 2

Reasoning:
- High Availability: With a replication factor of 2, each partition has one replica, ensuring that data is not lost if a single broker fails.
- Fault Tolerance: The system can continue to operate even if one broker goes down.
- Resource Efficiency: While a replication factor of 3 would provide even better fault tolerance, 2 is a good balance for our initial setup with 2 brokers, as it ensures data redundancy without excessive resource usage.

### Additional Configurations:

- Min In-Sync Replicas: Set to 1 to ensure that at least one replica must acknowledge writes.
- Retention Period: Set to 7 days (604,800,000 ms) to retain messages for a reasonable period while managing storage.

## Local Development Setup

For local development and testing, developers can:

1. Use the provided Docker Compose setup in the `local-dev` directory.
2. Run `docker-compose up` to start a local Kafka cluster.
3. Connect to Kafka at `localhost:9093` (the external port exposed by our Kafka setup).

The Python applications are already configured to connect to this address by default if no environment variables are provided.
