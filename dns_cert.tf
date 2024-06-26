variable "hosted_zone" {
  default = "john-weigand.sbx.hashidemos.io"
}

data "aws_route53_zone" "this" {
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_route53_record" "tfe" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = "tfe-public"
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

resource "aws_route53_record" "cert" {
  for_each = {
    for dvo in aws_acm_certificate.tfe.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.this.zone_id
}

resource "aws_acm_certificate_validation" "tfe" {
  certificate_arn         = aws_acm_certificate.tfe.arn
  validation_record_fqdns = [for record in aws_route53_record.cert : record.fqdn]
}
