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
