import json
import logging
import time
import random
import os
from kafka import KafkaProducer
from datetime import datetime

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def create_producer():
    # Get configuration from environment or use defaults
    bootstrap_servers = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    
    # Create producer with JSON serializer
    producer = KafkaProducer(
        bootstrap_servers=bootstrap_servers,
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        # Add any additional configuration as needed
    )
    
    return producer

def generate_sample_message():
    """Generate a sample message in the correct JSON format"""
    message_types = ['post', 'comment', 'like', 'share']
    user_ids = list(range(1, 101))
    
    message = {
        'id': random.randint(1000, 9999),
        'type': random.choice(message_types),
        'user_id': random.choice(user_ids),
        'content': f"Sample content #{random.randint(1, 1000)}",
        'timestamp': datetime.now().isoformat(),
        'metadata': {
            'source': 'producer-example',
            'version': '1.0'
        }
    }
    
    return message

def main():
    producer = create_producer()
    topic = os.environ.get('KAFKA_TOPIC', 'posts')
    message_count = int(os.environ.get('MESSAGE_COUNT', '0'))  # 0 means infinite
    delay_seconds = float(os.environ.get('DELAY_SECONDS', '10.0'))
    
    logger.info(f"Starting Kafka producer for topic: {topic}")
    count = 0
    
    try:
        while message_count == 0 or count < message_count:
            # Generate and send message
            message = generate_sample_message()
            
            # Send to Kafka
            future = producer.send(topic, message)
            result = future.get(timeout=60)  # Block until message is sent or timeout
            
            logger.info(f"Message {count} sent to {result.topic} partition {result.partition} offset {result.offset}")
            count += 1
            
            # Sleep before sending next message
            time.sleep(delay_seconds)
            
    except KeyboardInterrupt:
        logger.info("Producer stopped by user")
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
    finally:
        # Flush and close producer
        producer.flush()
        producer.close()
        logger.info("Producer closed")

if __name__ == "__main__":
    main()