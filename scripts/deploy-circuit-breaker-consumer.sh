#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

echo -e "${BLUE}=== Deploying Enhanced Consumer with Circuit Breaker ===${RESET}"

# Check if we're in a Kubernetes environment
if ! kubectl get namespace kafka &>/dev/null; then
    echo -e "${RED}Error: Kafka namespace not found. Make sure Kubernetes is running.${RESET}"
    exit 1
fi

# Create ConfigMap for the circuit breaker code
echo -e "${YELLOW}Creating ConfigMap for circuit breaker code...${RESET}"
kubectl create configmap -n kafka circuit-breaker-code \
    --from-file=circuit_breaker.py=scripts/circuit_breaker.py \
    --from-file=consumer.py=scripts/enhanced_consumer.py \
    --from-file=requirements.txt=requirements.txt \
    --dry-run=client -o yaml | kubectl apply -f -

# Create or update the deployment
echo -e "${YELLOW}Creating deployment for circuit breaker consumer...${RESET}"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-consumer-circuit-breaker
  namespace: kafka
  labels:
    app: kafka-consumer-circuit-breaker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-consumer-circuit-breaker
  template:
    metadata:
      labels:
        app: kafka-consumer-circuit-breaker
    spec:
      containers:
      - name: consumer
        image: python:3.8-slim
        command: [ "/bin/bash", "-c" ]
        args:
        - |
          pip install -r /app/requirements.txt &&
          cd /app &&
          python consumer.py
        env:
        - name: KAFKA_BOOTSTRAP_SERVERS
          value: "kafka-service:9092"
        - name: KAFKA_TOPIC
          value: "posts"
        - name: KAFKA_GROUP_ID
          value: "kafka-consumer-circuit-breaker-group"
        - name: KAFKA_AUTO_OFFSET_RESET
          value: "earliest"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: consumer-code
          mountPath: /app
      volumes:
      - name: consumer-code
        configMap:
          name: circuit-breaker-code
EOF

echo -e "${GREEN}Deployment created. Waiting for pod to be ready...${RESET}"
kubectl rollout status deployment/kafka-consumer-circuit-breaker -n kafka

echo -e "${GREEN}Enhanced consumer with circuit breaker deployed successfully!${RESET}"
echo -e "${YELLOW}You can now run the test-circuit-breaker.sh script to test the functionality.${RESET}"
