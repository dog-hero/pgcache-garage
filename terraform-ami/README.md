# PgCache AMI - Terraform

Terraform configuration for provisioning PgCache on AWS using direct resources.

## Structure

```
terraform-ami/
├── main.tf           # Provider configuration
├── variables.tf      # Input variables
├── resources.tf      # AWS resources (IAM, SG, SSM, EC2)
├── outputs.tf        # Output values
├── user_data.sh.tpl  # EC2 bootstrap template
├── dev.tfvars        # Development variables
├── prod.tfvars       # Production variables
└── .gitignore
```

## Resources Created

- **IAM Role** — with SSM Parameter Store read access
- **IAM Instance Profile** — for EC2
- **Security Group** — ports 5432 (proxy), 9090 (metrics), 22 (SSH if enabled)
- **SSM Parameter** — SecureString for upstream URL
- **EC2 Instance** — Ubuntu LTS with PgCache bootstrap

## Usage

```bash
# Initialize
terraform init

# Plan with dev vars
terraform plan -var-file="dev.tfvars"

# Apply
terraform apply -var-file="dev.tfvars"
```

## Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `aws_region` | AWS region | `us-east-1` |
| `environment` | Environment name | `dev` |
| `upstream_url` | Database connection URL | — |
| `vpc_id` | VPC ID | — |
| `subnet_id` | Subnet ID | — |
| `instance_type` | EC2 instance type | `m6g.large` |
| `allowed_cidr_blocks` | CIDR for access | `10.0.0.0/16` |
| `enable_ssh` | Enable SSH (port 22) | `false` |

## Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 instance ID |
| `instance_private_ip` | Private IP |
| `instance_public_ip` | Public IP |
| `security_group_id` | Security group ID |
| `iam_role_arn` | IAM role ARN |
