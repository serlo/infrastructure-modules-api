locals {
  name = "db-migration"
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

resource "kubernetes_service" "migration" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = local.name
    }

    type = "ClusterIP"
  }
}

output "service_name" {
  value = kubernetes_service.migration.metadata[0].name
}

output "service_port" {
  value = kubernetes_service.migration.spec[0].port[0].port
}

output "host" {
  value = "http://${kubernetes_service.migration.spec[0].cluster_ip}:${kubernetes_service.migration.spec[0].port[0].port}/graphql"
}

resource "kubernetes_deployment" "migration" {
  metadata {
    name      = local.name
    namespace = var.namespace

    labels = {
      app = local.name
    }
  }

  spec {
    selector {
      match_labels = {
        app = local.name
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
          app = local.name
        }
      }

      spec {
        node_selector = {
          "cloud.google.com/gke-nodepool" = var.node_pool
        }

        container {
          image             = "eu.gcr.io/serlo-shared/api-db-migration:${var.image_tag}"
          name              = local.name
          image_pull_policy = var.image_pull_policy

          env {
            name  = "ENVIRONMENT"
            value = var.environment
          }

          resources {
            limits = {
              cpu    = "200m"
              memory = "100Mi"
            }

            requests = {
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

resource "kubernetes_horizontal_pod_autoscaler" "migration" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  spec {
    max_replicas = 5

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = local.name
    }
  }
}
