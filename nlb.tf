resource "aws_lb" "this" {
  name                                                         = "vpc-link"
  internal                                                     = false
  load_balancer_type                                           = "network"
  subnets                                                      = var.public_subnet_ids
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
  security_groups                                              = [aws_security_group.nlb.id]

  tags = {
    Name = "tfe-nlb"
  }
}

resource "aws_lb_listener" "nlb_https" {
  load_balancer_arn = aws_lb.this.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.vault.arn
  }
}

resource "aws_lb_target_group" "vault" {
  name        = "vault"
  port        = 443
  protocol    = "TCP"
  vpc_id      = data.aws_vpc.this.id
  target_type = "ip"

  health_check {
    port     = "8200"
    protocol = "TCP"
  }
}

resource "aws_lb_target_group_attachment" "vault" {
  for_each          = toset(data.dns_a_record_set.hcp_vault.addrs)
  target_group_arn  = aws_lb_target_group.vault.arn
  target_id         = each.value
  availability_zone = "all"
}


resource "aws_security_group" "nlb" {
  name_prefix = "vpc-link-"
  vpc_id      = data.aws_vpc.this.id
}
/*
resource "aws_security_group_rule" "nlb_https_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
}
*/

resource "aws_security_group_rule" "nlb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
}
