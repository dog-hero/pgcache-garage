variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (default: m6g.xlarge)"
  type        = string
  default     = "m6g.xlarge"
}

variable "ami_id" {
  description = "AMI ID to use (defaults to Ubuntu LTS). Set to PgCache AMI for production."
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID to deploy PgCache instance"
  type        = string
}

variable "iam_instance_profile" {
  description = "IAM instance profile name for PgCache"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID for PgCache"
  type        = string
}

variable "ssm_prefix" {
  description = "SSM Parameter Store path prefix"
  type        = string
  default     = "/pgcache"
}

variable "tags" {
  description = "Tags to apply to EC2 instance"
  type        = map(string)
  default     = {}
}
