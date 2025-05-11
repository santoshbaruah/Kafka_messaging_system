.PHONY: build-images deploy-kafka deploy-apps deploy-monitoring local-dev enhanced-local-dev clean help

# Variables
KAFKA_VERSION := 7.3.2
NAMESPACE := default

help:
	@echo "Available commands:"
	@echo "  make build-images       - Build Docker images for producer and consumer"
	@echo "  make deploy-kafka       - Deploy Kafka cluster to Kubernetes"
	@echo "  make deploy-apps        - Deploy producer and consumer apps to Kubernetes"
	@echo "  make deploy-monitoring  - Deploy monitoring stack (Prometheus, Grafana)"
	@echo "  make local-dev          - Start local development environment with Docker Compose"
	@echo "  make enhanced-local-dev - Start enhanced local development environment"
	@echo "  make clean              - Remove all resources"
	@echo "  make help               - Show this help message"

build-images:
	@echo "Building Docker images..."
	docker build -t kafka-producer:latest producer/
	docker build -t kafka-consumer:latest consumer/
	@echo "Images built successfully"

deploy-kafka:
	@echo "Deploying Kafka cluster..."
	kubectl apply -f k8s/kafka/zookeeper.yaml
	kubectl apply -f k8s/kafka/kafka.yaml
	sleep 30
	kubectl apply -f k8s/kafka/topic.yaml
	@echo "Kafka cluster deployed successfully"

deploy-apps:
	@echo "Deploying applications..."
	kubectl apply -f k8s/apps/consumer.yaml
	kubectl apply -f k8s/apps/producer.yaml
	@echo "Applications deployed successfully"

deploy-monitoring:
	@echo "Deploying monitoring stack..."
	kubectl apply -f k8s/monitoring/prometheus.yaml
	kubectl apply -f k8s/monitoring/grafana.yaml
	kubectl apply -f k8s/monitoring/kafka-jmx-exporter.yaml
	@echo "Monitoring stack deployed successfully"

local-dev:
	@echo "Starting local development environment..."
	cd local-dev && docker-compose up -d
	@echo "Local environment started. Access Kafka at localhost:9093"

enhanced-local-dev:
	@echo "Starting enhanced local development environment..."
	./scripts/start-enhanced-local-dev.sh

clean:
	@echo "Cleaning up resources..."
	kubectl delete -f k8s/apps/ --ignore-not-found
	kubectl delete -f k8s/monitoring/ --ignore-not-found
	kubectl delete -f k8s/kafka/ --ignore-not-found
	cd local-dev && docker-compose down
	cd local-dev && docker-compose -f docker-compose.enhanced.yaml down
	@echo "Cleanup completed"

terraform-init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init
	@echo "Terraform initialized"

terraform-apply:
	@echo "Applying Terraform configuration..."
	cd terraform && terraform apply
	@echo "Terraform applied"

terraform-destroy:
	@echo "Destroying Terraform resources..."
	cd terraform && terraform destroy
	@echo "Terraform resources destroyed"
