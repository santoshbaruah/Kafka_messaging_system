variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
  default     = "kafka"
}

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

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard"
}

variable "kafka_storage_size" {
  description = "Size of Kafka data volume"
  type        = string
  default     = "10Gi"
}

variable "zookeeper_storage_size" {
  description = "Size of Zookeeper data volume"
  type        = string
  default     = "2Gi"
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

variable "kafka_admin_password" {
  description = "Password for Kafka admin user"
  type        = string
  default     = "admin-secret"
  sensitive   = true
}

# Create namespace
resource "kubernetes_namespace" "kafka_namespace" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/name" = "kafka"
      "app.kubernetes.io/part-of" = "event-driven-architecture"
    }
  }
}

# ConfigMap for Kafka server properties
resource "kubernetes_config_map" "kafka_server_config" {
  metadata {
    name      = "kafka-server-config"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "server.properties" = <<-EOT
      # Broker ID is set via environment variable

      # Listeners are set via environment variables

      # Zookeeper connection is set via environment variable

      # Log configuration
      log.dirs=/var/lib/kafka/data
      num.recovery.threads.per.data.dir=1

      # Topic defaults
      num.partitions=6
      default.replication.factor=${var.kafka_replicas > 2 ? 3 : 2}
      min.insync.replicas=${var.kafka_replicas > 2 ? 2 : 1}

      # Log retention policy
      log.retention.hours=168
      log.segment.bytes=1073741824
      log.retention.check.interval.ms=300000

      # Replication configuration
      replica.lag.time.max.ms=30000
      replica.socket.timeout.ms=30000
      replica.socket.receive.buffer.bytes=65536
      replica.fetch.max.bytes=1048576
      replica.fetch.wait.max.ms=500

      # Producer configuration
      compression.type=producer

      # Consumer configuration
      group.initial.rebalance.delay.ms=3000

      # Transaction configuration
      transaction.state.log.replication.factor=${min(var.kafka_replicas, 3)}
      transaction.state.log.min.isr=${min(var.kafka_replicas - 1, 2)}

      # Performance tuning
      num.network.threads=3
      num.io.threads=8
      socket.send.buffer.bytes=102400
      socket.receive.buffer.bytes=102400
      socket.request.max.bytes=104857600

      # Background threads
      background.threads=10

      # Unclean leader election
      unclean.leader.election.enable=false

      # Auto leader rebalance
      auto.leader.rebalance.enable=true
      leader.imbalance.check.interval.seconds=300
      leader.imbalance.per.broker.percentage=10

      # Log cleaner (for compacted topics)
      log.cleaner.enable=true
      log.cleaner.threads=1
      log.cleaner.dedupe.buffer.size=134217728

      # Controlled shutdown
      controlled.shutdown.enable=true
      controlled.shutdown.max.retries=3
      controlled.shutdown.retry.backoff.ms=5000

      # Delete topic
      delete.topic.enable=true

      # Auto create topics
      auto.create.topics.enable=false

      # Security configuration is set via environment variables
    EOT
  }
}

# ConfigMap for JMX exporter
resource "kubernetes_config_map" "kafka_jmx_exporter_config" {
  count = var.enable_monitoring ? 1 : 0

  metadata {
    name      = "kafka-jmx-exporter-config"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "config.yml" = <<-EOT
      lowercaseOutputName: true
      rules:
      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          topic: "$4"
          partition: "$5"
      - pattern: kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
        labels:
          clientId: "$3"
          broker: "$4:$5"
      - pattern: kafka.server<type=(.+), name=(.+)><>Value
        name: kafka_server_$1_$2
        type: GAUGE
    EOT
  }
}

