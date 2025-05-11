import os
import json
import logging
import time
from kafka import KafkaProducer
from kafka.errors import KafkaError
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get configuration from environment variables
kafka_broker_url = os.environ.get("KAFKA_BROKER_URL", "localhost:9093")
# Split the broker URL by comma to handle multiple brokers
kafka_brokers = kafka_broker_url.split(",")
kafka_topic = os.environ.get("KAFKA_TOPIC", "posts")
sasl_mechanism = os.environ.get("KAFKA_SASL_MECHANISM", None)
security_protocol = os.environ.get("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")
sasl_username = os.environ.get("KAFKA_SASL_USERNAME", None)
sasl_password = os.environ.get("KAFKA_SASL_PASSWORD", None)
message_count = int(os.environ.get("MESSAGE_COUNT", "5"))
message_interval = float(os.environ.get("MESSAGE_INTERVAL", "1.0"))

# Configure Kafka producer with security if enabled
producer_config = {
    'bootstrap_servers': kafka_brokers,
    'value_serializer': lambda v: json.dumps(v).encode('utf-8'),
    'acks': 'all',  # Wait for all replicas to acknowledge
    'retries': 3,   # Retry on failure
    'linger_ms': 5  # Small delay to allow batching
}

# Add security configuration if SASL is enabled
if sasl_mechanism and sasl_username and sasl_password:
    logger.info(f"Using SASL authentication with mechanism {sasl_mechanism}")
    producer_config.update({
        'security_protocol': security_protocol,
        'sasl_mechanism': sasl_mechanism,
        'sasl_plain_username': sasl_username,
        'sasl_plain_password': sasl_password
    })

try:
    # Create producer with the configuration
    producer = KafkaProducer(**producer_config)

    logger.info(f"Connected to Kafka brokers at {kafka_brokers}")

    # Send messages
    i = 0
    try:
        # If message_count is 0, run indefinitely
        while message_count == 0 or i < message_count:
            # Create message
            message = {
                "sender": "kafka-producer",
                "content": f"message {i}",
                "created_at": datetime.now().isoformat(),
                "metadata": {
                    "producer_id": os.environ.get("HOSTNAME", "unknown"),
                    "sequence": i
                }
            }

            # Send message
            future = producer.send(kafka_topic, message)

            # Wait for the message to be delivered
            record_metadata = future.get(timeout=10)

            logger.info(f"Message {i} sent to {record_metadata.topic} partition {record_metadata.partition} offset {record_metadata.offset}")

            # Wait before sending the next message
            time.sleep(message_interval)
            i += 1
    except KeyboardInterrupt:
        logger.info("Producer interrupted by user")
    finally:
        # Flush and close the producer
        producer.flush()
        producer.close()

        logger.info(f"Successfully sent {i} messages to topic {kafka_topic}")

except KafkaError as e:
    logger.error(f"Error sending message to Kafka: {e}")
    raise
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    raise
