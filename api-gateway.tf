
variable "vault_addr" {
  default = "https://vault.john-weigand.sbx.hashidemos.io"
}
variable "vault_namespace" {
  default = "demos/private-oidc/"
}

locals {
  proxy_url = "https://${aws_route53_record.vpc_link.fqdn}/v1/${var.vault_namespace}identity/oidc/plugins"
}


# Based losely on https://github.com/hashicorp/terraform-provider-aws/tree/main/examples/api-gateway-rest-api-openapi
# Original credit https://github.com/hashi-strawb/tf-vault-aws-plugin-wif/blob/main/main.tf

#
# API Gateway
#

resource "aws_api_gateway_rest_api" "example" {
  /*
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
            connectionType       = "VPC_LINK"
            connectionId         = aws_api_gateway_vpc_link.this.id
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
            connectionType       = "VPC_LINK"
            connectionId         = aws_api_gateway_vpc_link.this.id
            #uri = "https://ip-ranges.amazonaws.com/ip-ranges.json"
          }
        }
      }
    }
  })

*/



  name = "Plugin WIF Proxy"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}


resource "aws_api_gateway_resource" "v1" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id
  path_part   = "v1"
}

resource "aws_api_gateway_resource" "demos" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.v1.id
  path_part   = "demos"
}


resource "aws_api_gateway_resource" "private-oidc" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.demos.id
  path_part   = "private-oidc"
}

resource "aws_api_gateway_resource" "identity" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.private-oidc.id
  path_part   = "identity"
}

resource "aws_api_gateway_resource" "oidc" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.identity.id
  path_part   = "oidc"
}

resource "aws_api_gateway_resource" "plugins" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.oidc.id
  path_part   = "plugins"
}

resource "aws_api_gateway_resource" "well-known" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.plugins.id
  path_part   = ".well-known"
}

resource "aws_api_gateway_resource" "keys" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.well-known.id
  path_part   = "keys"
}

resource "aws_api_gateway_method" "keys" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.keys.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_resource" "oidc-configuration" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  parent_id   = aws_api_gateway_resource.well-known.id
  path_part   = "openid-configuration"
}

resource "aws_api_gateway_method" "oidc" {
  rest_api_id   = aws_api_gateway_rest_api.example.id
  resource_id   = aws_api_gateway_resource.oidc-configuration.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "keys" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.keys.id
  http_method = aws_api_gateway_method.keys.http_method

  type                    = "HTTP_PROXY"
  uri                     = "${local.proxy_url}/.well-known/keys"
  integration_http_method = "GET"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.this.id
}

resource "aws_api_gateway_integration" "oidc" {
  rest_api_id = aws_api_gateway_rest_api.example.id
  resource_id = aws_api_gateway_resource.oidc-configuration.id
  http_method = aws_api_gateway_method.oidc.http_method

  type                    = "HTTP_PROXY"
  uri                     = "${local.proxy_url}/.well-known/openid-configuration"
  integration_http_method = "GET"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.this.id
}



resource "aws_api_gateway_deployment" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.example.body))
  }


  depends_on = [
    aws_api_gateway_integration.keys,
    aws_api_gateway_integration.oidc
  ]

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

variable "hosted_zone" {
  default = "john-weigand.sbx.hashidemos.io"
}


resource "aws_acm_certificate" "example" {
  domain_name       = local.public_fqdn
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
  name    = "${var.public_hostname}.${var.hosted_zone}"
  type    = "A"

  alias {
    name                   = aws_api_gateway_domain_name.example.regional_domain_name
    zone_id                = aws_api_gateway_domain_name.example.regional_zone_id
    evaluate_target_health = true
  }
}

# NLB for API Gateway PrivateLink

variable "public_subnet_ids" {
  type    = list(string)
  default = ["subnet-07c7255688883867d", "subnet-097b378990b1b72d1", "subnet-0c5f47eef00a4ed91"]
}

variable "vpc_id" {
  type    = string
  default = "vpc-024f1be7071325f6e"
}

resource "aws_lb" "this" {
  name_prefix                                                  = "vpcl-"
  internal                                                     = true
  load_balancer_type                                           = "network"
  subnets                                                      = var.public_subnet_ids
  enforce_security_group_inbound_rules_on_private_link_traffic = "off"
  security_groups                                              = [aws_security_group.nlb.id]
}

resource "aws_route53_record" "vpc_link" {
  zone_id = data.aws_route53_zone.example.zone_id
  name    = "vpclink.${var.hosted_zone}"
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

resource "aws_lb_target_group" "this" {
  name        = "vault-vpc-link"
  target_type = "instance"
  port        = 8200
  protocol    = "TCP"
  vpc_id      = var.vpc_id

  health_check {
    protocol = "HTTPS"
    port     = "traffic-port"

    path = "/v1/sys/health?standbyok=true&perfstandbyok=true&activecode=200&standbycode=429&drsecondarycode=472&performancestandbycode=473&sealedcode=503&uninitcode=200"
  }
}

data "aws_autoscaling_group" "vault" {
  name = "vault-ent-asg"
}

data "aws_security_group" "vault" {
  name = "vault-ent-sg"
}

resource "aws_security_group_rule" "vault" {
  type                     = "ingress"
  from_port                = 8200
  to_port                  = 8200
  protocol                 = "TCP"
  security_group_id        = data.aws_security_group.vault.id
  source_security_group_id = aws_security_group.nlb.id
}

resource "aws_autoscaling_attachment" "example" {
  autoscaling_group_name = data.aws_autoscaling_group.vault.id
  lb_target_group_arn    = aws_lb_target_group.this.arn
}

resource "aws_lb_listener" "vault_api" {
  load_balancer_arn = aws_lb.this.id
  port              = 443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}



resource "aws_security_group" "nlb" {
  name_prefix = "vpc-link-"
  vpc_id      = var.vpc_id
}

resource "aws_security_group_rule" "nlb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nlb.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_api_gateway_vpc_link" "this" {
  name        = "vpc-link"
  target_arns = [aws_lb.this.arn]
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
  value       = "https://${var.public_hostname}.${var.hosted_zone}/v1/${var.vault_namespace}identity/oidc/plugins/.well-known/openid-configuration"
}


