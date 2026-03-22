resource "aws_ssm_parameter" "upstream_url" {
  name        = "${var.ssm_prefix}/upstream-url"
  description = "PgCache upstream database connection URL"
  type        = "SecureString"
  value       = var.upstream_url

  tags = merge(
    var.tags,
    { Name = "${var.ssm_prefix}/upstream-url" }
  )
}

resource "aws_ssm_parameter" "tls_cert" {
  count = var.tls_cert != "" ? 1 : 0

  name        = "${var.ssm_prefix}/tls-cert"
  description = "PgCache TLS certificate (PEM)"
  type        = "SecureString"
  value       = var.tls_cert

  tags = merge(
    var.tags,
    { Name = "${var.ssm_prefix}/tls-cert" }
  )
}

resource "aws_ssm_parameter" "tls_key" {
  count = var.tls_key != "" ? 1 : 0

  name        = "${var.ssm_prefix}/tls-key"
  description = "PgCache TLS private key (PEM)"
  type        = "SecureString"
  value       = var.tls_key

  tags = merge(
    var.tags,
    { Name = "${var.ssm_prefix}/tls-key" }
  )
}
