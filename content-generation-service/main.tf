locals {
  name = "content-generation-service"
}

variable "namespace" {
  type = string
}

variable "image_tag" {
  type = string
}

variable "image_pull_policy" {
  type = string
}

variable "node_pool" {
  type = string
}

variable "openai_api_key" {
  type = string
}

resource "kubernetes_service" "content-generation-service" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "${local.name}"
    }

    port {
      port        = 8082
      target_port = 8082
    }

    type = "ClusterIP"
  }
}

output "service_name" {
  value = kubernetes_service.content-generation-service.metadata[0].name
}

output "service_port" {
  value = kubernetes_service.content-generation-service.spec[0].port[0].port
}

output "host" {
  value = "${kubernetes_service.content-generation-service.spec[0].cluster_ip}:${kubernetes_service.content-generation-service.spec[0].port[0].port}"
}

resource "kubernetes_deployment" "content-generation-service" {
  metadata {
    name      = local.name
    namespace = var.namespace

    labels = {
      app = "${local.name}"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "${local.name}"
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
          app = "${local.name}"
        }
      }

      spec {
        node_selector = {
          "cloud.google.com/gke-nodepool" = var.node_pool
        }

        container {
          image             = "eu.gcr.io/serlo-shared/content-generation-service:${var.image_tag}"
          name              = local.name
          image_pull_policy = var.image_pull_policy

          liveness_probe {
            http_get {
              path = "/health"
              port = 8082
            }

            initial_delay_seconds = 5
            period_seconds        = 30
          }

          env {
            name  = "OPENAI_API_KEY"
            value = var.openai_api_key
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests = {
              cpu    = "100m"
              memory = "100Mi"
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
