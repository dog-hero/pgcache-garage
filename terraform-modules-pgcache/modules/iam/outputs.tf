output "instance_profile_name" {
  description = "IAM instance profile name for PgCache"
  value       = aws_iam_instance_profile.pgcache.name
}

output "iam_role_arn" {
  description = "IAM role ARN for PgCache"
  value       = aws_iam_role.pgcache.arn
}
