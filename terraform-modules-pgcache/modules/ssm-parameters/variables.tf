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

variable "tls_cert" {
  description = "TLS certificate (PEM format, optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tls_key" {
  description = "TLS private key (PEM format, optional)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to SSM parameters"
  type        = map(string)
  default     = {}
}
