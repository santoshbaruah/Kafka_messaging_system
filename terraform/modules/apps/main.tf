variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "kafka_service_name" {
  description = "Name of the Kafka service"
  type        = string
  default     = "kafka-service"
}

variable "kafka_topic" {
  description = "Kafka topic name"
  type        = string
  default     = "posts"
}

variable "consumer_replicas" {
  description = "Number of consumer replicas"
  type        = number
  default     = 2
}

variable "producer_replicas" {
  description = "Number of producer replicas"
  type        = number
  default     = 1
}

variable "consumer_image" {
  description = "Consumer Docker image"
  type        = string
  default     = "python:3.8-slim@sha256:1d52838af602b4b5a831beb13a0e4d073280665ea7be7f69ce2382f29c5a613f"
}

variable "producer_image" {
  description = "Producer Docker image"
  type        = string
  default     = "python:3.8-slim@sha256:1d52838af602b4b5a831beb13a0e4d073280665ea7be7f69ce2382f29c5a613f"
}

variable "enable_security" {
  description = "Enable security features"
  type        = bool
  default     = true
}

variable "enable_monitoring" {
  description = "Enable monitoring"
  type        = bool
  default     = true
}

variable "kafka_consumer_password" {
  description = "Password for Kafka consumer user"
  type        = string
  default     = "consumer-secret"
  sensitive   = true
}

variable "kafka_producer_password" {
  description = "Password for Kafka producer user"
  type        = string
  default     = "producer-secret"
  sensitive   = true
}

variable "kafka_admin_password" {
  description = "Password for Kafka admin user"
  type        = string
  default     = "admin-secret"
  sensitive   = true
}

# Consumer JAAS ConfigMap (for security)
resource "kubernetes_config_map" "consumer_jaas_config" {
  count = var.enable_security ? 1 : 0

  metadata {
    name      = "consumer-jaas-config"
    namespace = var.namespace
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

# Producer JAAS ConfigMap (for security)
resource "kubernetes_config_map" "producer_jaas_config" {
  count = var.enable_security ? 1 : 0

  metadata {
    name      = "producer-jaas-config"
    namespace = var.namespace
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

# Kafka credentials Secret
resource "kubernetes_secret" "kafka_credentials" {
  count = var.enable_security ? 1 : 0

  metadata {
    name      = "kafka-credentials"
    namespace = var.namespace
  }

  data = {
    "admin-password"     = var.kafka_admin_password
    "producer-password"  = var.kafka_producer_password
    "consumer-password"  = var.kafka_consumer_password
  }
}

# Consumer Deployment
resource "kubernetes_deployment" "kafka_consumer" {
  metadata {
    name      = "kafka-consumer"
    namespace = var.namespace
    labels = {
      app = "kafka-consumer"
    }
  }

  spec {
    replicas = var.consumer_replicas

    selector {
      match_labels = {
        app = "kafka-consumer"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka-consumer"
        }
        annotations = var.enable_monitoring ? {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8000"
        } : {}
      }

      spec {
        security_context {
          run_as_user = 1000
          fs_group    = 1000
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "consumer"
          image             = var.consumer_image
          image_pull_policy = "Always"

          security_context {
            allow_privilege_escalation = false
            privileged = false
            read_only_root_filesystem = true
            run_as_non_root = true
            capabilities {
              drop = ["ALL"]
            }
          }

          env {
            name  = "KAFKA_BROKER_URL"
            value = "${var.kafka_service_name}:9092"
          }
          env {
            name  = "KAFKA_TOPIC"
            value = var.kafka_topic
          }
          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }

          # Security configuration
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_MECHANISM"
              value = "SCRAM-SHA-512"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SECURITY_PROTOCOL"
              value = "SASL_PLAINTEXT"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_USERNAME"
              value = "consumer"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_PASSWORD"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.kafka_credentials[0].metadata[0].name
                  key  = "consumer-password"
                }
              }
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_OPTS"
              value = "-Djava.security.auth.login.config=/etc/kafka/consumer-jaas.conf"
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "200m"
            }
          }

          dynamic "volume_mount" {
            for_each = var.enable_security ? [1] : []
            content {
              name       = "consumer-jaas"
              mount_path = "/etc/kafka/consumer-jaas.conf"
              sub_path   = "consumer-jaas.conf"
            }
          }

          liveness_probe {
            exec {
              command = ["python", "healthcheck.py"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["python", "healthcheck.py"]
            }
            initial_delay_seconds = 15
            period_seconds        = 5
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        dynamic "volume" {
          for_each = var.enable_security ? [1] : []
          content {
            name = "consumer-jaas"
            config_map {
              name = kubernetes_config_map.consumer_jaas_config[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

# Producer Deployment
resource "kubernetes_deployment" "kafka_producer" {
  metadata {
    name      = "kafka-producer"
    namespace = var.namespace
    labels = {
      app = "kafka-producer"
    }
  }

  spec {
    replicas = var.producer_replicas

    selector {
      match_labels = {
        app = "kafka-producer"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka-producer"
        }
        annotations = var.enable_monitoring ? {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8000"
        } : {}
      }

      spec {
        security_context {
          run_as_user = 1000
          fs_group    = 1000
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "producer"
          image             = var.producer_image
          image_pull_policy = "Always"

          security_context {
            allow_privilege_escalation = false
            privileged = false
            read_only_root_filesystem = true
            run_as_non_root = true
            capabilities {
              drop = ["ALL"]
            }
          }

          env {
            name  = "KAFKA_BROKER_URL"
            value = "${var.kafka_service_name}:9092"
          }
          env {
            name  = "KAFKA_TOPIC"
            value = var.kafka_topic
          }
          env {
            name  = "MESSAGE_COUNT"
            value = "5"
          }
          env {
            name  = "MESSAGE_INTERVAL"
            value = "1.0"
          }
          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }

          # Security configuration
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_MECHANISM"
              value = "SCRAM-SHA-512"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SECURITY_PROTOCOL"
              value = "SASL_PLAINTEXT"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_USERNAME"
              value = "producer"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_PASSWORD"
              value_from {
                secret_key_ref {
                  name = kubernetes_secret.kafka_credentials[0].metadata[0].name
                  key  = "producer-password"
                }
              }
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_OPTS"
              value = "-Djava.security.auth.login.config=/etc/kafka/producer-jaas.conf"
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "200m"
            }
          }

          dynamic "volume_mount" {
            for_each = var.enable_security ? [1] : []
            content {
              name       = "producer-jaas"
              mount_path = "/etc/kafka/producer-jaas.conf"
              sub_path   = "producer-jaas.conf"
            }
          }

          liveness_probe {
            exec {
              command = ["python", "healthcheck.py"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["python", "healthcheck.py"]
            }
            initial_delay_seconds = 15
            period_seconds        = 5
            timeout_seconds       = 5
            failure_threshold     = 3
          }
        }

        dynamic "volume" {
          for_each = var.enable_security ? [1] : []
          content {
            name = "producer-jaas"
            config_map {
              name = kubernetes_config_map.producer_jaas_config[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

# Outputs
output "consumer_deployment_name" {
  value = kubernetes_deployment.kafka_consumer.metadata[0].name
}

output "producer_deployment_name" {
  value = kubernetes_deployment.kafka_producer.metadata[0].name
}
