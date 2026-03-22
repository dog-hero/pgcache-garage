variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ssm_prefix" {
  description = "SSM Parameter Store path prefix"
  type        = string
  default     = "/pgcache"
}

variable "upstream_url" {
  description = "Origin database connection URL"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access PgCache"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "m6g.large"
}

variable "enable_ssh" {
  description = "Enable SSH access"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "CIDR for SSH access"
  type        = string
  default     = "10.0.0.0/16"
}
