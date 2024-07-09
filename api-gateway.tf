
variable "vault_namespace" {
  default = "admin/demo/"
}

variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-07c7255688883867d", "subnet-097b378990b1b72d1", "subnet-0c5f47eef00a4ed91"]
}

locals {
  vault_addr = hcp_vault_cluster.this.vault_private_endpoint_url
  proxy_url  = "${local.vault_addr}/v1/${var.vault_namespace}identity/oidc/plugins"
}

/*
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
*/

#
# API Gateway
#

resource "aws_api_gateway_vpc_link" "example" {
  name        = "example"
  target_arns = [aws_lb.this.arn]
}

resource "aws_api_gateway_rest_api" "example" {
  body = jsonencode({
    openapi = "3.0.1"
    info = {
      title   = "Plugin WIF Proxy"
      version = "1.0"
    }
    paths = {
      "v1/${var.vault_namespace}identity/oidc/plugins/.well-known/openid-configuration" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "${local.proxy_url}/.well-known/openid-configuration"
            #uri = "https://ip-ranges.amazonaws.com/ip-ranges.json"

          }
        }
      }
      "v1/${var.vault_namespace}identity/oidc/plugins/.well-known/keys" = {
        get = {
          x-amazon-apigateway-integration = {
            httpMethod           = "GET"
            payloadFormatVersion = "1.0"
            type                 = "HTTP_PROXY"
            uri                  = "${local.proxy_url}/.well-known/keys"
            #uri = "https://ip-ranges.amazonaws.com/ip-ranges.json"
          }
        }
      }
    }
  })

  name = "Plugin WIF Proxy"


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
  variables = {
    vpcLinkID = aws_api_gateway_vpc_link.example.id
  }
}



#
# ACM Cert
#

variable "hosted_zone" {
  default = "john-weigand.sbx.hashidemos.io"
}


resource "aws_acm_certificate" "example" {
  domain_name       = "vault-plugin-wif.${var.hosted_zone}"
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
  depends_on = [
    // need to wait for the validation to finish before we can use the domain
    aws_acm_certificate_validation.example
  ]

  domain_name              = aws_acm_certificate.example.domain_name
  regional_certificate_arn = aws_acm_certificate.example.arn

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
  name    = "vault-plugin-wif.${var.hosted_zone}"
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.example.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.example.regional_zone_id
    evaluate_target_health = true
  }
}



#
# Outputs
#

output "invoke_url" {
  value = "${aws_api_gateway_stage.example.invoke_url}/${var.vault_namespace}identity/oidc/plugins/.well-known/openid-configuration"
}


output "proxy_url" {
  depends_on = [aws_api_gateway_base_path_mapping.example]

  description = "API Gateway Domain URL (self-signed certificate)"
  value       = "https://vault-plugin-wif.${var.hosted_zone}/v1/${var.vault_namespace}identity/oidc/plugins/.well-known/openid-configuration"
}
