resource "kubernetes_network_policy" "kafka_network_policy" {
  metadata {
    name      = "kafka-network-policy"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "kafka"
      }
    }

    ingress {
      from {
        pod_selector {
          match_expressions {
            key      = "app"
            operator = "In"
            values   = ["kafka-consumer", "kafka-producer"]
          }
        }
      }

      ports {
        port     = 9092
        protocol = "TCP"
      }
    }

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "kafka"
          }
        }
      }

      ports {
        port     = 9092
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}

resource "kubernetes_network_policy" "zookeeper_network_policy" {
  metadata {
    name      = "zookeeper-network-policy"
    namespace = kubernetes_namespace.kafka_namespace.metadata[0].name
  }

  spec {
    pod_selector {
      match_labels = {
        app = "zookeeper"
      }
    }

    ingress {
      from {
        pod_selector {
          match_labels = {
            app = "kafka"
          }
        }
      }

      ports {
        port     = 2181
        protocol = "TCP"
      }
    }

    policy_types = ["Ingress"]
  }
}
