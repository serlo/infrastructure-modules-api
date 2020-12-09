locals {
  name = "server"
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

variable "secrets" {
  description = "Shared secrets between api.serlo.org and respective consumers"
  type = object({
    serlo_cloudflare_worker = string
    serlo_org               = string
  })
}

variable "active_donors_data" {
  description = "Data for active donors endpoint"
  type = object({
    google_api_key        = string
    google_spreadsheet_id = string
  })
}

variable "redis_url" {
  description = "Redis url to use for Cache"
  type        = string
}

variable "hydra_host" {
  description = "Hydra host"
  type        = string
}

variable "serlo_org_ip_address" {
  description = "IP address of serlo.org server"
  type        = string
}

variable "sentry_dsn" {
  description = "Sentry DSN"
  type        = string
}

variable "sentry_environment" {
  description = "Sentry environment"
  type        = string
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
        host_aliases {
          ip = var.serlo_org_ip_address
          hostnames = [
            "de.serlo.localhost",
            "en.serlo.localhost",
            "es.serlo.localhost",
            "fr.serlo.localhost",
            "hi.serlo.localhost",
            "ta.serlo.localhost"
          ]
        }

        container {
          image             = "eu.gcr.io/serlo-shared/api:${var.image_tag}"
          name              = local.name
          image_pull_policy = var.image_pull_policy

          liveness_probe {
            http_get {
              path = "/.well-known/apollo/server-health"
              port = 3000
            }

            initial_delay_seconds = 5
            period_seconds        = 30
          }

          env {
            name  = "SERLO_ORG_HOST"
            value = "serlo.localhost"
          }

          env {
            name  = "SERLO_ORG_SECRET"
            value = var.secrets.serlo_org
          }

          env {
            name  = "SERLO_CLOUDFLARE_WORKER_SECRET"
            value = var.secrets.serlo_cloudflare_worker
          }

          env {
            name  = "REDIS_URL"
            value = var.redis_url
          }

          env {
            name  = "HYDRA_HOST"
            value = var.hydra_host
          }

          env {
            name  = "GOOGLE_API_KEY"
            value = var.active_donors_data.google_api_key
          }

          env {
            name  = "ACTIVE_DONORS_SPREADSHEET_ID"
            value = var.active_donors_data.google_spreadsheet_id
          }

          env {
            name  = "SENTRY_DSN"
            value = var.sentry_dsn
          }

          env {
            name  = "ENVIRONMENT"
            value = var.sentry_environment
          }

          env {
            name  = "LOG_LEVEL"
            value = "INFO"
          }

          resources {
            limits {
              cpu    = "300m"
              memory = "750Mi"
            }

            requests {
              cpu    = "200m"
              memory = "500Mi"
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
