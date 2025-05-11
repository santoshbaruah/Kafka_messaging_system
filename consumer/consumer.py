import os
import json
import logging
import traceback
import time
from datetime import datetime
from kafka import KafkaConsumer, KafkaProducer, TopicPartition
from kafka.errors import KafkaError

# Import our custom modules
from circuit_breaker import CircuitBreaker, CircuitBreakerError
from metrics_exporter import get_metrics

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Get configuration from environment variables
kafka_broker_url = os.environ.get("KAFKA_BROKER_URL", "kafka-1:29092,kafka-2:29092,kafka-3:29092")
# Also check for KAFKA_BOOTSTRAP_SERVERS which is a common environment variable name
kafka_bootstrap_servers = os.environ.get("KAFKA_BOOTSTRAP_SERVERS", kafka_broker_url)
# Split the broker URL by comma to handle multiple brokers
kafka_brokers = kafka_bootstrap_servers.split(",")
kafka_topic = os.environ.get("KAFKA_TOPIC", "posts")
kafka_dlq_topic = os.environ.get("KAFKA_DLQ_TOPIC", f"{kafka_topic}.dlq")
max_retries = int(os.environ.get("MAX_RETRIES", "3"))
group_id = os.environ.get("KAFKA_GROUP_ID", "kafka-consumer-group")
sasl_mechanism = os.environ.get("KAFKA_SASL_MECHANISM", None)
security_protocol = os.environ.get("KAFKA_SECURITY_PROTOCOL", "PLAINTEXT")
sasl_username = os.environ.get("KAFKA_SASL_USERNAME", None)
sasl_password = os.environ.get("KAFKA_SASL_PASSWORD", None)
metrics_port = int(os.environ.get("METRICS_PORT", "8000"))

# Initialize metrics
metrics = get_metrics(metrics_port)

# Safe deserializer function that handles JSON parsing errors
def safe_json_deserializer(m):
    if m is None:
        return None

    try:
        return json.loads(m.decode('utf-8'))
    except json.JSONDecodeError as e:
        logger.warning(f"Failed to decode JSON message: {e}. Treating as raw text.")
        # Return a default object instead of crashing
        return {"error": "Invalid JSON format", "raw_message": m.decode('utf-8', errors='replace')}

# Configure Kafka consumer with security if enabled
consumer_config = {
    'bootstrap_servers': kafka_brokers,
    'auto_offset_reset': 'earliest',
    'value_deserializer': safe_json_deserializer,
    'group_id': group_id,
    'enable_auto_commit': False,  # Manual commit for better error handling
    'auto_commit_interval_ms': 5000,
    'retry_backoff_ms': 500,
    'request_timeout_ms': 30000
}

# Configure Kafka producer for DLQ
producer_config = {
    'bootstrap_servers': kafka_brokers,
    'value_serializer': lambda m: json.dumps(m).encode('utf-8'),
    'acks': 'all',
    'retries': 3,
    'retry_backoff_ms': 500,
    'request_timeout_ms': 30000
}

# Add security configuration if SASL is enabled
if sasl_mechanism and sasl_username and sasl_password:
    logger.info(f"Using SASL authentication with mechanism {sasl_mechanism}")
    security_config = {
        'security_protocol': security_protocol,
        'sasl_mechanism': sasl_mechanism,
        'sasl_plain_username': sasl_username,
        'sasl_plain_password': sasl_password
    }
    consumer_config.update(security_config)
    producer_config.update(security_config)

def send_to_dlq(producer, message, exception):
    """Send failed message to Dead Letter Queue"""
    error_type = type(exception).__name__

    dlq_message = {
        'original_message': message.value,
        'topic': message.topic,
        'partition': message.partition,
        'offset': message.offset,
        'timestamp': datetime.now().isoformat(),
        'error': str(exception),
        'error_type': error_type,
        'stacktrace': traceback.format_exc()
    }

    try:
        producer.send(kafka_dlq_topic, dlq_message).get(timeout=10)
        logger.info(f"Message sent to DLQ topic '{kafka_dlq_topic}'")

        # Record DLQ metric
        metrics.record_dlq_message(message.topic, error_type)

        return True
    except Exception as e:
        logger.error(f"Failed to send message to DLQ: {e}")
        return False

# Create circuit breaker for external service calls
external_service_cb = CircuitBreaker(
    name="external-service",
    failure_threshold=5,
    reset_timeout=60,
    half_open_max_calls=2
)

@external_service_cb
def call_external_service(data):
    """
    Example function that calls an external service.
    This is protected by a circuit breaker.
    """
    # Simulate an external service call
    # In a real application, this would be an API call or database query

    # Simulate failures for testing circuit breaker
    import random

    # Check if this is a test message with force_failure flag
    if isinstance(data, dict) and isinstance(data.get('metadata'), dict) and data.get('metadata', {}).get('force_failure', False):
        # Higher chance of failure for test messages
        if random.random() < 0.6:  # 60% chance of failure for test messages
            raise ConnectionError("Simulated external service failure")
    elif random.random() < 0.3:  # 30% chance of failure for regular messages
        raise ConnectionError("Simulated external service failure")

    # Simulate processing delay
    time.sleep(0.1)

    return {"processed": True, "data": data}

