output "security_group_id" {
  description = "Security group ID for PgCache"
  value       = aws_security_group.pgcache.id
}
