#!/usr/bin/env python3

import json
import logging
import os
import sys

# Try to import Kafka, install if not available
try:
    from kafka import KafkaConsumer  # type: ignore # noqa
except ImportError:
    print("Kafka module not found. Installing kafka-python...")
    import subprocess
    try:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "kafka-python>=2.0.0"])
        from kafka import KafkaConsumer  # type: ignore # noqa
    except Exception as e:
        print(f"Error installing kafka-python: {e}")
        print("Please install manually with: pip install kafka-python>=2.0.0")
        sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Disable kafka logger completely to avoid DNS lookup error messages
logging.getLogger('kafka').setLevel(logging.CRITICAL)
logging.getLogger('kafka').propagate = False

# Safe deserializer function that handles JSON parsing errors
def safe_json_deserializer(m):
    if m is None:
        return None

    try:
        decoded = m.decode('utf-8')
        return json.loads(decoded)
    except json.JSONDecodeError as e:
        logger.warning(f"Failed to decode JSON message: {e}")
        return {"error": "Invalid JSON format", "raw_message": m.decode('utf-8', errors='replace')}

def main():
    # Get configuration
    bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')  # Allow override but default to localhost
    topic = os.environ.get('KAFKA_TOPIC', 'posts')
    group_id = os.environ.get('KAFKA_GROUP_ID', 'message-viewer-group')
    from_beginning = os.environ.get('FROM_BEGINNING', 'false').lower() == 'true'

    # Set offset reset strategy based on from_beginning
    auto_offset_reset = 'earliest' if from_beginning else 'latest'

    logger.info(f"Connecting to Kafka at {bootstrap_servers}")
    logger.info(f"Viewing messages from topic: {topic} ({'from beginning' if from_beginning else 'new messages only'})")

    try:
        # Initialize the consumer with the safe deserializer
        consumer = KafkaConsumer(
            topic,
            bootstrap_servers=bootstrap_servers.split(','),
            client_id='view-consumer-client',
            auto_offset_reset=auto_offset_reset,
            group_id=group_id,
            value_deserializer=safe_json_deserializer,
            # Set appropriate timeouts (request_timeout must be >= session_timeout)
            request_timeout_ms=30000,
            session_timeout_ms=10000,
            # Disable auto commit to avoid waiting for commits
            enable_auto_commit=False,
            # Add consumer timeout to avoid blocking forever if no messages
            consumer_timeout_ms=60000  # 60 seconds timeout
        )

        logger.info("Consumer initialized. Waiting for messages...")
        logger.info("Press Ctrl+C to stop viewing")

        message_count = 0
        for message in consumer:
            message_count += 1

            # Format the output nicely
            print("\n" + "=" * 50)
            print(f"Message #{message_count} | Partition: {message.partition} | Offset: {message.offset}")
            print("-" * 50)

            value = message.value
            if isinstance(value, dict) and "error" in value:
                # This is a message that couldn't be parsed as JSON
                print(f"RAW MESSAGE: {value.get('raw_message')}")
            else:
                # Print JSON message nicely formatted
                print(json.dumps(value, indent=2))

            print("=" * 50)
    except KeyboardInterrupt:
        logger.info("\nViewer stopped by user")
    except Exception as e:
        logger.error(f"Error connecting to Kafka: {e}")
        logger.info("Make sure Kafka is running and accessible at the specified bootstrap servers.")
        logger.info(f"Current bootstrap servers: {bootstrap_servers}")
        logger.info("If you're running in Docker, make sure you're using 'localhost:9092' instead of container names.")
        logger.info("You can override the bootstrap servers with the KAFKA_BOOTSTRAP_SERVERS environment variable.")
        sys.exit(1)
    finally:
        try:
            consumer.close()
            logger.info("Consumer closed")
        except:
            pass

if __name__ == "__main__":
    main()