resource "kubernetes_config_map" "kafka_jmx_exporter" {
  metadata {
    name      = "kafka-jmx-exporter"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  data = {
    "kafka-jmx-exporter.yml" = <<-EOT
      lowercaseOutputName: true
      lowercaseOutputLabelNames: true
      rules:
      - pattern: "kafka.server<type=(.+), name=(.+), clientId=(.+), topic=(.+), partition=(.*)><>Value"
        name: "kafka_server_$1_$2"
        type: "GAUGE"
        labels:
          clientId: "$3"
          topic: "$4"
          partition: "$5"
      - pattern: "kafka.server<type=(.+), name=(.+), clientId=(.+), brokerHost=(.+), brokerPort=(.+)><>Value"
        name: "kafka_server_$1_$2"
        type: "GAUGE"
        labels:
          clientId: "$3"
          broker: "$4:$5"
      - pattern: "kafka.server<type=(.+), name=(.+)><>Value"
        name: "kafka_server_$1_$2"
        type: "GAUGE"
      - pattern: "kafka.controller<type=(.+), name=(.+)><>Value"
        name: "kafka_controller_$1_$2"
        type: "GAUGE"
      - pattern: "kafka.network<type=(.+), name=(.+)><>Value"
        name: "kafka_network_$1_$2"
        type: "GAUGE"
      - pattern: "kafka.log<type=(.+), name=(.+)><>Value"
        name: "kafka_log_$1_$2"
        type: "GAUGE"
      - pattern: "kafka.cluster<type=(.+), name=(.+)><>Value"
        name: "kafka_cluster_$1_$2"
        type: "GAUGE"
    EOT
  }
}

# Update Kafka StatefulSet to include JMX exporter
resource "kubernetes_stateful_set" "kafka_jmx" {
  metadata {
    name      = "kafka-jmx"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  spec {
    service_name = "kafka-jmx-service"
    replicas     = var.kafka_replicas

    selector {
      match_labels = {
        app = "kafka-jmx"
      }
    }

    template {
      metadata {
        labels = {
          app = "kafka-jmx"
        }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "5556"
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
                    values   = ["kafka-jmx"]
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
          port {
            container_port = 5555
            name           = "jmx"
          }
          port {
            container_port = 5556
            name           = "metrics"
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
            value = "-Djava.security.auth.login.config=/etc/kafka/kafka-jaas.conf -javaagent:/opt/jmx-exporter/jmx_prometheus_javaagent-0.16.1.jar=5556:/opt/jmx-exporter/kafka-jmx-exporter.yml"
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
          env {
            name  = "KAFKA_JMX_PORT"
            value = "5555"
          }
          env {
            name = "KAFKA_JMX_HOSTNAME"
            value_from {
              field_ref {
                field_path = "status.podIP"
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
          volume_mount {
            name       = "jmx-exporter-config"
            mount_path = "/opt/jmx-exporter/kafka-jmx-exporter.yml"
            sub_path   = "kafka-jmx-exporter.yml"
          }
          volume_mount {
            name       = "jmx-exporter-agent"
            mount_path = "/opt/jmx-exporter/jmx_prometheus_javaagent-0.16.1.jar"
            sub_path   = "jmx_prometheus_javaagent-0.16.1.jar"
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

        # Init container to download JMX exporter
        init_container {
          name  = "download-jmx-exporter"
          image = "busybox:1.35.0"
          command = [
            "sh",
            "-c",
            "wget -O /jmx-exporter/jmx_prometheus_javaagent-0.16.1.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.16.1/jmx_prometheus_javaagent-0.16.1.jar"
          ]
          volume_mount {
            name       = "jmx-exporter-agent"
            mount_path = "/jmx-exporter"
          }
        }

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

        volume {
          name = "jmx-exporter-config"
          config_map {
            name = kubernetes_config_map.kafka_jmx_exporter.metadata[0].name
            items {
              key  = "kafka-jmx-exporter.yml"
              path = "kafka-jmx-exporter.yml"
            }
          }
        }

        volume {
          name = "jmx-exporter-agent"
          empty_dir {}
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

# JMX Service
resource "kubernetes_service" "kafka_jmx_service" {
  metadata {
    name      = "kafka-jmx-service"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
    labels = {
      app = "kafka-jmx"
    }
  }

  spec {
    selector = {
      app = "kafka-jmx"
    }

    port {
      port = 9092
      name = "internal"
    }
    port {
      port = 9093
      name = "external"
    }
    port {
      port = 5555
      name = "jmx"
    }
    port {
      port = 5556
      name = "metrics"
    }
  }
}
