FROM python:3.8-slim AS builder

# Set working directory
WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.8-slim

# Set working directory
WORKDIR /app

# Create a non-root user
RUN useradd -m appuser && \
    chown -R appuser:appuser /app

# Copy only the necessary files from the builder stage
COPY --from=builder /usr/local/lib/python3.8/site-packages /usr/local/lib/python3.8/site-packages
COPY producer.py .

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD python -c "import socket, os; broker = os.environ.get('KAFKA_BROKER_URL', 'localhost:9093').split(',')[0]; host, port = broker.split(':'); socket.socket().connect((host, int(port)))" || exit 1

# Add metadata
LABEL maintainer="DevOps Team" \
      version="1.0" \
      description="Kafka producer application with SASL authentication"

# Run the application
CMD ["python", "producer.py"]
