resource "aws_vpc_endpoint" "api" {
  vpc_id            = data.aws_vpc.this.id
  service_name      = "com.amazonaws.${var.aws_region}.execute-api"
  vpc_endpoint_type = "Interface"

  security_group_ids = [aws_security_group.api_endpoint.id]

  subnet_ids = var.public_subnet_ids

  private_dns_enabled = true
}

resource "aws_security_group" "api_endpoint" {
  vpc_id = data.aws_vpc.this.id
}

data "aws_network_interface" "api" {
  for_each = toset(aws_vpc_endpoint.api.network_interface_ids)
  id       = each.value
}

output "endpoint_ips" {
  value = [for eni in data.aws_network_interface.api : eni.private_ip]

}
