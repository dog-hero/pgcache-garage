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

module "pgcache_iam" {
  source = "../../modules/iam"

  environment  = var.environment
  ssm_prefix   = var.ssm_prefix
}

module "pgcache_security_group" {
  source = "../../modules/security-group"

  environment         = var.environment
  vpc_id              = var.vpc_id
  allowed_cidr_blocks = var.allowed_cidr_blocks
  enable_ssh          = var.enable_ssh
  ssh_allowed_cidr   = var.ssh_allowed_cidr
}

module "pgcache_ssm_parameters" {
  source = "../../modules/ssm-parameters"

  ssm_prefix   = var.ssm_prefix
  upstream_url = var.upstream_url
}

module "pgcache_instance" {
  source = "../../modules/ec2-instance"

  environment            = var.environment
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = module.pgcache_iam.instance_profile_name
  security_group_id       = module.pgcache_security_group.security_group_id
  ssm_prefix             = var.ssm_prefix
}
