resource "random_password" "playground" {
  length  = 32
  special = false
}

output "playground" {
  description = "Shared secret between api.serlo.org and its playground"
  value       = random_password.playground.result
}

resource "random_password" "serlo_cloudflare_worker" {
  length  = 32
  special = false
}

output "serlo_cloudflare_worker" {
  description = "Shared secret between api.serlo.org and serlo.org-cloudflare-worker"
  value       = random_password.serlo_cloudflare_worker.result
}

resource "random_password" "serlo_org" {
  length  = 32
  special = false
}

output "serlo_org" {
  description = "Shared secret between api.serlo.org and serlo.org"
  value       = random_password.serlo_org.result
}
