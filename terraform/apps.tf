# Consumer Deployment
resource "kubernetes_deployment" "kafka_consumer" {
  metadata {
    name      = "kafka-consumer"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "kafka-consumer"
    }
  }

  spec {
    replicas = 2

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
      }

      spec {
        # Security context for non-root execution
        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name              = "consumer"
          image             = "python:3.8-slim@sha256:1d52838af602b4b5a831beb13a0e4d073280665ea7be7f69ce2382f29c5a613f"
          image_pull_policy = "Always"

          # Container security context
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
            value = "kafka-service:9092"
          }
          env {
            name  = "KAFKA_TOPIC"
            value = "posts"
          }
          env {
            name  = "KAFKA_CONSUMER_GROUP_ID"
            value = "consumer-group-1"
          }
          env {
            name  = "KAFKA_AUTO_OFFSET_RESET"
            value = "earliest"
          }
          # Security configuration
          env {
            name  = "KAFKA_SECURITY_PROTOCOL"
            value = "SASL_PLAINTEXT"
          }
          env {
            name  = "KAFKA_SASL_MECHANISM"
            value = "SCRAM-SHA-512"
          }
          env {
            name = "KAFKA_SASL_USERNAME"
            value_from {
              secret_key_ref {
                name = "kafka-credentials"
                key  = "username"
              }
            }
          }
          env {
            name = "KAFKA_SASL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "kafka-credentials"
                key  = "password"
              }
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

          liveness_probe {
            exec {
              command = [
                "python",
                "-c",
                "import socket; socket.socket().connect(('kafka-service', 9092))"
              ]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = [
                "python",
                "-c",
                "import socket; socket.socket().connect(('kafka-service', 9092))"
              ]
            }
            initial_delay_seconds = 15
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_job.kafka_topic_creator]
}

# Producer Deployment
resource "kubernetes_deployment" "kafka_producer" {
  metadata {
    name      = "kafka-producer"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "kafka-producer"
    }
  }

  spec {
    replicas = 1

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
      }

      spec {
        # Security context for non-root execution
        security_context {
          run_as_user     = 1000
          fs_group        = 1000
          run_as_non_root = true
        }

        container {
          name              = "producer"
          image             = "python:3.8-slim@sha256:1d52838af602b4b5a831beb13a0e4d073280665ea7be7f69ce2382f29c5a613f"
          image_pull_policy = "Always"

          # Container security context
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
            value = "kafka-service:9092"
          }
          env {
            name  = "KAFKA_TOPIC"
            value = "posts"
          }
          env {
            name  = "KAFKA_ACKS"
            value = "all"
          }
          env {
            name  = "KAFKA_RETRIES"
            value = "3"
          }
          env {
            name  = "KAFKA_LINGER_MS"
            value = "5"
          }
          # Security configuration
          env {
            name  = "KAFKA_SECURITY_PROTOCOL"
            value = "SASL_PLAINTEXT"
          }
          env {
            name  = "KAFKA_SASL_MECHANISM"
            value = "SCRAM-SHA-512"
          }
          env {
            name = "KAFKA_SASL_USERNAME"
            value_from {
              secret_key_ref {
                name = "kafka-credentials"
                key  = "username"
              }
            }
          }
          env {
            name = "KAFKA_SASL_PASSWORD"
            value_from {
              secret_key_ref {
                name = "kafka-credentials"
                key  = "password"
              }
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

          liveness_probe {
            exec {
              command = [
                "python",
                "-c",
                "import socket; socket.socket().connect(('kafka-service', 9092))"
              ]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = [
                "python",
                "-c",
                "import socket; socket.socket().connect(('kafka-service', 9092))"
              ]
            }
            initial_delay_seconds = 15
            period_seconds        = 5
          }
        }
      }
    }
  }

  depends_on = [kubernetes_job.kafka_topic_creator]
}
