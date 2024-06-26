variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-07c7255688883867d", "subnet-097b378990b1b72d1", "subnet-0c5f47eef00a4ed91"]
}

resource "aws_lb" "tfe_nlb" {
  name               = "tfe-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.public_subnet_ids

  tags = {
    Name = "tfe-nlb"
  }
}

resource "aws_lb_target_group" "proxy" {
  name     = "proxy"
  port     = 8118
  protocol = "TCP"
  vpc_id   = data.aws_vpc.this.id
}

resource "aws_lb_target_group_attachment" "proxy" {
  target_group_arn = aws_lb_target_group.proxy.arn
  target_id        = aws_instance.proxy.id
  port             = 8118
}

resource "aws_lb_listener" "proxy" {
  load_balancer_arn = aws_lb.tfe_nlb.arn
  port              = "8118"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.proxy.arn
  }
}

resource "aws_security_group" "nlb" {
  name_prefix = "tfe_nlb"
  vpc_id      = data.aws_vpc.this.id
}

resource "aws_security_group_rule" "nlb_proxy_ingress" {
  type              = "ingress"
  from_port         = 8118
  to_port           = 8118
  protocol          = "tcp"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
}

resource "aws_security_group_rule" "nlb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

variable "hosted_zone" {
  default = "john-weigand.sbx.hashidemos.io"
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_route53_record" "tfe" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "tfe"
  type    = "A"

  alias {
    name                   = aws_lb.tfe_nlb.dns_name
    zone_id                = aws_lb.tfe_nlb.zone_id
    evaluate_target_health = false
  }
}