# Zookeeper StatefulSet
resource "kubernetes_stateful_set" "zookeeper" {
  metadata {
    name      = "zookeeper"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "zookeeper"
    }
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
        security_context {
          run_as_user = 1000
          fs_group    = 1000
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "zookeeper"
          image = "confluentinc/cp-zookeeper@sha256:5971e800825ce61670124ff8c23f99ce42d95f6592bad4e9a9a77063f7a58af2"
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

          liveness_probe {
            exec {
              command = ["sh", "-c", "echo ruok | nc localhost 2181 | grep imok"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["sh", "-c", "echo ruok | nc localhost 2181 | grep imok"]
            }
            initial_delay_seconds = 10
            period_seconds        = 5
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
        storage_class_name = var.storage_class
        resources {
          requests = {
            storage = var.zookeeper_storage_size
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
        storage_class_name = var.storage_class
        resources {
          requests = {
            storage = var.zookeeper_storage_size
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

# Kafka JAAS ConfigMap (for security)
resource "kubernetes_config_map" "kafka_jaas_config" {
  count = var.enable_security ? 1 : 0

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

# Kafka StatefulSet
resource "kubernetes_stateful_set" "kafka" {
  metadata {
    name      = "kafka"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "kafka"
    }
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
        annotations = var.enable_monitoring ? {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "5556"
        } : {}
      }

      spec {
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

        security_context {
          run_as_user = 1000
          fs_group    = 1000
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        termination_grace_period_seconds = 300

        container {
          name  = "kafka"
          image = "confluentinc/cp-kafka@sha256:724faab73e5a5d18a83f1f015a52dde0dfac32851dec62c5f0006d6125d45b99"
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

          # Security configuration
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
              value = "INTERNAL:SASL_PLAINTEXT,EXTERNAL:SASL_PLAINTEXT"
            }
          }
          dynamic "env" {
            for_each = !var.enable_security ? [1] : []
            content {
              name  = "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"
              value = "INTERNAL:PLAINTEXT,EXTERNAL:PLAINTEXT"
            }
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
            value = "${min(var.kafka_replicas, 3)}"
          }
          env {
            name  = "KAFKA_DEFAULT_REPLICATION_FACTOR"
            value = "${min(var.kafka_replicas, 3)}"
          }
          env {
            name  = "KAFKA_MIN_INSYNC_REPLICAS"
            value = "${min(var.kafka_replicas - 1, 2)}"
          }
          env {
            name  = "KAFKA_AUTO_CREATE_TOPICS_ENABLE"
            value = "false"
          }

          # Additional security configuration
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_ENABLED_MECHANISMS"
              value = "SCRAM-SHA-512"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SASL_MECHANISM_INTER_BROKER_PROTOCOL"
              value = "SCRAM-SHA-512"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SECURITY_INTER_BROKER_PROTOCOL"
              value = "SASL_PLAINTEXT"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_AUTHORIZER_CLASS_NAME"
              value = "kafka.security.authorizer.AclAuthorizer"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_SUPER_USERS"
              value = "User:admin"
            }
          }
          dynamic "env" {
            for_each = var.enable_security ? [1] : []
            content {
              name  = "KAFKA_OPTS"
              value = "-Djava.security.auth.login.config=/etc/kafka/kafka-jaas.conf"
            }
          }

          env {
            name = "POD_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          # JMX configuration for monitoring
          dynamic "env" {
            for_each = var.enable_monitoring ? [1] : []
            content {
              name  = "KAFKA_JMX_PORT"
              value = "5555"
            }
          }
          dynamic "env" {
            for_each = var.enable_monitoring ? [1] : []
            content {
              name = "KAFKA_JMX_HOSTNAME"
              value_from {
                field_ref {
                  field_path = "status.podIP"
                }
              }
            }
          }

          resources {
            requests = {
              memory = "2Gi"
              cpu    = "1000m"
            }
            limits = {
              memory = "4Gi"
              cpu    = "2000m"
            }
          }

          volume_mount {
            name       = "kafka-data"
            mount_path = "/var/lib/kafka/data"
          }

          dynamic "volume_mount" {
            for_each = var.enable_security ? [1] : []
            content {
              name       = "kafka-jaas"
              mount_path = "/etc/kafka/kafka-jaas.conf"
              sub_path   = "kafka-jaas.conf"
            }
          }

          volume_mount {
            name       = "kafka-config"
            mount_path = "/etc/kafka/server.properties"
            sub_path   = "server.properties"
          }

          readiness_probe {
            exec {
              command = ["/bin/sh", "-c", "kafka-topics --list --bootstrap-server localhost:9092"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          liveness_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 60
            period_seconds        = 20
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }

          startup_probe {
            tcp_socket {
              port = 9092
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 30
          }
        }

        # JMX exporter container for monitoring
        dynamic "container" {
          for_each = var.enable_monitoring ? [1] : []
          content {
            name  = "jmx-exporter"
            image = "bitnami/jmx-exporter@sha256:a6b5e6d48a1bb3a446658004ab0413dcc7b41b5b6e08432aaea4c0b945e31c1e"
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

            port {
              container_port = 5556
              name           = "metrics"
            }

            args = [
              "5556",
              "/etc/jmx-exporter/config.yml"
            ]

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

            volume_mount {
              name       = "jmx-config"
              mount_path = "/etc/jmx-exporter"
            }

            liveness_probe {
              http_get {
                path = "/metrics"
                port = 5556
              }
              initial_delay_seconds = 30
              period_seconds        = 10
            }
          }
        }

        volume {
          name = "kafka-config"
          config_map {
            name = kubernetes_config_map.kafka_server_config.metadata[0].name
          }
        }

        dynamic "volume" {
          for_each = var.enable_security ? [1] : []
          content {
            name = "kafka-jaas"
            config_map {
              name = kubernetes_config_map.kafka_jaas_config[0].metadata[0].name
            }
          }
        }

        dynamic "volume" {
          for_each = var.enable_monitoring ? [1] : []
          content {
            name = "jmx-config"
            config_map {
              name = kubernetes_config_map.kafka_jmx_exporter_config[0].metadata[0].name
            }
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "kafka-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class
        resources {
          requests = {
            storage = var.kafka_storage_size
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
        container {
          name    = "kafka-topic-creator"
          image   = "confluentinc/cp-kafka@sha256:724faab73e5a5d18a83f1f015a52dde0dfac32851dec62c5f0006d6125d45b99"
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
          command = ["/bin/bash", "-c"]
          args = [
            <<-EOT
            # Wait for Kafka to be ready
            echo "Waiting for Kafka to be ready..."
            sleep 30

            # Create the posts topic with advanced configuration
            kafka-topics --create --if-not-exists \
              --bootstrap-server kafka-0.kafka-service:9092 \
              --topic posts \
              --partitions 6 \
              --replication-factor ${min(var.kafka_replicas, 3)} \
              --config min.insync.replicas=${min(var.kafka_replicas - 1, 2)} \
              --config retention.ms=604800000 \
              --config segment.bytes=1073741824 \
              --config cleanup.policy=delete \
              --config max.message.bytes=1000000 \
              --config flush.messages=1 \
              --config flush.ms=1000

            echo "Topic 'posts' created successfully"

            # Create additional topics for different use cases

            # High-throughput topic with more partitions
            kafka-topics --create --if-not-exists \
              --bootstrap-server kafka-0.kafka-service:9092 \
              --topic high-throughput-events \
              --partitions 12 \
              --replication-factor ${min(var.kafka_replicas, 3)} \
              --config min.insync.replicas=${min(var.kafka_replicas - 1, 2)} \
              --config retention.ms=259200000 \
              --config segment.bytes=1073741824

            echo "Topic 'high-throughput-events' created successfully"

            # Compacted topic for state storage
            kafka-topics --create --if-not-exists \
              --bootstrap-server kafka-0.kafka-service:9092 \
              --topic user-profiles \
              --partitions 6 \
              --replication-factor ${min(var.kafka_replicas, 3)} \
              --config min.insync.replicas=${min(var.kafka_replicas - 1, 2)} \
              --config cleanup.policy=compact \
              --config segment.bytes=1073741824 \
              --config min.cleanable.dirty.ratio=0.5

            echo "Topic 'user-profiles' created successfully"

            # Low-latency topic
            kafka-topics --create --if-not-exists \
              --bootstrap-server kafka-0.kafka-service:9092 \
              --topic notifications \
              --partitions 6 \
              --replication-factor ${min(var.kafka_replicas, 3)} \
              --config min.insync.replicas=${min(var.kafka_replicas - 1, 2)} \
              --config retention.ms=86400000 \
              --config segment.bytes=536870912 \
              --config flush.messages=1

            echo "Topic 'notifications' created successfully"

            # List all topics
            echo "Listing all topics:"
            kafka-topics --list --bootstrap-server kafka-0.kafka-service:9092

            # Describe the posts topic
            echo "Details of 'posts' topic:"
            kafka-topics --describe --bootstrap-server kafka-0.kafka-service:9092 --topic posts
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
