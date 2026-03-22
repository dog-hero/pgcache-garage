variable "aws_region" {
  description = "AWS region to deploy PgCache"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "upstream_url" {
  description = "Origin database connection URL"
  type        = string
  sensitive   = true
}

variable "ssm_prefix" {
  description = "SSM Parameter Store path prefix"
  type        = string
  default     = "/pgcache"
}

variable "vpc_id" {
  description = "VPC ID to deploy PgCache"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for EC2 instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6g.large"
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access PgCache"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_ssh" {
  description = "Enable SSH access (port 22)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "CIDR block for SSH access"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ami_id" {
  description = "AMI ID (defaults to Ubuntu LTS if empty)"
  type        = string
  default     = ""
}
