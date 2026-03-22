data "aws_ssm_parameter" "pgcache_ami" {
  name = "/aws/service/canonical/ubuntu/server/jammy/stable/current/amd64/hvm/ebs-gp3/amd64-ubuntu-core-ssd-gp3"
}

resource "aws_instance" "pgcache" {
  ami           = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.pgcache_ami.value
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  iam_instance_profile = var.iam_instance_profile

  vpc_security_group_ids = [var.security_group_id]

  user_data = templatefile("${path.module}/user_data.sh.tpl", {
    ssm_prefix = var.ssm_prefix
  })

  root_block_device {
    volume_type = "gp3"
    volume_size = 50
  }

  tags = merge(
    var.tags,
    {
      Name = "pgcache-${var.environment}"
      Environment = var.environment
    }
  )
}
