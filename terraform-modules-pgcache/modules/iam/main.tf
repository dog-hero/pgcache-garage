data "aws_iam_policy_document" "pgcache_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "pgcache" {
  name               = "pgcache-${var.environment}-role"
  assume_role_policy = data.aws_iam_policy_document.pgcache_assume_role.json
  description        = "IAM role for PgCache EC2 instance"
}

resource "aws_iam_role_policy" "pgcache_ssm_read" {
  name = "pgcache-${var.environment}-ssm-read"
  role = aws_iam_role.pgcache.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.ssm_prefix}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "pgcache" {
  name = "pgcache-${var.environment}-profile"
  role = aws_iam_role.pgcache.name
}
