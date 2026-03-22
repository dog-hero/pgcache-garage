# PgCache Terraform Modules

Reusable Terraform modules for provisioning PgCache on AWS.

## Modules

| Module | Description |
|--------|-------------|
| [iam](./modules/iam) | IAM role with SSM Parameter Store read access |
| [security-group](./modules/security-group) | Security group for ports 5432, 9090 |
| [ssm-parameters](./modules/ssm-parameters) | SSM SecureString parameters for configuration |
| [ec2-instance](./modules/ec2-instance) | EC2 instance with PgCache bootstrap |

## Quick Start

```hcl
module "pgcache" {
  source = "github.com/tempest98/terraform-modules-pgcache//modules/ec2-instance?ref=v0.1.0"

  environment  = "prod"
  upstream_url = "postgres://user:pass@host:5432/db?sslmode=require"
  vpc_id       = "vpc-12345"
  subnet_id    = "subnet-12345"
}
```

## Full Example

See [examples/simple](./examples/simple/) for a complete setup:

```bash
cd examples/simple
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC                                  │
│  ┌─────────────────────────────────────────────────────┐     │
│  │              PgCache EC2 Instance                   │     │
│  │  ┌─────────────┐    ┌─────────────┐                │     │
│  │  │ pgcache     │    │ PostgreSQL  │                │     │
│  │  │ proxy       │───▶│ cache DB    │                │     │
│  │  │ (port 5432) │    │ (port 5433) │                │     │
│  │  └─────────────┘    └─────────────┘                │     │
│  └─────────────────────────────┬───────────────────────┘     │
│                                │                              │
│                    user_data bootstrap.sh                      │
│                                │                              │
│                    SSM Parameter Store                         │
│                    /pgcache/{env}/upstream-url                │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │   Origin PostgreSQL   │
                    │   (wal_level=logical) │
                    └───────────────────────┘
```

## Prerequisites

- PostgreSQL 16+ origin with `wal_level = logical`
- VPC with subnet for EC2 instance
- AWS credentials configured

## Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 instance ID |
| `instance_private_ip` | Private IP address |
| `instance_public_ip` | Public IP address |
| `instance_availability_zone` | Availability zone |

## Requirements

- Terraform >= 1.0
- AWS Provider >= 5.0

## License

MIT
