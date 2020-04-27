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
    playground              = string
    serlo_cloudflare_worker = string
    serlo_org               = string
  })
}

variable "redis_host" {
  description = "Redis host to use for Cache"
  type        = string
}

variable "serlo_org_ip_address" {
  description = "IP address of serlo.org server"
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
        max_unavailable = "1"
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
            name  = "PLAYGROUND_SECRET"
            value = var.secrets.playground
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
            name  = "REDIS_HOST"
            value = var.redis_host
          }

          resources {
            limits {
              cpu    = "375m"
              memory = "150Mi"
            }

            requests {
              cpu    = "250m"
              memory = "100Mi"
            }
          }
        }
      }
    }
  }

  # Ignore changes to number of replicas since we have autoscaling enabled
  #  lifecycle {
  #    ignore_changes = [
  #      spec.0.replicas
  #    ]
  #  }
}

#resource "kubernetes_horizontal_pod_autoscaler" "server" {
#  metadata {
#    name      = local.name
#    namespace = var.namespace
#  }
#
#  spec {
#    max_replicas = 5
#
#    scale_target_ref {
#      api_version = "apps/v1"
#      kind        = "Deployment"
#      name        = local.name
#    }
#  }
#}
