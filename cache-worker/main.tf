locals {
  name = "cache_worker"
}

variable "namespace" {
  description = "Kubernetes namespace to use"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag to use"
  type        = string
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

resource "kubernetes_cron_job" "cache_worker" {
  count = var.enable_cronjob ? 1 : 0

  metadata {
    name      = "cache_worker"
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
        # TODO: ask
        backoff_limit = 2
        template {
          metadata {}
          spec {
            container {
              name  = "cache_worker"
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
            }
            restart_policy = "Never"
          }
        }
      }
    }
  }
}
