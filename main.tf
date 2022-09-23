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

variable "google_spreadsheet_api" {
  description = "Configuration for Google Spreadsheet API"
  type = object({
    active_donors = string
    motivation    = string
    secret        = string
  })
}

variable "rocket_chat_api" {
  description = "Configuration for API of Rocket.Chat"
  type = object({
    user_id    = string
    auth_token = string
    url        = string
  })
}

variable "mailchimp_api" {
  description = "Configuration for API of Mailchimp"
  type = object({
    key = string
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

variable "server" {
  description = "Configuration for server"
  type = object({
    hydra_host             = string
    kratos_public_host     = string
    kratos_admin_host      = string
    kratos_secret          = string
    google_service_account = string
    swr_queue_dashboard = object({
      username = string
      password = string
    })
    sentry_dsn = string
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
    sentry_dsn               = string
  })
}

variable "cache_worker" {
  description = "Configuration for Cache Worker"
  type = object({
    image_tag      = string
    enable_cronjob = bool
  })
}

module "secrets" {
  source = "./secrets"
}

module "database_layer" {
  source = "./database-layer"

  suffix            = ""
  namespace         = var.namespace
  image_tag         = var.database_layer.image_tag
  image_pull_policy = var.image_pull_policy
  node_pool         = var.node_pool

  environment              = var.environment
  sentry_dsn               = var.database_layer.sentry_dsn
  serlo_org_database_url   = var.database_layer.database_url
  database_max_connections = var.database_layer.database_max_connections
}

module "database_layer_swr" {
  source = "./database-layer"

  suffix            = "-swr"
  namespace         = var.namespace
  image_tag         = var.database_layer.image_tag
  image_pull_policy = var.image_pull_policy
  node_pool         = var.node_pool

  environment              = var.environment
  sentry_dsn               = var.database_layer.sentry_dsn
  serlo_org_database_url   = var.database_layer.database_url
  database_max_connections = var.database_layer.database_max_connections
}

module "server" {
  source = "./server"

  namespace         = var.namespace
  image_tag         = var.image_tag
  image_pull_policy = var.image_pull_policy
  node_pool         = var.node_pool

  environment                   = var.environment
  log_level                     = var.log_level
  redis_url                     = var.redis_url
  secrets                       = module.secrets
  sentry_dsn                    = var.server.sentry_dsn
  google_service_account        = var.server.google_service_account
  google_spreadsheet_api        = var.google_spreadsheet_api
  rocket_chat_api               = var.rocket_chat_api
  mailchimp_api                 = var.mailchimp_api
  hydra_host                    = var.server.hydra_host
  kratos_public_host            = var.server.kratos_public_host
  kratos_admin_host             = var.server.kratos_admin_host
  kratos_secret                 = var.server.kratos_secret
  serlo_org_database_layer_host = module.database_layer.host
  swr_queue_dashboard           = var.server.swr_queue_dashboard
}

module "swr_queue_worker" {
  source = "./swr-queue-worker"

  namespace         = var.namespace
  image_tag         = var.image_tag
  image_pull_policy = var.image_pull_policy
  node_pool         = var.node_pool

  environment                   = var.environment
  log_level                     = var.log_level
  redis_url                     = var.redis_url
  secrets                       = module.secrets
  sentry_dsn                    = var.server.sentry_dsn
  google_spreadsheet_api        = var.google_spreadsheet_api
  rocket_chat_api               = var.rocket_chat_api
  mailchimp_api                 = var.mailchimp_api
  serlo_org_database_layer_host = module.database_layer_swr.host
  concurrency                   = var.swr_queue_worker.concurrency
}

module "cache_worker" {
  source = "./cache-worker"

  namespace = var.namespace
  image_tag = var.cache_worker.image_tag
  node_pool = var.node_pool

  api_host       = module.server.host
  secret         = module.secrets.serlo_cache_worker
  enable_cronjob = var.cache_worker.enable_cronjob
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
