import time
import threading
import logging
from prometheus_client import start_http_server, Counter, Gauge, Histogram, Summary

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("metrics-exporter")

# Define metrics
class KafkaConsumerMetrics:
    def __init__(self, port=8000):
        self.port = port

        # Message processing metrics
        self.messages_processed = Counter(
            'kafka_consumer_messages_processed_total',
            'Total number of messages processed',
            ['topic', 'partition', 'result']
        )

        self.processing_time = Histogram(
            'kafka_consumer_message_processing_seconds',
            'Time spent processing messages',
            ['topic'],
            buckets=(0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 7.5, 10.0, float('inf'))
        )

        # DLQ metrics
        self.dlq_messages = Counter(
            'kafka_consumer_dlq_messages_total',
            'Total number of messages sent to DLQ',
            ['topic', 'error_type']
        )

        # Lag metrics
        self.consumer_lag = Gauge(
            'kafka_consumer_lag',
            'Lag in number of messages for the consumer',
            ['topic', 'partition', 'group_id']
        )

        # Error metrics
        self.processing_errors = Counter(
            'kafka_consumer_processing_errors_total',
            'Total number of errors during message processing',
            ['topic', 'error_type']
        )

        # Batch metrics
        self.batch_size = Summary(
            'kafka_consumer_batch_size',
            'Size of message batches processed',
            ['topic']
        )

        # Retry metrics
        self.message_retries = Counter(
            'kafka_consumer_message_retries_total',
            'Total number of message processing retries',
            ['topic']
        )

        # Throughput metrics
        self.message_throughput = Gauge(
            'kafka_consumer_throughput_messages_per_second',
            'Number of messages processed per second',
            ['topic']
        )

        # Health status metrics
        self.health_status = Gauge(
            'kafka_consumer_health_status',
            'Health status of the consumer (0=healthy, 1=unhealthy)',
            []
        )

        # Processing time summary
        self.processing_time_summary = Summary(
            'kafka_consumer_processing_time',
            'Summary of message processing time',
            ['topic']
        )

        # Start server in a separate thread
        self.server_thread = threading.Thread(target=self._start_server)
        self.server_thread.daemon = True
        self.server_thread.start()

        # Start throughput calculator
        self.throughput_thread = threading.Thread(target=self._calculate_throughput)
        self.throughput_thread.daemon = True
        self.last_processed_count = {}
        self.throughput_thread.start()

        logger.info(f"Metrics server started on port {self.port}")

    def _start_server(self):
        """Start the HTTP server for exposing metrics"""
        start_http_server(self.port)

    def _calculate_throughput(self):
        """Calculate and update throughput metrics periodically"""
        while True:
            for topic, count in self.last_processed_count.items():
                # Get current count
                current_count = self.messages_processed.labels(topic=topic, partition='all', result='success')._value.get()

                # Calculate throughput (messages per second)
                throughput = (current_count - count) / 5.0

                # Update gauge
                self.message_throughput.labels(topic=topic).set(throughput)

                # Update last count
                self.last_processed_count[topic] = current_count

            # Sleep for 5 seconds
            time.sleep(5)

    def record_message_processed(self, topic, partition, result='success'):
        """Record a processed message"""
        self.messages_processed.labels(topic=topic, partition=str(partition), result=result).inc()

        # Initialize throughput tracking if needed
        if topic not in self.last_processed_count:
            self.last_processed_count[topic] = 0

    def record_processing_time(self, topic, duration):
        """Record time spent processing a message"""
        self.processing_time.labels(topic=topic).observe(duration)

    def record_dlq_message(self, topic, error_type):
        """Record a message sent to DLQ"""
        self.dlq_messages.labels(topic=topic, error_type=error_type).inc()

    def update_consumer_lag(self, topic, partition, group_id, lag):
        """Update consumer lag metric"""
        self.consumer_lag.labels(topic=topic, partition=str(partition), group_id=group_id).set(lag)

    def record_processing_error(self, topic, error_type):
        """Record a processing error"""
        self.processing_errors.labels(topic=topic, error_type=error_type).inc()

    def record_batch_size(self, topic, size):
        """Record batch size"""
        self.batch_size.labels(topic=topic).observe(size)

    def record_message_retry(self, topic):
        """Record a message retry"""
        self.message_retries.labels(topic=topic).inc()

    def update_health_status(self, is_healthy):
        """Update the health status of the consumer"""
        self.health_status.set(0 if is_healthy else 1)

    def record_processing_time_summary(self, topic, duration):
        """Record processing time in the summary metric"""
        self.processing_time_summary.labels(topic=topic).observe(duration)

# Singleton instance
_metrics_instance = None

def get_metrics(port=8000):
    """Get or create the metrics instance"""
    global _metrics_instance
    if _metrics_instance is None:
        _metrics_instance = KafkaConsumerMetrics(port)
    return _metrics_instance
