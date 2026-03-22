variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ssm_prefix" {
  description = "SSM Parameter Store path prefix"
  type        = string
  default     = "/pgcache"
}
