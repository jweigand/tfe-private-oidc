#credit to Lucy Davinhart for the original API gateway code for Vault (https://github.com/hashi-strawb/tf-vault-aws-plugin-wif/), and to Huseyin Unal for adapting it for TFE
/*
locals {
  custom_domain = "tfe.${var.hosted_zone}"
}

#
# API Gateway
#

resource "aws_api_gateway_rest_api" "example" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "TFE WIF API Gateway"
      version = "1.0"
    }
    paths = {
      ".well-known/openid-configuration" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://${var.tfe_addr}/.well-known/openid-configuration"

          }
        }
      }
      ".well-known/jwks" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "https://${var.tfe_addr}/.well-known/jwks"
          }
        }
      }
    }
  })

  name = "TFE WIF API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.example.body))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id
  rest_api_id   = aws_api_gateway_rest_api.example.id
  stage_name    = "v1" # TODO: Change this to something to reflext the specific Vault we're proxying
}



#
# ACM Cert
#

resource "aws_acm_certificate" "example" {
  domain_name       = local.custom_domain
  validation_method = "DNS"
}

data "aws_route53_zone" "example" {
  name         = var.hosted_zone
  private_zone = false
}

resource "aws_route53_record" "example" {
  for_each = {
    for dvo in aws_acm_certificate.example.domain_validation_options : dvo.domain_name => {
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
  zone_id         = data.aws_route53_zone.example.zone_id
}

resource "aws_acm_certificate_validation" "example" {
  certificate_arn         = aws_acm_certificate.example.arn
  validation_record_fqdns = [for record in aws_route53_record.example : record.fqdn]
}




#
# Custom Domain
#

resource "aws_api_gateway_domain_name" "example" {
  domain_name              = aws_acm_certificate.example.domain_name
  regional_certificate_arn = aws_acm_certificate_validation.example.certificate_arn

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_base_path_mapping" "example" {
  api_id      = aws_api_gateway_rest_api.example.id
  domain_name = aws_api_gateway_domain_name.example.domain_name
  stage_name  = aws_api_gateway_stage.example.stage_name
}

resource "aws_route53_record" "domain" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = local.custom_domain
  type    = "A"
  # allow_overwrite = true

  alias {
    name                   = aws_api_gateway_domain_name.example.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.example.regional_zone_id
    evaluate_target_health = true
  }
}

# Variables
variable "hosted_zone" {
  default = "john-weigand.sbx.hashidemos.io"
}

variable "tfe_addr" {
  type        = string
  description = "The hostname of the TFC or TFE instance you'd like to use with AWS"
  default     = "evolving-beetle.john-weigand.sbx.hashidemos.io"
}


#
# Outputs
#

output "invoke_url" {
  value = "${aws_api_gateway_stage.example.invoke_url}/.well-known/openid-configuration"
}


output "proxy_url" {
  depends_on = [aws_api_gateway_base_path_mapping.example]

  description = "API Gateway Domain URL (self-signed certificate)"
  value       = "https://${local.custom_domain}/.well-known/openid-configuration"
}
*/