def process_message(message):
    """Process a message from Kafka"""
    start_time = time.time()

    try:
        # Log the received message with partition and offset info
        logger.info(f"Processing message: Partition={message.partition}, Offset={message.offset}")

        value = message.value
        if isinstance(value, dict) and "error" in value and "raw_message" in value:
            # This is a message that couldn't be parsed as JSON
            logger.warning(f"Processing raw text message: {value.get('raw_message')[:50]}...")
            # Add your business logic for handling non-JSON messages
            result = True
        else:
            # Process valid JSON message
            logger.info(f"Processing JSON message: {value}")

            # Simulate random failures for testing DLQ
            import random
            # Check if this is a test message with force_failure flag
            if isinstance(value, dict) and isinstance(value.get('metadata'), dict) and value.get('metadata', {}).get('force_failure', False):
                # Higher chance of failure for test messages
                if random.random() < 0.3:  # 30% chance of failure for test messages
                    raise ValueError("Simulated random processing failure")
            elif random.random() < 0.1:  # 10% chance of failure for regular messages
                raise ValueError("Simulated random processing failure")

            # Example of calling an external service with circuit breaker protection
            try:
                result = call_external_service(value)
                logger.info(f"External service result: {result}")
            except CircuitBreakerError as e:
                logger.warning(f"Circuit breaker prevented external service call: {e}")
                # Handle the circuit breaker error - maybe send to DLQ or retry later
                raise

            # Your actual message processing logic here
            result = True

        # Record successful processing
        processing_time = time.time() - start_time
        metrics.record_message_processed(message.topic, message.partition, 'success')
        metrics.record_processing_time(message.topic, processing_time)
        metrics.record_processing_time_summary(message.topic, processing_time)

        # Update health status to healthy
        metrics.update_health_status(True)

        return result

    except Exception as e:
        # Record processing error
        error_type = type(e).__name__
        metrics.record_processing_error(message.topic, error_type)
        metrics.record_message_processed(message.topic, message.partition, 'failure')

        # Update health status based on error type
        # Only mark as unhealthy for serious errors
        if error_type in ['ConnectionError', 'KafkaError', 'CircuitBreakerError']:
            metrics.update_health_status(False)

        # Re-raise the exception to be handled by the caller
        raise

def update_lag_metrics(consumer, topic):
    """Update consumer lag metrics"""
    try:
        # Get the partitions for the topic
        partitions = consumer.partitions_for_topic(topic)
        if not partitions:
            return

        # Create TopicPartition objects
        topic_partitions = [TopicPartition(topic, p) for p in partitions]

        # Get the end offsets (latest available message offsets)
        end_offsets = consumer.end_offsets(topic_partitions)

        # Get the current positions for the consumer
        current_positions = {tp: consumer.position(tp) for tp in topic_partitions}

        # Calculate and update lag for each partition
        for tp in topic_partitions:
            if tp in end_offsets and tp in current_positions:
                lag = end_offsets[tp] - current_positions[tp]
                metrics.update_consumer_lag(topic, tp.partition, consumer.config['group_id'], lag)
    except Exception as e:
        logger.error(f"Error updating lag metrics: {e}")

def main():
    try:
        # Create consumer with the configuration
        consumer = KafkaConsumer(
            kafka_topic,
            **consumer_config
        )

        # Create producer for DLQ
        producer = KafkaProducer(**producer_config)

        logger.info(f"Connected to Kafka brokers at {kafka_brokers}")
        logger.info(f"Listening for messages on topic '{kafka_topic}'...")
        logger.info(f"DLQ configured at topic '{kafka_dlq_topic}'")
        logger.info(f"Metrics server started on port {metrics_port}")

        # Initialize health status as healthy
        metrics.update_health_status(True)

        # Process messages
        for message in consumer:
            try:
                logger.info(f"Received message: Partition={message.partition}, Offset={message.offset}")

                # Update lag metrics periodically
                if message.offset % 10 == 0:  # Update every 10 messages
                    update_lag_metrics(consumer, kafka_topic)

                # Process the message with retry logic
                retry_count = 0
                while retry_count <= max_retries:
                    try:
                        # Process the message
                        process_message(message)
                        break  # Success, exit retry loop
                    except CircuitBreakerError as e:
                        # Circuit breaker is open, send to DLQ immediately
                        logger.warning(f"Circuit breaker error: {e}")
                        send_to_dlq(producer, message, e)
                        break
                    except Exception as e:
                        retry_count += 1
                        if retry_count <= max_retries:
                            # Record retry metric
                            metrics.record_message_retry(message.topic)
                            logger.warning(f"Retry {retry_count}/{max_retries} for message: {e}")
                            time.sleep(1 * retry_count)  # Exponential backoff
                        else:
                            # Max retries exceeded, re-raise
                            raise

                # Commit the offset after successful processing
                consumer.commit()

            except Exception as e:
                logger.error(f"Error processing message: {e}")
                logger.error(traceback.format_exc())

                # Send to DLQ
                if send_to_dlq(producer, message, e):
                    # Commit the offset even though processing failed
                    # This prevents the same message from being reprocessed
                    consumer.commit()
                else:
                    # If we couldn't send to DLQ, we might want to retry or take other action
                    # For now, we'll just log and continue
                    logger.error("Failed to send to DLQ, continuing to next message")

    except KafkaError as e:
        logger.error(f"Error connecting to Kafka: {e}")
        raise
    except KeyboardInterrupt:
        logger.info("Consumer stopped by user")
        consumer.close()
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        logger.error(traceback.format_exc())
        raise
    finally:
        try:
            consumer.close()
            logger.info("Consumer closed")
        except:
            pass

if __name__ == "__main__":
    main()
