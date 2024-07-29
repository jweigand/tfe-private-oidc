variable "public_hostname" {
  default = "vault-oidc"
}

locals {
  public_fqdn        = "${var.public_hostname}.${var.hosted_zone}"
  oidc_audience      = "${local.public_fqdn}:443/v1${var.vault_namespace}identity/oidc/plugins"
  vault_plugins_addr = "https://${local.public_fqdn}/v1${var.vault_namespace}identity/oidc/plugins"
}



# https://developer.hashicorp.com/vault/docs/secrets/aws#plugin-workload-identity-federation-wif
data "tls_certificate" "vault_certificate" {
  url        = "https://${aws_route53_record.domain.fqdn}"
  depends_on = [aws_acm_certificate.example]
}
resource "aws_iam_openid_connect_provider" "vault_provider" {
  url             = data.tls_certificate.vault_certificate.url
  client_id_list  = [local.oidc_audience]
  thumbprint_list = [data.tls_certificate.vault_certificate.certificates[0].sha1_fingerprint]
}

resource "aws_iam_role" "plugins_role" {
  name = "vault-oidc-plugins"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "${aws_iam_openid_connect_provider.vault_provider.arn}"
     },
     "Action": "sts:AssumeRoleWithWebIdentity"
   }
 ]
}
EOF

  # TODO: this is waaaaay too much access; limit it to just what's needed
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AdministratorAccess"
  ]

  lifecycle {
    create_before_destroy = true
  }
}






resource "vault_generic_endpoint" "identity_config" {
  path = "identity/oidc/config"
  data_json = jsonencode({
    "issuer" = "https://${local.public_fqdn}"
  })

  // delete on this path is unsupported
  disable_delete = true
}



# BEGIN HASHI-SPECIFIC
locals {
  username_template = <<EOT
{{ if (eq .Type "STS") }}
	{{ printf "demo-john.weigand@hashicorp.com-vault-%s-%s" (random 20) (unix_time) | truncate 32 }}
{{ else }}
	{{ printf "demo-john.weigand@hashicorp.com-vault-%s-%s" (unix_time) (random 20) | truncate 60 }}
{{ end }}
EOT

  # Known good config
  #    {{ printf "${aws_iam_user.vault_mount_user.name}-vault-%s-%s" (unix_time) (random 20) | truncate 60 }}
  #
  # Template from https://developer.hashicorp.com/vault/api-docs/secret/aws#username_template
  #    {{ printf "vault-%s-%s-%s" (printf "%s-%s" (.DisplayName) (.PolicyName) | truncate 42) (unix_time) (random 20) | truncate 64 }}
  # I can't get that to work, so... Known Good is fine for now

  username_template_without_whitespace = replace(
    replace(
      local.username_template,
      "\n", ""
    ),
    "\t", ""
  )
}
data "aws_iam_policy" "demo_user_permissions_boundary" {
  name = "DemoUser"
}
# END HASHI-SPECIFIC


resource "vault_aws_secret_backend" "aws" {
  path                    = "aws/hashi"
  identity_token_audience = local.oidc_audience
  role_arn                = aws_iam_role.plugins_role.arn


  # Hashi-specific requirement
  username_template = local.username_template_without_whitespace
}

resource "vault_generic_endpoint" "aws-lmhd-lease" {
  path = "${vault_aws_secret_backend.aws.path}/config/lease"

  data_json = <<EOT
{
  "lease": "5m0s",
  "lease_max": "2h0m0s"
}
EOT


  // delete on this path is unsupported
  disable_delete = true
}

resource "vault_aws_secret_backend_role" "test" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "test"
  credential_type = "iam_user"

  permissions_boundary_arn = data.aws_iam_policy.demo_user_permissions_boundary.arn


  policy_document = <<EOT
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:List*"
            ],
            "Resource": "*"
        }
    ]
}
EOT
}


output "test_command" {
  value = "vault read ${vault_aws_secret_backend.aws.path}/creds/${vault_aws_secret_backend_role.test.name}"
}
