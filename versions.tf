terraform {
  required_version = ">= 0.14"
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 2.0"
    }
  }
}
