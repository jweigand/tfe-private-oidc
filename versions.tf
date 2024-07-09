terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "weigand-hcp"
    hostname     = "app.terraform.io"

    workspaces {
      name = "tfe-vault-backed-oidc"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "3.4.1"
    }
  }
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}

provider "vault" {
  address   = hcp_vault_cluster.this.vault_private_endpoint_url
  token     = hcp_vault_cluster_admin_token.this.token
  namespace = "admin"
}

provider "vault" {
  address   = hcp_vault_cluster.this.vault_private_endpoint_url
  token     = hcp_vault_cluster_admin_token.this.token
  namespace = "admin/demo"
  alias     = "demo"
}
