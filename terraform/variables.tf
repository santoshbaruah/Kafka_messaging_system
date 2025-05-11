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
