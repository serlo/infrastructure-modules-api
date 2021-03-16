locals {
  name = "swr-queue-worker"
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

variable "environment" {
  description = "environment"
  type        = string
}

variable "log_level" {
  description = "log level"
  type        = string
}

variable "redis_url" {
  description = "Redis URL to use for Cache"
  type        = string
}

variable "secrets" {
  description = "Shared secrets between api.serlo.org and respective consumers"
  type = object({
    serlo_cloudflare_worker = string
    serlo_org               = string
  })
}

variable "sentry_dsn" {
  description = "Sentry DSN"
  type        = string
}

variable "google_spreadsheet_api" {
  description = "Configuration for Google Spreadsheet API"
  type = object({
    active_donors = string
    secret        = string
  })
}

variable "serlo_org_database_layer_host" {
  description = "Host of database layer"
  type        = string
}

variable "concurrency" {
  description = "Number of parallel requests"
  type        = number
}

resource "kubernetes_service" "server" {
  metadata {
    name      = local.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = local.name
    }

    port {
      port        = 3000
      target_port = 3000
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
  value = "http://${kubernetes_service.server.spec[0].cluster_ip}:${kubernetes_service.server.spec[0].port[0].port}/graphql"
}

resource "kubernetes_deployment" "server" {
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
      type = "Recreate"
    }

    replicas = 1

    template {
      metadata {
        labels = {
          app = local.name
        }
      }

      spec {
        container {
          image             = "eu.gcr.io/serlo-shared/api-swr-queue-worker:${var.image_tag}"
          name              = local.name
          image_pull_policy = var.image_pull_policy

          liveness_probe {
            http_get {
              path = "/.well-known/health"
              port = 3000
            }

            initial_delay_seconds = 5
            period_seconds        = 30
          }

          env {
            name  = "ENVIRONMENT"
            value = var.environment
          }

          env {
            name  = "GOOGLE_SPREADSHEET_API_ACTIVE_DONORS"
            value = var.google_spreadsheet_api.active_donors
          }

          env {
            name  = "GOOGLE_SPREADSHEET_API_SECRET"
            value = var.google_spreadsheet_api.secret
          }

          env {
            name  = "LOG_LEVEL"
            value = var.log_level
          }

          env {
            name  = "REDIS_URL"
            value = var.redis_url
          }

          env {
            name  = "SENTRY_DSN"
            value = var.sentry_dsn
          }

          env {
            name  = "SENTRY_RELEASE"
            value = var.image_tag
          }

          env {
            name  = "SERLO_ORG_DATABASE_LAYER_HOST"
            value = var.serlo_org_database_layer_host
          }

          env {
            name  = "SERLO_ORG_SECRET"
            value = var.secrets.serlo_org
          }

          env {
            name  = "SWR_QUEUE_WORKER_CONCURRENCY"
            value = var.concurrency
          }

          env {
            name  = "SWR_QUEUE_WORKER_DELAY"
            value = "250"
          }

          resources {
            limits {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests {
              cpu    = "100m"
              memory = "100Mi"
            }
          }
        }
      }
    }
  }
}
