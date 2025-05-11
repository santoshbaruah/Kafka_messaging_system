provider "kubernetes" {
  config_path = "~/.kube/config"
}

# Variables
variable "kafka_version" {
  description = "Kafka version to deploy"
  type        = string
  default     = "7.3.2"
}

variable "kafka_replicas" {
  description = "Number of Kafka brokers"
  type        = number
  default     = 3
}

variable "zookeeper_replicas" {
  description = "Number of Zookeeper nodes"
  type        = number
  default     = 1
}

variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "default"
}

# Namespace
resource "kubernetes_namespace" "kafka_namespace" {
  metadata {
    name = var.namespace
  }
}

# Zookeeper StatefulSet
resource "kubernetes_stateful_set" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  spec {
    service_name = "zookeeper-service"
    replicas     = var.zookeeper_replicas

    selector {
      match_labels = {
        app = "zookeeper"
      }
    }

    template {
      metadata {
        labels = {
          app = "zookeeper"
        }
      }

      spec {
        container {
          name  = "zookeeper"
          image = "confluentinc/cp-zookeeper:${var.kafka_version}"

          port {
            container_port = 2181
            name           = "client"
          }
          port {
            container_port = 2888
            name           = "server"
          }
          port {
            container_port = 3888
            name           = "leader-election"
          }

          env {
            name  = "ZOOKEEPER_CLIENT_PORT"
            value = "2181"
          }
          env {
            name  = "ZOOKEEPER_TICK_TIME"
            value = "2000"
          }
          env {
            name  = "ZOOKEEPER_INIT_LIMIT"
            value = "5"
          }
          env {
            name  = "ZOOKEEPER_SYNC_LIMIT"
            value = "2"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          volume_mount {
            name       = "zookeeper-data"
            mount_path = "/var/lib/zookeeper/data"
          }
          volume_mount {
            name       = "zookeeper-log"
            mount_path = "/var/lib/zookeeper/log"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "zookeeper-data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "zookeeper-log"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "1Gi"
          }
        }
      }
    }
  }
}

# Zookeeper Service
resource "kubernetes_service" "zookeeper_service" {
  metadata {
    name      = "zookeeper-service"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "zookeeper"
    }
  }

  spec {
    selector = {
      app = "zookeeper"
    }

    port {
      port = 2181
      name = "client"
    }
    port {
      port = 2888
      name = "server"
    }
    port {
      port = 3888
      name = "leader-election"
    }
  }
}

