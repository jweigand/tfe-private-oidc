terraform {
  required_version = ">= 1.0"

  cloud {
    organization = "weigand-hcp"
    hostname     = "app.terraform.io"

    workspaces {
      name = "vault-private-oidc"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
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
  address   = "https://vault.john-weigand.sbx.hashidemos.io:8200"
  namespace = var.vault_namespace
}
