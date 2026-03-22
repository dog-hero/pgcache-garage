output "ssm_prefix" {
  description = "SSM Parameter Store path prefix"
  value       = var.ssm_prefix
}

output "upstream_url_ssm_path" {
  description = "SSM path for upstream URL"
  value       = "${var.ssm_prefix}/upstream-url"
}
