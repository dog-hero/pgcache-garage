output "instance_id" {
  description = "PgCache EC2 instance ID"
  value       = aws_instance.pgcache.id
}

output "instance_private_ip" {
  description = "Private IP address of PgCache instance"
  value       = aws_instance.pgcache.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of PgCache instance (if available)"
  value       = aws_instance.pgcache.public_ip
}

output "instance_availability_zone" {
  description = "Availability zone of PgCache instance"
  value       = aws_instance.pgcache.availability_zone
}
