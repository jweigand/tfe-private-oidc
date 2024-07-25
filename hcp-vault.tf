/*
resource "hcp_hvn" "this" {
  hvn_id         = "vault-private"
  cloud_provider = "aws"
  region         = "us-east-1"
  cidr_block     = "192.168.0.0/24"
}

resource "hcp_aws_network_peering" "this" {
  hvn_id          = hcp_hvn.this.hvn_id
  peering_id      = "vault-private"
  peer_vpc_id     = data.aws_vpc.this.id
  peer_account_id = data.aws_vpc.this.owner_id
  peer_vpc_region = "us-east-1"
}

resource "hcp_hvn_route" "this" {
  hvn_link         = hcp_hvn.this.self_link
  hvn_route_id     = "private"
  destination_cidr = data.aws_vpc.this.cidr_block
  target_link      = hcp_aws_network_peering.this.self_link
}

resource "hcp_vault_cluster" "this" {
  cluster_id        = "vault-private"
  hvn_id            = hcp_hvn.this.hvn_id
  tier              = "dev"
  public_endpoint   = true
  min_vault_version = "1.15.4"
  proxy_endpoint    = "enabled"
}

output "vault_private_endpoint" {
  value = hcp_vault_cluster.this.vault_private_endpoint_url
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = hcp_aws_network_peering.this.provider_peering_id
  auto_accept               = true
}

data "aws_route_tables" "this" {
  vpc_id = var.vpc_id
}

resource "aws_route" "hcp" {
  for_each                  = toset(data.aws_route_tables.this.ids)
  route_table_id            = each.value
  destination_cidr_block    = hcp_hvn.this.cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection_accepter.peer.id
}

resource "hcp_vault_cluster_admin_token" "this" {
  cluster_id = hcp_vault_cluster.this.cluster_id
}

output "vault_private_endpoint_url" {
  value = hcp_vault_cluster.this.vault_private_endpoint_url
}
*/
