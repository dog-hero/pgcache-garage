output "instance_id" {
  description = "PgCache EC2 instance ID"
  value       = aws_instance.pgcache.id
}

output "instance_private_ip" {
  description = "Private IP address"
  value       = aws_instance.pgcache.private_ip
}

output "instance_public_ip" {
  description = "Public IP address"
  value       = aws_instance.pgcache.public_ip
}

output "security_group_id" {
  description = "Security group ID"
  value       = aws_security_group.pgcache.id
}

output "iam_role_arn" {
  description = "IAM role ARN"
  value       = aws_iam_role.pgcache.arn
}