# Kafka StatefulSet
resource "kubernetes_stateful_set" "kafka" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  spec {
    service_name = "kafka-service"
    replicas     = var.kafka_replicas

    selector {
      match_labels = {
        app = "kafka"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka"
        }
      }

      spec {
        # Pod anti-affinity to distribute brokers across nodes
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["kafka"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        # Security context for non-root execution
        security_context {
          run_as_user = 1000
          fs_group    = 1000
        }

        # Allow time for clean shutdown
        termination_grace_period_seconds = 300

        container {
          name  = "kafka"
          image = "confluentinc/cp-kafka:${var.kafka_version}"

          port {
            container_port = 9092
            name           = "internal"
          }
          port {
            container_port = 9093
            name           = "external"
          }

          env {
            name = "KAFKA_BROKER_ID"
            value_from {
              field_ref {
                field_path = "metadata.name"
              }
            }
          }
          env {
            name  = "KAFKA_ZOOKEEPER_CONNECT"
            value = "zookeeper-service:2181"
          }
          env {
            name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
            value = "INTERNAL:SASL_PLAINTEXT,EXTERNAL:SASL_PLAINTEXT"
          }
          env {
            name  = "KAFKA_SASL_ENABLED_MECHANISMS"
            value = "SCRAM-SHA-512"
          }
          env {
            name  = "KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL"
            value = "SCRAM-SHA-512"
          }
          env {
            name  = "KAFKA_SECURITY_INTER_BROKER_PROTOCOL"
            value = "SASL_PLAINTEXT"
          }
          env {
            name  = "KAFKA_AUTHORIZER_CLASS_NAME"
            value = "kafka.security.authorizer.AclAuthorizer"
          }
          env {
            name  = "KAFKA_SUPER_USERS"
            value = "User:admin"
          }
          env {
            name  = "KAFKA_OPTS"
            value = "-Djava.security.auth.login.config=/etc/kafka/kafka-jaas.conf"
          }
          env {
            name  = "KAFKA_ADVERTISED_LISTENERS"
            value = "INTERNAL://$(KAFKA_BROKER_ID).kafka-service.$(POD_NAMESPACE).svc.cluster.local:9092,EXTERNAL://localhost:9093"
          }
          env {
            name  = "KAFKA_INTER_BROKER_LISTENER_NAME"
            value = "INTERNAL"
          }
          env {
            name  = "KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR"
            value = "3"
          }
          env {
            name  = "KAFKA_DEFAULT_REPLICATION_FACTOR"
            value = "3"
          }
          env {
            name  = "KAFKA_MIN_INSYNC_REPLICAS"
            value = "2"
          }
          env {
            name  = "KAFKA_AUTO_CREATE_TOPICS_ENABLE"
            value = "false"
          }
          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          resources {
            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          volume_mount {
            name       = "kafka-data"
            mount_path = "/var/lib/kafka/data"
          }
          volume_mount {
            name       = "kafka-jaas"
            mount_path = "/etc/kafka/kafka-jaas.conf"
            sub_path   = "kafka-jaas.conf"
          }

          readiness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          liveness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 60
            period_seconds        = 20
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "kafka-data"
      }
      spec {
        access_modes = ["ReadWriteOnce"]
        resources {
          requests = {
            storage = "5Gi"
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.zookeeper]
}

# Kafka Service
resource "kubernetes_service" "kafka_service" {
  metadata {
    name      = "kafka-service"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "kafka"
    }
  }

  spec {
    selector = {
      app = "kafka"
    }

    port {
      port = 9092
      name = "internal"
    }
    port {
      port = 9093
      name = "external"
    }
  }
}

# Kafka Topic Creation Job
resource "kubernetes_job" "kafka_topic_creator" {
  metadata {
    name      = "kafka-topic-creator"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  spec {
    template {
      metadata {}
      spec {
        volume {
          name = "kafka-jaas"
          config_map {
            name = kubernetes_config_map.kafka_jaas.metadata[0].name
            items {
              key  = "kafka-jaas.conf"
              path = "kafka-jaas.conf"
            }
          }
        }

        container {
          name    = "kafka-topic-creator"
          image   = "confluentinc/cp-kafka:${var.kafka_version}"
          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
            # Wait for Kafka to be ready
            echo "Waiting for Kafka to be ready..."
            sleep 30

            # Create the posts topic with 8 partitions and replication factor of 3
            kafka-topics --create --if-not-exists \
              --bootstrap-server kafka-0.kafka-service:9092 \
              --topic posts \
              --partitions 8 \
              --replication-factor 3 \
              --config min.insync.replicas=2 \
              --config retention.ms=604800000 \
              --config segment.bytes=1073741824 \
              --config cleanup.policy=delete \
              --config max.message.bytes=1000000 \
              --config flush.messages=1 \
              --config flush.ms=1000

            echo "Topic 'posts' created successfully"
            EOT
          ]
        }
        restart_policy = "Never"
      }
    }
    backoff_limit = 3
  }

  depends_on = [kubernetes_stateful_set.kafka]
}

# Outputs
output "kafka_service_name" {
  value = kubernetes_service.kafka_service.metadata[0].name
}

output "zookeeper_service_name" {
  value = kubernetes_service.zookeeper_service.metadata[0].name
}

output "namespace" {
  value = kubernetes_namespace.kafka_namespace.metadata[0].name
}
