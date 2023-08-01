locals {
  name = "cache-worker"
}

variable "namespace" {
  description = "Kubernetes namespace to use"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to use"
  type        = string
}

variable "node_pool" {
  type        = string
  description = "Node pool to use"
}

variable "secret" {
  description = "Shared secret between api.serlo.org and serlo.org-cache-worker"
  type        = string
}

variable "api_host" {
  description = "URL to API endpoint"
  type        = string
}

variable "enable_cronjob" {
  type        = bool
  description = "enables cache worker cronjob"
}

resource "kubernetes_cron_job_v1" "cache_worker" {
  count = var.enable_cronjob ? 1 : 0

  metadata {
    name      = "cache-worker"
    namespace = var.namespace

    labels = {
      app = local.name
    }
  }

  spec {
    concurrency_policy = "Forbid"
    schedule           = "0 5 * * *"
    job_template {
      metadata {}
      spec {
        backoff_limit = 2
        template {
          metadata {}
          spec {
            node_selector = {
              "cloud.google.com/gke-nodepool" = var.node_pool
            }

            container {
              name  = "cache-worker"
              image = "eu.gcr.io/serlo-shared/api-cache-worker:${var.image_tag}"

              env {
                name  = "API_HOST"
                value = var.api_host
              }
              env {
                name  = "SECRET"
                value = var.secret
              }
              env {
                name  = "SERVICE"
                value = "serlo.org-cache-worker"
              }
              # This ensures that changes to the config file trigger the cronjob
              env {
                name  = "CONFIG_CHECKSUM"
                value = sha256(file("${path.module}/cache-keys.json"))
              }
              volume_mount {
                name       = local.name
                mount_path = "/usr/src/app/dist/config/cache-keys.json"
                sub_path   = "cache-keys.json"
              }
            }
            volume {
              name = local.name

              config_map {
                name = kubernetes_config_map.cache-keys.metadata.0.name

                items {
                  key  = "cache-keys.json"
                  path = "cache-keys.json"
                }
              }
            }
            restart_policy = "Never"
          }
        }
      }
    }
  }
}

resource "kubernetes_config_map" "cache-keys" {
  metadata {
    name      = "cache-keys.json"
    namespace = var.namespace
  }

  data = {
    "cache-keys.json" = file("${path.module}/cache-keys.json")
  }
}
