# Provider Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Último AMI oficial de Ubuntu 22.04 (amd64) publicado por Canonical
data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "monitor_sat" {
  name_prefix = "${var.project_name}-sg"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Application port (for development/debugging)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-sg"
  }
}

# Key Pair
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = var.public_key
}

# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Secrets Manager
resource "aws_iam_policy" "secrets_policy" {
  name = "${var.project_name}-secrets-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.monitor_sat_credentials.arn
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "secrets_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# Secrets Manager Secret
resource "aws_secretsmanager_secret" "monitor_sat_credentials" {
  name                    = "${var.project_name}/credentials"
  description             = "Credenciales para Monitor SAT"
  recovery_window_in_days = 0 # Para poder recrear inmediatamente en desarrollo
}

# Secret Value
resource "aws_secretsmanager_secret_version" "credentials" {
  secret_id = aws_secretsmanager_secret.monitor_sat_credentials.id
  secret_string = jsonencode({
    finkok_username = var.finkok_username
    finkok_password = var.finkok_password
    cert_content    = var.cert_content
    key_content     = var.key_content
  })
}

# User Data Script
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name  = var.project_name
    aws_region    = var.aws_region
    secret_name   = aws_secretsmanager_secret.monitor_sat_credentials.name
    domain_name   = var.domain_name
    admin_email   = var.admin_email
    github_repo   = var.github_repo
    github_branch = var.github_branch
  }))
}

# EC2 Instance
resource "aws_instance" "monitor_sat" {
  ami                    = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type          = var.instance_type
  key_name               = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.monitor_sat.id]
  subnet_id              = aws_subnet.public.id
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  user_data = local.user_data

  root_block_device {
    volume_type = "gp3"
    volume_size = var.volume_size
    encrypted   = true
  }

  tags = {
    Name = "${var.project_name}-server"
  }

  # Ensure instance is replaced if user data changes
  user_data_replace_on_change = true
}

# Elastic IP
resource "aws_eip" "monitor_sat" {
  instance = aws_instance.monitor_sat.id
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route53 Hosted Zone (optional)
resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0
  name  = var.domain_name

  tags = {
    Name = "${var.project_name}-zone"
  }
}

# Route53 Record
resource "aws_route53_record" "main" {
  count   = var.create_route53_zone ? 1 : 0
  zone_id = aws_route53_zone.main[0].zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.monitor_sat.public_ip]
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "monitor_sat" {
  name              = "/aws/ec2/${var.project_name}"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-logs"
  }
}
