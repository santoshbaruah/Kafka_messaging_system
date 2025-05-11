variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "kafka_service_name" {
  description = "Name of the Kafka service"
  type        = string
  default     = "kafka-service"
}

variable "grafana_admin_password" {
  description = "Grafana admin password"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "retention_days" {
  description = "Prometheus data retention in days"
  type        = number
  default     = 15
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard"
}

variable "prometheus_storage_size" {
  description = "Size of Prometheus data volume"
  type        = string
  default     = "10Gi"
}

variable "grafana_storage_size" {
  description = "Size of Grafana data volume"
  type        = string
  default     = "2Gi"
}

# Prometheus ConfigMap
resource "kubernetes_config_map" "prometheus_config" {
  metadata {
    name      = "prometheus-config"
    namespace = var.namespace
  }

  data = {
    "prometheus.yml" = <<-EOT
      global:
        scrape_interval: 15s
        evaluation_interval: 15s
        external_labels:
          monitor: 'kafka-monitor'

      scrape_configs:
        - job_name: 'kafka'
          static_configs:
            - targets: ['kafka-jmx-exporter:5556']

        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
              action: replace
              target_label: __metrics_path__
              regex: (.+)
            - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
              action: replace
              regex: ([^:]+)(?::\d+)?;(\d+)
              replacement: $1:$2
              target_label: __address__
            - action: labelmap
              regex: __meta_kubernetes_pod_label_(.+)
            - source_labels: [__meta_kubernetes_namespace]
              action: replace
              target_label: kubernetes_namespace
            - source_labels: [__meta_kubernetes_pod_name]
              action: replace
              target_label: kubernetes_pod_name
    EOT

    "alert.rules" = <<-EOT
      groups:
      - name: kafka_alerts
        rules:
        - alert: KafkaBrokerDown
          expr: up{job="kafka"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Kafka broker down"
            description: "Kafka broker has been down for more than 1 minute."

        - alert: KafkaTopicUnderReplicated
          expr: kafka_server_replicamanager_underreplicatedpartitions > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Kafka topic under-replicated"
            description: "Kafka topic has under-replicated partitions for more than 5 minutes."

        - alert: KafkaConsumerLag
          expr: kafka_consumer_consumer_fetch_manager_metrics_records_lag_max > 1000
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Kafka consumer lag"
            description: "Kafka consumer is lagging behind by more than 1000 records for more than 5 minutes."

        - alert: KafkaDiskUsage
          expr: node_filesystem_avail_bytes{mountpoint="/var/lib/kafka/data"} / node_filesystem_size_bytes{mountpoint="/var/lib/kafka/data"} * 100 < 20
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Kafka disk space low"
            description: "Kafka broker disk space is below 20% for more than 5 minutes."
    EOT
  }
}

# Grafana ConfigMap for Dashboards
resource "kubernetes_config_map" "grafana_dashboards" {
  metadata {
    name      = "grafana-dashboards"
    namespace = var.namespace
  }

  data = {
    "kafka-overview.json" = <<-EOT
      {
        "annotations": {
          "list": []
        },
        "editable": true,
        "gnetId": null,
        "graphTooltip": 0,
        "id": 1,
        "links": [],
        "panels": [
          {
            "aliasColors": {},
            "bars": false,
            "dashLength": 10,
            "dashes": false,
            "datasource": "Prometheus",
            "fieldConfig": {
              "defaults": {
                "custom": {}
              },
              "overrides": []
            },
            "fill": 1,
            "fillGradient": 0,
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 0
            },
            "hiddenSeries": false,
            "id": 2,
            "legend": {
              "avg": false,
              "current": false,
              "max": false,
              "min": false,
              "show": true,
              "total": false,
              "values": false
            },
            "lines": true,
            "linewidth": 1,
            "nullPointMode": "null",
            "options": {
              "alertThreshold": true
            },
            "percentage": false,
            "pluginVersion": "7.2.0",
            "pointradius": 2,
            "points": false,
            "renderer": "flot",
            "seriesOverrides": [],
            "spaceLength": 10,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "expr": "kafka_server_brokertopicmetrics_messagesinpersec_oneminuterate",
                "interval": "",
                "legendFormat": "{{topic}}",
                "refId": "A"
              }
            ],
            "thresholds": [],
            "timeFrom": null,
            "timeRegions": [],
            "timeShift": null,
            "title": "Messages In Per Second",
            "tooltip": {
              "shared": true,
              "sort": 0,
              "value_type": "individual"
            },
            "type": "graph",
            "xaxis": {
              "buckets": null,
              "mode": "time",
              "name": null,
              "show": true,
              "values": []
            },
            "yaxes": [
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ],
            "yaxis": {
              "align": false,
              "alignLevel": null
            }
          },
          {
            "aliasColors": {},
            "bars": false,
            "dashLength": 10,
            "dashes": false,
            "datasource": "Prometheus",
            "fieldConfig": {
              "defaults": {
                "custom": {}
              },
              "overrides": []
            },
            "fill": 1,
            "fillGradient": 0,
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 0
            },
            "hiddenSeries": false,
            "id": 3,
            "legend": {
              "avg": false,
              "current": false,
              "max": false,
              "min": false,
              "show": true,
              "total": false,
              "values": false
            },
            "lines": true,
            "linewidth": 1,
            "nullPointMode": "null",
            "options": {
              "alertThreshold": true
            },
            "percentage": false,
            "pluginVersion": "7.2.0",
            "pointradius": 2,
            "points": false,
            "renderer": "flot",
            "seriesOverrides": [],
            "spaceLength": 10,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "expr": "kafka_server_brokertopicmetrics_bytesinpersec_oneminuterate",
                "interval": "",
                "legendFormat": "{{topic}}",
                "refId": "A"
              }
            ],
            "thresholds": [],
            "timeFrom": null,
            "timeRegions": [],
            "timeShift": null,
            "title": "Bytes In Per Second",
            "tooltip": {
              "shared": true,
              "sort": 0,
              "value_type": "individual"
            },
            "type": "graph",
            "xaxis": {
              "buckets": null,
              "mode": "time",
              "name": null,
              "show": true,
              "values": []
            },
            "yaxes": [
              {
                "format": "bytes",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ],
            "yaxis": {
              "align": false,
              "alignLevel": null
            }
          },
          {
            "aliasColors": {},
            "bars": false,
            "dashLength": 10,
            "dashes": false,
            "datasource": "Prometheus",
            "fieldConfig": {
              "defaults": {
                "custom": {}
              },
              "overrides": []
            },
            "fill": 1,
            "fillGradient": 0,
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 0,
              "y": 8
            },
            "hiddenSeries": false,
            "id": 4,
            "legend": {
              "avg": false,
              "current": false,
              "max": false,
              "min": false,
              "show": true,
              "total": false,
              "values": false
            },
            "lines": true,
            "linewidth": 1,
            "nullPointMode": "null",
            "options": {
              "alertThreshold": true
            },
            "percentage": false,
            "pluginVersion": "7.2.0",
            "pointradius": 2,
            "points": false,
            "renderer": "flot",
            "seriesOverrides": [],
            "spaceLength": 10,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "expr": "kafka_consumer_consumer_fetch_manager_metrics_records_lag_max",
                "interval": "",
                "legendFormat": "{{topic}}",
                "refId": "A"
              }
            ],
            "thresholds": [],
            "timeFrom": null,
            "timeRegions": [],
            "timeShift": null,
            "title": "Consumer Lag",
            "tooltip": {
              "shared": true,
              "sort": 0,
              "value_type": "individual"
            },
            "type": "graph",
            "xaxis": {
              "buckets": null,
              "mode": "time",
              "name": null,
              "show": true,
              "values": []
            },
            "yaxes": [
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ],
            "yaxis": {
              "align": false,
              "alignLevel": null
            }
          },
          {
            "aliasColors": {},
            "bars": false,
            "dashLength": 10,
            "dashes": false,
            "datasource": "Prometheus",
            "fieldConfig": {
              "defaults": {
                "custom": {}
              },
              "overrides": []
            },
            "fill": 1,
            "fillGradient": 0,
            "gridPos": {
              "h": 8,
              "w": 12,
              "x": 12,
              "y": 8
            },
            "hiddenSeries": false,
            "id": 5,
            "legend": {
              "avg": false,
              "current": false,
              "max": false,
              "min": false,
              "show": true,
              "total": false,
              "values": false
            },
            "lines": true,
            "linewidth": 1,
            "nullPointMode": "null",
            "options": {
              "alertThreshold": true
            },
            "percentage": false,
            "pluginVersion": "7.2.0",
            "pointradius": 2,
            "points": false,
            "renderer": "flot",
            "seriesOverrides": [],
            "spaceLength": 10,
            "stack": false,
            "steppedLine": false,
            "targets": [
              {
                "expr": "kafka_server_replicamanager_underreplicatedpartitions",
                "interval": "",
                "legendFormat": "Under Replicated Partitions",
                "refId": "A"
              }
            ],
            "thresholds": [],
            "timeFrom": null,
            "timeRegions": [],
            "timeShift": null,
            "title": "Under Replicated Partitions",
            "tooltip": {
              "shared": true,
              "sort": 0,
              "value_type": "individual"
            },
            "type": "graph",
            "xaxis": {
              "buckets": null,
              "mode": "time",
              "name": null,
              "show": true,
              "values": []
            },
            "yaxes": [
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              },
              {
                "format": "short",
                "label": null,
                "logBase": 1,
                "max": null,
                "min": null,
                "show": true
              }
            ],
            "yaxis": {
              "align": false,
              "alignLevel": null
            }
          }
        ],
        "refresh": "10s",
        "schemaVersion": 26,
        "style": "dark",
        "tags": [],
        "templating": {
          "list": []
        },
        "time": {
          "from": "now-1h",
          "to": "now"
        },
        "timepicker": {},
        "timezone": "",
        "title": "Kafka Overview",
        "uid": "kafka-overview",
        "version": 1
      }
    EOT
  }
}

