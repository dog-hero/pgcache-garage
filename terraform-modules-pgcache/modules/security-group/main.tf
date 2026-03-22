resource "aws_security_group" "pgcache" {
  name        = "pgcache-${var.environment}-sg"
  description = "Security group for PgCache (ports 5432, 9090)"
  vpc_id      = var.vpc_id

  tags = merge(
    var.tags,
    { Name = "pgcache-${var.environment}-sg" }
  )
}

resource "aws_vpc_security_group_ingress_rule" "pgcache_proxy" {
  security_group_id = aws_security_group.pgcache.id
  description        = "PgCache proxy port"
  from_port          = 5432
  to_port            = 5432
  ip_protocol        = "tcp"
  cidr_ipv4          = var.allowed_cidr_blocks
}

resource "aws_vpc_security_group_ingress_rule" "pgcache_metrics" {
  security_group_id = aws_security_group.pgcache.id
  description        = "PgCache metrics port"
  from_port          = 9090
  to_port            = 9090
  ip_protocol        = "tcp"
  cidr_ipv4          = var.allowed_cidr_blocks
}

resource "aws_vpc_security_group_ingress_rule" "pgcache_ssh" {
  count = var.enable_ssh ? 1 : 0

  security_group_id = aws_security_group.pgcache.id
  description        = "SSH access"
  from_port          = 22
  to_port            = 22
  ip_protocol        = "tcp"
  cidr_ipv4          = var.ssh_allowed_cidr
}

resource "aws_vpc_security_group_egress_rule" "pgcache_all" {
  security_group_id = aws_security_group.pgcache.id
  description        = "Allow all outbound"
  ip_protocol        = "-1"
  cidr_ipv4          = "0.0.0.0/0"
}
