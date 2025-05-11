#!/bin/bash
set -e

# Function to check if pods are ready
wait_for_pods() {
    namespace=$1
    label=$2
    expected_count=$3
    timeout=$4

    echo "Waiting for $expected_count $label pods to be ready in namespace $namespace..."

    start_time=$(date +%s)
    while true; do
        ready_count=$(kubectl get pods -n $namespace -l $label -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' | grep -c "true" || echo 0)

        if [ "$ready_count" -eq "$expected_count" ]; then
            echo "All $label pods are ready!"
            break
        fi

        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        if [ "$elapsed_time" -gt "$timeout" ]; then
            echo "Timeout waiting for $label pods to be ready"
            kubectl get pods -n $namespace -l $label
            exit 1
        fi

        echo "Waiting for pods to be ready: $ready_count/$expected_count ready"
        sleep 5
    done
}

# Create namespace
echo "Creating kafka namespace..."
kubectl create namespace kafka --dry-run=client -o yaml | kubectl apply -f -

# Build Docker images
echo "Building Docker images..."
docker build -t kafka-consumer:latest consumer/
docker build -t kafka-producer:latest producer/

# Deploy Zookeeper
echo "Deploying Zookeeper..."
kubectl apply -f k8s/kafka/zookeeper.yaml -n kafka
wait_for_pods "kafka" "app=zookeeper" 1 300

# Deploy Kafka
echo "Deploying Kafka brokers..."
kubectl apply -f k8s/kafka/kafka.yaml -n kafka
wait_for_pods "kafka" "app=kafka" 2 600

# Create Kafka topic
echo "Creating Kafka topic..."
kubectl apply -f k8s/kafka/topic.yaml -n kafka
sleep 30  # Give some time for the job to complete

# Check if topic was created successfully
echo "Verifying topic creation..."
kubectl exec -it $(kubectl get pods -n kafka -l app=kafka -o jsonpath='{.items[0].metadata.name}') -n kafka -- \
  kafka-topics --describe --bootstrap-server localhost:9092 --topic posts

# Deploy monitoring
echo "Deploying monitoring stack..."
kubectl apply -f k8s/monitoring/prometheus.yaml -n kafka
kubectl apply -f k8s/monitoring/grafana.yaml -n kafka
kubectl apply -f k8s/monitoring/kafka-jmx-exporter.yaml -n kafka
wait_for_pods "kafka" "app=prometheus" 1 300
wait_for_pods "kafka" "app=grafana" 1 300

# Deploy applications
echo "Deploying consumer and producer applications..."
kubectl apply -f k8s/apps/consumer.yaml -n kafka
kubectl apply -f k8s/apps/producer.yaml -n kafka
wait_for_pods "kafka" "app=kafka-consumer" 2 300
wait_for_pods "kafka" "app=kafka-producer" 1 300

# Test producer and consumer
echo "Testing producer and consumer..."
echo "Producer logs:"
kubectl logs -n kafka -l app=kafka-producer --tail=20

echo "Consumer logs:"
kubectl logs -n kafka -l app=kafka-consumer --tail=20

# Set up port forwarding for Grafana
echo "Setting up port forwarding for Grafana..."
kubectl port-forward -n kafka svc/grafana 3000:3000 &
port_forward_pid=$!

echo "Deployment and testing complete!"
echo "Grafana is available at http://localhost:3000 (admin/admin)"
echo "Press Ctrl+C to stop port forwarding"

# Wait for user to stop port forwarding
wait $port_forward_pid
