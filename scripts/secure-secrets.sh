#!/bin/bash

# Script to secure secrets in the Terraform code
# This script converts hardcoded secrets to environment variables or Kubernetes secrets

# Set base directory for Terraform code
TERRAFORM_DIR="/Users/santoshbaruah/Developer/DevOps-Challenge-main/terraform"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

echo -e "${BLUE}===========================================================${RESET}"
echo -e "${BLUE}      Terraform Secrets Security - Starting Fixes          ${RESET}"
echo -e "${BLUE}===========================================================${RESET}"
echo ""

# Create a Kubernetes secret for Kafka credentials
echo -e "${YELLOW}Creating Kubernetes secret for Kafka credentials...${RESET}"

cat > "$TERRAFORM_DIR/kafka-secret.tf" << 'EOF'
# Kafka credentials Secret
resource "kubernetes_secret" "kafka_credentials" {
  metadata {
    name      = "kafka-credentials"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "admin-username"     = "admin"
    "admin-password"     = var.kafka_admin_password
    "producer-username"  = "producer"
    "producer-password"  = var.kafka_producer_password
    "consumer-username"  = "consumer"
    "consumer-password"  = var.kafka_consumer_password
  }
}
EOF

echo -e "${GREEN}Created kafka-secret.tf${RESET}"

# Create variables for Kafka credentials
echo -e "${YELLOW}Creating variables for Kafka credentials...${RESET}"

cat > "$TERRAFORM_DIR/variables.tf" << 'EOF'
variable "kafka_admin_password" {
  description = "Password for Kafka admin user"
  type        = string
  default     = "admin-secret"
  sensitive   = true
}

variable "kafka_producer_password" {
  description = "Password for Kafka producer user"
  type        = string
  default     = "producer-secret"
  sensitive   = true
}

variable "kafka_consumer_password" {
  description = "Password for Kafka consumer user"
  type        = string
  default     = "consumer-secret"
  sensitive   = true
}

variable "grafana_admin_password" {
  description = "Password for Grafana admin user"
  type        = string
  default     = "admin@Grafana123!"
  sensitive   = true
}
EOF

echo -e "${GREEN}Created variables.tf${RESET}"

# Update JAAS ConfigMap to use variables
echo -e "${YELLOW}Updating JAAS ConfigMap to use variables...${RESET}"

cat > "$TERRAFORM_DIR/kafka-configmap.tf" << 'EOF'
# Kafka JAAS ConfigMap
resource "kubernetes_config_map" "kafka_jaas_config" {
  metadata {
    name      = "kafka-jaas-config"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "kafka-jaas.conf" = <<-EOT
      KafkaServer {
        org.apache.kafka.common.security.scram.ScramLoginModule required
        username="admin"
        password="${var.kafka_admin_password}";
      };

      Client {
        org.apache.kafka.common.security.scram.ScramLoginModule required
        username="admin"
        password="${var.kafka_admin_password}";
      };
    EOT
  }
}

# Consumer JAAS ConfigMap
resource "kubernetes_config_map" "consumer_jaas_config" {
  metadata {
    name      = "consumer-jaas-config"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "consumer-jaas.conf" = <<-EOT
      KafkaClient {
        org.apache.kafka.common.security.scram.ScramLoginModule required
        username="consumer"
        password="${var.kafka_consumer_password}";
      };
    EOT
  }
}

# Producer JAAS ConfigMap
resource "kubernetes_config_map" "producer_jaas_config" {
  metadata {
    name      = "producer-jaas-config"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "producer-jaas.conf" = <<-EOT
      KafkaClient {
        org.apache.kafka.common.security.scram.ScramLoginModule required
        username="producer"
        password="${var.kafka_producer_password}";
      };
    EOT
  }
}
EOF

echo -e "${GREEN}Created kafka-configmap.tf${RESET}"

# Create a .gitignore file to ignore sensitive files
echo -e "${YELLOW}Creating .gitignore for sensitive files...${RESET}"

cat > "$TERRAFORM_DIR/.gitignore" << 'EOF'
# Local .terraform directories
/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files, which are likely to contain sensitive data
*.tfvars
*.tfvars.json

# Ignore override files as they are usually used to override resources locally
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# Ignore CLI configuration files
.terraformrc
terraform.rc

# Ignore sensitive environment files
.env
*.env

# Ignore security reports
security-reports/
EOF

echo -e "${GREEN}Created .gitignore${RESET}"

# Create a terraform.tfvars.example file
echo -e "${YELLOW}Creating terraform.tfvars.example file...${RESET}"

cat > "$TERRAFORM_DIR/terraform.tfvars.example" << 'EOF'
# Example terraform.tfvars file
# Copy this file to terraform.tfvars and update with your own values

# Kafka credentials
kafka_admin_password     = "admin-secret"
kafka_producer_password  = "producer-secret"
kafka_consumer_password  = "consumer-secret"

# Grafana credentials
grafana_admin_password   = "admin@Grafana123!"
EOF

echo -e "${GREEN}Created terraform.tfvars.example${RESET}"

echo -e "${BLUE}===========================================================${RESET}"
echo -e "${BLUE}      Terraform Secrets Security - Fixes Completed          ${RESET}"
echo -e "${BLUE}===========================================================${RESET}"
echo ""
echo -e "${YELLOW}Next steps:${RESET}"
echo -e "1. Create a terraform.tfvars file with your actual secrets"
echo -e "2. Update any references to hardcoded secrets in the modules"
echo -e "3. Consider using a secrets management solution like HashiCorp Vault"
echo ""
