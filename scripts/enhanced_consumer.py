import json
import logging
import os
import time
import random
import traceback
from kafka import KafkaConsumer

# Import the circuit breaker
from circuit_breaker import CircuitBreaker, CircuitBreakerError

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Safe deserializer function that handles JSON parsing errors
def safe_json_deserializer(m):
    if m is None:
        return None
        
    try:
        decoded = m.decode('utf-8')
        logger.debug(f"Attempting to parse: {decoded[:100]}...")
        return json.loads(decoded)
    except json.JSONDecodeError as e:
        logger.warning(f"Failed to decode JSON message: {e}. Raw message: {m[:50]}...")
        # Return a default object instead of crashing
        return {"error": "Invalid JSON format", "raw_message": m.decode('utf-8', errors='replace')}
    except Exception as e:
        logger.error(f"Unexpected error deserializing message: {str(e)}")
        return {"error": str(e), "raw_message": "Could not decode message"}

# Create circuit breaker for external service calls
external_service_cb = CircuitBreaker(
    name="external-service",
    failure_threshold=3,
    reset_timeout=30,
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

    # Simulate random failures for testing circuit breaker
    if random.random() < 0.4:  # 40% chance of failure
        logger.warning("External service call failed (simulated)")
        raise ConnectionError("Simulated external service failure")

    # Simulate processing delay
    time.sleep(0.1)
    
    logger.info(f"External service processed data successfully: {data}")
    return {"processed": True, "data": data}

def process_message(message):
    """Process a message with circuit breaker protection"""
    try:
        # Log the received message
        logger.info(f"Processing message: Topic={message.topic}, Partition={message.partition}, Offset={message.offset}")
        
        # Process the message value
        value = message.value
        if isinstance(value, dict) and "error" in value:
            # This is a message that couldn't be parsed as JSON
            logger.warning(f"Processing raw text message: {value.get('raw_message')[:50]}...")
            return True
        
        # Process valid JSON message
        logger.info(f"Processing JSON message: {value}")
        
        # Example of calling an external service with circuit breaker protection
        try:
            result = call_external_service(value)
            logger.info(f"External service result: {result}")
        except CircuitBreakerError as e:
            logger.warning(f"Circuit breaker prevented external service call: {e}")
            # In a real application, you might want to handle this differently
            # For example, you could send to a DLQ or implement a fallback
            return False
        except Exception as e:
            logger.error(f"Error calling external service: {e}")
            return False
            
        return True
        
    except Exception as e:
        logger.error(f"Error processing message: {e}")
        logger.error(traceback.format_exc())
        return False

def main():
    # Wait for Kafka to be ready
    logger.info("Starting Kafka consumer with circuit breaker...")
    time.sleep(5)
    
    # Get configuration from environment
    bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'kafka-service:9092')
    topic = os.environ.get('KAFKA_TOPIC', 'posts')
    group_id = os.environ.get('KAFKA_GROUP_ID', 'kafka-consumer-group')
    
    logger.info(f"Connecting to Kafka at {bootstrap_servers}")
    logger.info(f"Subscribing to topic: {topic}")
    
    # Initialize the consumer with the safe deserializer
    consumer = KafkaConsumer(
        topic,
        bootstrap_servers=[bootstrap_servers],
        auto_offset_reset='earliest',
        group_id=group_id,
        value_deserializer=safe_json_deserializer
    )
    
    logger.info("Consumer initialized with circuit breaker. Waiting for messages...")
    
    try:
        for message in consumer:
            process_message(message)
    except KeyboardInterrupt:
        logger.info("Consumer stopped by user")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        traceback.print_exc()
    finally:
        consumer.close()
        logger.info("Consumer closed")

if __name__ == "__main__":
    main()
