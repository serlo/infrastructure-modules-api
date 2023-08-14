locals {
  name = "api-db-migration"
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

variable "database_url" {
  type = string
}

resource "kubernetes_job" "migration" {
  metadata {
    name      = local.name
    namespace = var.namespace

    labels = {
      app = local.name
    }
  }

  spec {
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
            name  = "DATABASE"
            value = var.database_url
          }
        }
      }
    }
  }

  wait_for_completion = false
}
