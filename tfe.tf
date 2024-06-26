/*

# Pull in the base infrastructure from the Terrafrom Cloud workspace.

data "terraform_remote_state" "base-infra" {
  backend = "remote"

  config = {
    organization = "weigand-hcp"
    workspaces = {
      name = var.infra_workspace_name
    }
  }
}

# Set the data source for the base infrastructure to a local for ease of access

locals {
  base-infra = data.terraform_remote_state.base-infra.outputs
}

# Call the Terraform Enterprise module.

module "tfe" {
  source = "app.terraform.io/weigand-hcp/terraform-enterprise/aws"

  deployment_type  = "external-services"
  license_url      = local.base-infra.license_file
  license_channel  = var.license_channel
  release_sequence = var.release_sequence
  vpc              = local.base-infra.vpc
  zone_name        = local.base-infra.zone_name
  os_type          = var.os_type
  instance_type    = var.instance_type
  db_instance_size = var.db_instance_size
  override_email   = "john.weigand@hashicorp.com"
  asg_terminate    = var.asg_terminate
}

output "application_url" {
  value = module.tfe.application_url
}

output "replicated_dashboard" {
  value = module.tfe.replicated_dashboard
}

output "initial_admin_user_link" {
  value = module.tfe.initial_admin_user_link
}

output "tags" {
  value = module.tfe.tags
}

variable "release_sequence" {
  description = "The release sequence to install. Defaults to 0 (unpinned)."
  default     = 722
}

variable "license_channel" {
  description = "The license channel to use if not using the default (Stable) channel."
  default     = ""
}

variable "os_type" {
  description = "The OS to use for instance(s). Defaults to ubuntu."
  default     = "ubuntu"
}

variable "instance_type" {
  description = "(Optional) The type of the compute instance to create."
  type        = string
  default     = "m5a.xlarge"
}

variable "db_instance_size" {
  description = "(Optional) The type of DB instance to create."
  type        = string
  default     = "db.t2.small"
}

variable "infra_workspace_name" {
  type    = string
  default = "tfe-1-base-infra"
}

variable "asg_terminate" {
  type    = bool
  default = true
}
*/
