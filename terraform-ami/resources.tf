data "aws_caller_identity" "current" {}

locals {
  name_prefix = "pgcache-${var.environment}"
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM Role for PgCache EC2
data "aws_iam_policy_document" "pgcache_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "pgcache" {
  name               = "${local.name_prefix}-role"
  assume_role_policy = data.aws_iam_policy_document.pgcache_assume_role.json
}

resource "aws_iam_role_policy" "pgcache_ssm_read" {
  name = "${local.name_prefix}-ssm-read"
  role = aws_iam_role.pgcache.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["ssm:GetParameter", "ssm:GetParameters"]
        Resource = "arn:aws:ssm:*:*:parameter/${trimprefix(var.ssm_prefix, "/")}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "pgcache" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.pgcache.name
}

# Security Group
resource "aws_security_group" "pgcache" {
  name        = "${local.name_prefix}-sg"
  description = "PgCache security group (ports 5432, 9090)"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, { Name = "${local.name_prefix}-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "pgcache_proxy" {
  security_group_id = aws_security_group.pgcache.id
  description       = "PgCache proxy port"
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_cidr_blocks
}

resource "aws_vpc_security_group_ingress_rule" "pgcache_metrics" {
  security_group_id = aws_security_group.pgcache.id
  description       = "PgCache metrics port"
  from_port         = 9090
  to_port           = 9090
  ip_protocol       = "tcp"
  cidr_ipv4         = var.allowed_cidr_blocks
}

resource "aws_vpc_security_group_ingress_rule" "pgcache_ssh" {
  count = var.enable_ssh ? 1 : 0

  security_group_id = aws_security_group.pgcache.id
  description       = "SSH access"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.ssh_allowed_cidr
}

resource "aws_vpc_security_group_egress_rule" "pgcache_all" {
  security_group_id = aws_security_group.pgcache.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# SSM Parameters
resource "aws_ssm_parameter" "upstream_url" {
  name        = "${var.ssm_prefix}/upstream-url"
  description = "PgCache upstream database connection URL"
  type        = "SecureString"
  value       = var.upstream_url

  tags = merge(local.tags, { Name = "${var.ssm_prefix}/upstream-url" })
}

# EC2 Instance
data "aws_ssm_parameter" "pgcache_ami" {
  name = "/aws/service/canonical/ubuntu/server/jammy/stable/current/amd64/hvm/ebs-gp3/amd64-ubuntu-core-ssd-gp3"
}

resource "aws_instance" "pgcache" {
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.pgcache_ami.value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  iam_instance_profile = aws_iam_instance_profile.pgcache.name
  vpc_security_group_ids = [aws_security_group.pgcache.id]

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    ssm_prefix = var.ssm_prefix
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}" })
}
