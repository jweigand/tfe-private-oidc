data "aws_vpc" "this" {
  id = var.vpc_id
}

variable "vpc_id" {
  type    = string
  default = "vpc-024f1be7071325f6e"
}

data "dns_a_record_set" "hcp_vault" {
  host = trim(trim(local.vault_addr, "https://"), ":8200")
}

output "vault_ips" {
  value = data.dns_a_record_set.hcp_vault.addrs

}
