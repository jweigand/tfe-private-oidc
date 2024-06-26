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

resource "aws_acm_certificate" "tfe" {
  domain_name       = aws_route53_record.tfe.fqdn
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "tfe" {
  certificate_arn         = aws_acm_certificate.tfe.arn
  validation_record_fqdns = [aws_route53_record.tfe.fqdn]
}
