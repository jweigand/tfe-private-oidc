resource "aws_lb" "alb" {
  name               = "tfe-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "tfe-alb"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = aws_acm_certificate.tfe.arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Cannot access TFE directly."
      status_code  = "200"
    }
  }
  depends_on = [aws_acm_certificate_validation.tfe]
}

resource "aws_lb_listener_rule" "oidc" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe.arn
  }
  condition {
    path_pattern {
      values = ["/.well-known/openid-configuration/"]
    }
  }
}

resource "aws_lb_listener_rule" "jwks" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 11
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe.arn
  }
  condition {
    path_pattern {
      values = ["/.well-known/jwks/"]
    }
  }
}

data "aws_autoscaling_group" "tfe" {
  name = "tfe-${var.tfe_name}-asg"
}

resource "aws_lb_target_group" "tfe" {
  name     = "tfe-alb"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = data.aws_vpc.this.id

  health_check {
    path     = "/_health_check"
    port     = "443"
    protocol = "HTTPS"
  }
}

resource "aws_autoscaling_attachment" "tfe" {
  autoscaling_group_name = data.aws_autoscaling_group.tfe.id
  lb_target_group_arn    = aws_lb_target_group.tfe.arn
}

resource "aws_security_group" "alb" {
  name_prefix = "tfe_alb"
  vpc_id      = data.aws_vpc.this.id
}

resource "aws_security_group_rule" "alb_ingress" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "TCP"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

variable "tfe_name" {
  type    = string
  default = "evolving-beetle"
}
