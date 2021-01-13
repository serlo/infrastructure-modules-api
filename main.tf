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

variable "google_spreadsheet_api" {
  description = "Configuration for Google Spreadsheet API"
  type = object({
    active_donors = string
    secret        = string
  })
}

variable "log_level" {
  description = "log level"
  type        = string
  default     = "INFO"
}

variable "redis_url" {
  description = "Redis URL to use for Cache"
  type        = string
}

variable "sentry_dsn" {
  description = "Sentry DSN"
  type        = string
}

variable "serlo_org_ip_address" {
  description = "IP address of serlo.org server"
  type        = string
}

variable "server" {
  description = "Configuration for server"
  type = object({
    hydra_host = string
    swr_queue_dashboard = object({
      username = string
      password = string
    })
  })
}

variable "swr_queue_worker" {
  description = "Configuration for SWR Queue worker"
  type = object({
    concurrency = number
  })
}

variable "database_layer" {
  description = "Configuration for Database Layer"
  type = object({
    image_tag = string

    database_url             = string
    database_max_connections = number
  })
}

module "secrets" {
  source = "./secrets"
}

module "database_layer" {
  source = "./database-layer"

  namespace         = var.namespace
  image_tag         = var.database_layer.image_tag
  image_pull_policy = var.image_pull_policy

  serlo_org_database_url   = var.database_layer.database_url
  database_max_connections = var.database_layer.database_max_connections
}

module "server" {
  source = "./server"

  namespace         = var.namespace
  image_tag         = var.image_tag
  image_pull_policy = var.image_pull_policy

  environment                   = var.environment
  log_level                     = var.log_level
  redis_url                     = var.redis_url
  secrets                       = module.secrets
  sentry_dsn                    = var.sentry_dsn
  google_spreadsheet_api        = var.google_spreadsheet_api
  hydra_host                    = var.server.hydra_host
  serlo_org_database_layer_host = module.database_layer.host
  serlo_org_ip_address          = var.serlo_org_ip_address
  swr_queue_dashboard           = var.server.swr_queue_dashboard
}

module "swr_queue_worker" {
  source = "./swr-queue-worker"

  namespace         = var.namespace
  image_tag         = var.image_tag
  image_pull_policy = var.image_pull_policy

  environment                   = var.environment
  log_level                     = var.log_level
  redis_url                     = var.redis_url
  secrets                       = module.secrets
  sentry_dsn                    = var.sentry_dsn
  google_spreadsheet_api        = var.google_spreadsheet_api
  serlo_org_database_layer_host = module.database_layer.host
  serlo_org_ip_address          = var.serlo_org_ip_address
  concurrency                   = var.swr_queue_worker.concurrency
}

output "server_service_name" {
  value = module.server.service_name
}

output "server_service_port" {
  value = module.server.service_port
}

output "server_host" {
  value = module.server.host
}

output "swr_queue_worker_service_name" {
  value = module.swr_queue_worker.service_name
}

output "swr_queue_worker_service_port" {
  value = module.swr_queue_worker.service_port
}

output "swr_queue_worker_host" {
  value = module.swr_queue_worker.host
}

output "secrets_serlo_cloudflare_worker" {
  value = module.secrets.serlo_cloudflare_worker
}

output "secrets_serlo_org" {
  value = module.secrets.serlo_org
}
