locals {
  name = "serlo-org-database-layer"
}

variable "suffix" {
  type = string
}

variable "namespace" {
  description = "Kubernetes namespace to use"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to use"
  type        = string
}

variable "image_pull_policy" {
  description = "image pull policy"
  type        = string
}

variable "node_pool" {
  type        = string
  description = "Node pool to use"
}

variable "environment" {
  description = "environment"
  type        = string
}

variable "serlo_org_database_url" {
  description = "Serlo.org Database URL"
  type        = string
}

variable "database_max_connections" {
  description = "Max Database connections"
  type        = number
}

variable "sentry_dsn" {
  description = "Sentry DSN"
  type        = string
}

resource "kubernetes_service" "server" {
  metadata {
    name      = "${local.name}${var.suffix}"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "${local.name}${var.suffix}"
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

output "service_name" {
  value = kubernetes_service.server.metadata[0].name
}

output "service_port" {
  value = kubernetes_service.server.spec[0].port[0].port
}

output "host" {
  value = "${kubernetes_service.server.spec[0].cluster_ip}:${kubernetes_service.server.spec[0].port[0].port}"
}

resource "kubernetes_deployment" "server" {
  metadata {
    name      = "${local.name}${var.suffix}"
    namespace = var.namespace

    labels = {
      app = "${local.name}${var.suffix}"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "${local.name}${var.suffix}"
      }
    }

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_surge       = "1"
        max_unavailable = "0"
      }
    }

    template {
      metadata {
        labels = {
          app = "${local.name}${var.suffix}"
        }
      }

      spec {
        node_selector = {
          "cloud.google.com/gke-nodepool" = var.node_pool
        }

        container {
          image             = "eu.gcr.io/serlo-shared/serlo-org-database-layer:${var.image_tag}"
          name              = "${local.name}${var.suffix}"
          image_pull_policy = var.image_pull_policy

          liveness_probe {
            http_get {
              path = "/.well-known/health"
              port = 8080
            }

            initial_delay_seconds = 5
            period_seconds        = 30
          }

          env {
            name  = "ENV"
            value = var.environment
          }

          env {
            name  = "DATABASE_URL"
            value = var.serlo_org_database_url
          }

          env {
            name  = "DATABASE_MAX_CONNECTIONS"
            value = var.database_max_connections
          }

          env {
            name  = "SENTRY_DSN"
            value = var.sentry_dsn
          }

          resources {
            limits {
              cpu    = "200m"
              memory = "100Mi"
            }

            requests {
              cpu    = "100m"
              memory = "50Mi"
            }
          }
        }
      }
    }
  }

  # Ignore changes to number of replicas since we have autoscaling enabled
  lifecycle {
    ignore_changes = [
      spec.0.replicas
    ]
  }
}

resource "kubernetes_horizontal_pod_autoscaler" "server" {
  metadata {
    name      = "${local.name}${var.suffix}"
    namespace = var.namespace
  }

  spec {
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "${local.name}${var.suffix}"
    }
  }
}