# Grafana ConfigMap for Datasources
resource "kubernetes_config_map" "grafana_datasources" {
  metadata {
    name      = "grafana-datasources"
    namespace = var.namespace
  }

  data = {
    "datasources.yaml" = <<-EOT
      apiVersion: 1
      datasources:
        - name: Prometheus
          type: prometheus
          url: http://prometheus:9090
          access: proxy
          isDefault: true
    EOT
  }
}

# Prometheus Deployment
resource "kubernetes_deployment" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
    labels = {
      app = "prometheus"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "prometheus"
      }
    }

    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }

      spec {
        security_context {
          run_as_user = 65534  # nobody user
          fs_group    = 65534
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "prometheus"
          image = "prom/prometheus@sha256:d2ab0a27783fd4ad96a8853e2847b99a0be0043687b8a5d1ebfb2dd3fa4fd1b8"
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

          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=${var.retention_days}d",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles",
            "--web.enable-lifecycle"
          ]

          port {
            container_port = 9090
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "2Gi"
              cpu    = "1000m"
            }
          }

          volume_mount {
            name       = "config-volume"
            mount_path = "/etc/prometheus"
          }

          volume_mount {
            name       = "prometheus-data"
            mount_path = "/prometheus"
          }

          liveness_probe {
            http_get {
              path = "/-/healthy"
              port = 9090
            }
            initial_delay_seconds = 30
            period_seconds        = 15
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/-/ready"
              port = 9090
            }
            initial_delay_seconds = 30
            period_seconds        = 5
            timeout_seconds       = 4
            failure_threshold     = 3
          }
        }

        volume {
          name = "config-volume"
          config_map {
            name = kubernetes_config_map.prometheus_config.metadata[0].name
          }
        }

        volume {
          name = "prometheus-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.prometheus_data.metadata[0].name
          }
        }
      }
    }
  }
}

