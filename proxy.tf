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

resource "aws_instance" "proxy" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.proxy.name
  subnet_id                   = var.proxy_subnet_id
  #vpc_security_group_ids = []
  user_data_replace_on_change = true
  user_data                   = file("${path.module}/proxy-user-data.sh")

  tags = {
    Name = "proxy"
  }
}

variable "proxy_subnet_id" {
  type    = string
  default = "subnet-048e666f6841f2475"
}
