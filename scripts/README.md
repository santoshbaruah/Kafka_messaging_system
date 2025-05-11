# Kafka System Scripts

This directory contains scripts for managing and demonstrating the Kafka messaging system.

## Setup Scripts

- `download-jmx-exporter.sh` - Downloads the JMX exporter for Kafka metrics
- `generate-ssl-certs.sh` - Generates SSL certificates for Kafka security
- `setup-minikube.sh` - Sets up Minikube for local Kubernetes development

## Deployment Scripts

- `deploy-and-test.sh` - Deploys and tests the Kafka cluster on Kubernetes
- `start-enhanced-local-dev.sh` - Starts the enhanced local development environment

## Demo Scripts

- `run-demo.sh` - Runs a complete demonstration of the Kafka messaging system
- `send-test-message.sh` - Sends a test message to the Kafka topic
- `direct-message-sender.sh` - Sends multiple test messages with different content
- `test-circuit-breaker.sh` - Tests the circuit breaker functionality
- `view-messages.sh` - Views messages in a Kafka topic with formatting (recommended)
- `view-consumer-venv.sh` - Improved wrapper script that uses a Python virtual environment
- `view-consumer-k8s.sh` - Script to view Kafka messages using kubectl exec (no local dependencies)
- `message-analyzer.py` - Advanced script for viewing and analyzing Kafka messages
- `test-kafka-connection.sh` - Tests Kafka connection and sends a test message

## Monitoring Scripts

- `import-grafana-dashboard.sh` - Imports Grafana dashboards
- `reset-grafana-password.sh` - Resets the Grafana admin password

## Maintenance Scripts

- `kafka-disaster-recovery.sh` - Performs disaster recovery for Kafka
- `scan-terraform.sh` - Scans Terraform code for security issues

## Python Scripts

To use the Python scripts, you have two options:

### Option 1: Use the virtual environment wrapper (Recommended)

# Use the virtual environment wrapper script
./view-consumer-venv.sh

This script automatically creates a Python virtual environment and installs the required dependencies.

### Option 2: Install dependencies manually

# Create a virtual environment
python3 -m venv kafka-venv
source kafka-venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the script
python3 view-consumer.py

### Option 3: Use the helper script (Not recommended for newer macOS systems)

# Note: Some older scripts have been moved to the deprecated directory.
# See scripts/deprecated/README.md for more information.

# Or manually install with pip
pip3 install -r requirements.txt

Note: On newer macOS systems, you may encounter an "externally-managed-environment" error when trying to install packages globally. It's recommended to use a virtual environment instead (Option 1 or 2).

## Usage Examples

### Sending Test Messages

./send-test-message.sh

# Send multiple test messages
./direct-message-sender.sh

### Viewing Messages

# Using kubectl exec (recommended, no local dependencies)
./view-consumer-k8s.sh
./view-consumer-k8s.sh --from-beginning

# Using Python with virtual environment
./view-consumer-venv.sh
FROM_BEGINNING=true ./view-consumer-venv.sh

# Using the original script
./view-messages.sh

### Analyzing Messages

# View and analyze messages
python3 message-analyzer.py

# View and analyze messages from the beginning
python3 message-analyzer.py --from-beginning

### Testing Circuit Breaker

./test-circuit-breaker.sh

### Running a Complete Demo

./run-demo.sh
