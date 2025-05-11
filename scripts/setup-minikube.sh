#!/bin/bash
set -e

echo "Setting up Minikube for Kafka cluster testing..."

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "Minikube not found. Please install Minikube first."
    exit 1
fi

# Start minikube with sufficient resources for Kafka
echo "Starting Minikube with 4 CPUs and 8GB RAM..."
minikube start --cpus=4 --memory=8192 --disk-size=20g

# Enable necessary addons
echo "Enabling necessary addons..."
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable ingress

# Set up Docker environment to use Minikube's Docker daemon
echo "Configuring Docker to use Minikube's Docker daemon..."
eval $(minikube docker-env)

echo "Minikube setup complete. You can now deploy the Kafka cluster."
echo "To access the Kubernetes dashboard, run: minikube dashboard"
