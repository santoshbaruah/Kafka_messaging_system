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