# Prometheus PVC
resource "kubernetes_persistent_volume_claim" "prometheus_data" {
  metadata {
    name      = "prometheus-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.prometheus_storage_size
      }
    }
  }
}

# Prometheus Service
resource "kubernetes_service" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
    labels = {
      app = "prometheus"
    }
  }

  spec {
    selector = {
      app = "prometheus"
    }

    port {
      port        = 9090
      target_port = 9090
      name        = "http"
    }
  }
}

# Grafana Deployment
resource "kubernetes_deployment" "grafana" {
  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels = {
      app = "grafana"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "grafana"
      }
    }

    template {
      metadata {
        labels = {
          app = "grafana"
        }
      }

      spec {
        security_context {
          run_as_user = 472  # grafana user
          fs_group    = 472
          run_as_non_root = true
          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = "grafana"
          image = "grafana/grafana@sha256:1a359d92f40ef98049b1aac3e43cb4a569f5dc0e552caa883a6b6f4ae1eacded"
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
            container_port = 3000
            name           = "http"
          }

          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.grafana_admin_password
          }

          env {
            name  = "GF_USERS_ALLOW_SIGN_UP"
            value = "false"
          }

          env {
            name  = "GF_INSTALL_PLUGINS"
            value = "grafana-piechart-panel"
          }

          env {
            name  = "GF_DASHBOARDS_DEFAULT_HOME_DASHBOARD_PATH"
            value = "/etc/grafana/provisioning/dashboards/kafka-overview.json"
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          volume_mount {
            name       = "grafana-data"
            mount_path = "/var/lib/grafana"
          }

          volume_mount {
            name       = "grafana-datasources"
            mount_path = "/etc/grafana/provisioning/datasources"
          }

          volume_mount {
            name       = "grafana-dashboards"
            mount_path = "/etc/grafana/provisioning/dashboards"
          }

          liveness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 60
            timeout_seconds       = 30
            period_seconds        = 10
            failure_threshold     = 10
          }

          readiness_probe {
            http_get {
              path = "/api/health"
              port = 3000
            }
            initial_delay_seconds = 60
            timeout_seconds       = 30
            period_seconds        = 10
            failure_threshold     = 10
          }
        }

        volume {
          name = "grafana-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.grafana_data.metadata[0].name
          }
        }

        volume {
          name = "grafana-datasources"
          config_map {
            name = kubernetes_config_map.grafana_datasources.metadata[0].name
          }
        }

        volume {
          name = "grafana-dashboards"
          config_map {
            name = kubernetes_config_map.grafana_dashboards.metadata[0].name
          }
        }
      }
    }
  }
}

# Grafana PVC
resource "kubernetes_persistent_volume_claim" "grafana_data" {
  metadata {
    name      = "grafana-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.grafana_storage_size
      }
    }
  }
}

# Grafana Service
resource "kubernetes_service" "grafana" {
  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels = {
      app = "grafana"
    }
  }

  spec {
    selector = {
      app = "grafana"
    }

    port {
      port        = 3000
      target_port = 3000
      name        = "http"
    }
  }
}

# Outputs
output "prometheus_service_name" {
  value = kubernetes_service.prometheus.metadata[0].name
}

output "grafana_service_name" {
  value = kubernetes_service.grafana.metadata[0].name
}
