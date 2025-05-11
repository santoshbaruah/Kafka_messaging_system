import json
import logging
from kafka import KafkaConsumer
import time
import os

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Robust deserializer that handles both JSON and non-JSON messages
def safe_deserializer(message):
    if message is None:
        return None
    
    decoded_message = message.decode('utf-8')
    
    try:
        # Try to deserialize as JSON
        return json.loads(decoded_message)
    except json.JSONDecodeError:
        # If not JSON, return as plain text
        logger.warning(f"Received non-JSON message: {decoded_message[:100]}...")
        return {"raw_message": decoded_message, "parsed": False}

def create_consumer():
    # Get configuration from environment or use defaults
    bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    topic = os.environ.get('KAFKA_TOPIC', 'posts')
    group_id = os.environ.get('KAFKA_GROUP_ID', 'consumer-group')
    auto_offset_reset = os.environ.get('KAFKA_AUTO_OFFSET_RESET', 'earliest')
    
    # Create consumer with the safe deserializer
    consumer = KafkaConsumer(
        topic,
        bootstrap_servers=bootstrap_servers,
        group_id=group_id,
        auto_offset_reset=auto_offset_reset,
        value_deserializer=safe_deserializer,
        # Add any additional configuration as needed
    )
    
    return consumer

def process_message(message):
    """Process the message from Kafka"""
    if not message.value:
        logger.warning("Received empty message")
        return
    
    try:
        if isinstance(message.value, dict):
            if message.value.get('parsed') is False:
                # This is a non-JSON message that was handled by our safe_deserializer
                logger.info(f"Processing raw message: {message.value['raw_message'][:50]}...")
                # Add your logic for handling plain text messages here
            else:
                # This is a properly formatted JSON message
                logger.info(f"Processing JSON message: {message.value}")
                # Add your processing logic here
        else:
            logger.warning(f"Unexpected message format: {type(message.value)}")
    except Exception as e:
        logger.error(f"Error processing message: {str(e)}")
        # You could implement retry logic or send to a DLQ here if needed

def main():
    logger.info("Starting Kafka consumer...")
    consumer = create_consumer()
    
    try:
        for message in consumer:
            logger.info(f"Received message from topic {message.topic}, partition {message.partition}, offset {message.offset}")
            process_message(message)
    except KeyboardInterrupt:
        logger.info("Consumer stopped by user")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
    finally:
        consumer.close()
        logger.info("Consumer closed")

if __name__ == "__main__":
    # Add a small delay on startup to ensure Kafka is ready
    time.sleep(5)
    main()