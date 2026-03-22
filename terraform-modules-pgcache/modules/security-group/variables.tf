variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID to deploy security group"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access PgCache (ports 5432, 9090)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_ssh" {
  description = "Enable SSH access (port 22)"
  type        = bool
  default     = false
}

variable "ssh_allowed_cidr" {
  description = "CIDR block allowed for SSH access"
  type        = string
  default     = "10.0.0.0/16"
}

variable "tags" {
  description = "Tags to apply to security group"
  type        = map(string)
  default     = {}
}
