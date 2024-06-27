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

resource "aws_security_group_rule" "api_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.api_endpoint.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "api_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.api_endpoint.id
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_network_interface" "api" {
  for_each = toset(aws_vpc_endpoint.api.network_interface_ids)
  id       = each.value
}

output "endpoint_ips" {
  value = [for eni in data.aws_network_interface.api : eni.private_ip]

}
