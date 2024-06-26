data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_iam_instance_profile" "proxy" {
  name = "proxy"
  role = data.aws_iam_role.ssm.name
}

data "aws_iam_role" "ssm" {
  name = "AmazonSSMRoleForInstancesQuickSetup"
}

data "aws_subnet" "this" {
  id = var.proxy_subnet_id
}

data "aws_vpc" "this" {
  id = data.aws_subnet.this.vpc_id
}

resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.proxy.name
  subnet_id                   = data.aws_subnet.this.id
  vpc_security_group_ids      = [aws_security_group.proxy.id]
  user_data_replace_on_change = true
  user_data                   = file("${path.module}/proxy-user-data.sh")

  tags = {
    Name = "proxy"
  }
}

resource "aws_security_group" "proxy" {
  name_prefix = "proxy"
  description = "Allow inbound traffic on port 80 and 443"
  vpc_id      = data.aws_subnet.this.vpc_id
}

resource "aws_security_group_rule" "proxy_ingress" {
  type              = "ingress"
  from_port         = 8118
  to_port           = 8118
  protocol          = "tcp"
  security_group_id = aws_security_group.proxy.id
  cidr_blocks       = [data.aws_vpc.this.cidr_block]
}

resource "aws_security_group_rule" "nlb_to_proxy_ingress" {
  type                     = "ingress"
  from_port                = 8118
  to_port                  = 8118
  protocol                 = "tcp"
  security_group_id        = aws_security_group.proxy.id
  source_security_group_id = aws_security_group.nlb.id
}

resource "aws_security_group_rule" "proxy_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.proxy.id
  cidr_blocks       = ["0.0.0.0/0"]
}

variable "proxy_subnet_id" {
  type    = string
  default = "subnet-048e666f6841f2475"
}

