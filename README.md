# pgcache-garage

A workspace for PgCache experiments, labs, and tooling. This repository contains resources for exploring, testing, and integrating PgCache in various scenarios.

## What is PgCache?

PgCache is a transparent caching proxy for PostgreSQL that sits between your application and database. It automatically caches SELECT query results and uses Change Data Capture (CDC) via logical replication to keep the cache synchronized with the origin.

For the main project, see: [tempest98/pgcache](https://github.com/tempest98/pgcache)

## Repository Structure

This repository is organized into experiments and tooling:

```
pgcache-garage/
├── README.md                   # This file
├── llm.txt                     # Full PgCache documentation for LLM context
├── pgcache.skill.md            # PgCache skill definition for AI agents
├── pgcache-playground/         # Web-based SQL editor and benchmarking tool
├── test-env/                   # Complete test environment with Docker Compose
├── terraform-ami/              # Direct Terraform resources (monolithic)
├── terraform-modules-pgcache/  # Reusable Terraform modules for AWS
└── experiments/                # (future) Experimental configurations and tests
```

## Projects

### llm.txt

Full PgCache documentation formatted for LLM/AI agent context. This file provides comprehensive documentation including:

- Getting started guide
- Configuration reference (TOML, CLI, Environment variables)
- Architecture and caching behavior
- What queries get cached vs forwarded to origin
- Cache invalidation via CDC
- Monitoring with Prometheus metrics
- AWS Marketplace deployment
- Compatibility notes
- Changelog (v0.4.x)

**Use case**: Provide AI assistants with complete PgCache knowledge for code generation, troubleshooting, or integration work.

### pgcache.skill.md

PgCache skill definition following the standard skill format. This is a condensed reference for AI agents and code assistants, containing:

- Quick start examples
- Configuration options
- Cache behavior summary
- Monitoring endpoints
- Deployment examples
- Troubleshooting guide

**Use case**: Load as a skill when working with PgCache-related tasks.

### pgcache-playground

Web-based SQL editor and benchmarking tool to compare direct PostgreSQL queries against PgCache. Built with Next.js.

Features:
- Dual connection to PostgreSQL and PgCache simultaneously
- Schema explorer for browsing tables and columns
- SQL editor with parameterized query support
- Benchmark both databases or select one specifically
- Real-time performance visualization with charts
- Statistical summary (Mean, Median, Min, Max, StdDev)

**Location**: [pgcache-playground/](pgcache-playground/)

**Use case**: Test and benchmark PgCache performance against your PostgreSQL origin.

### test-env

Complete test environment with Docker Compose. Includes PostgreSQL 16 origin with 1M+ rows of e-commerce SaaS data, PgCache proxy, Prometheus, and Grafana dashboard.

Stack:
- **PostgreSQL 16** — Origin database with logical replication
- **PgCache** (`pgcache/pgcache:0.4.5-amd64`) — Caching proxy
- **Prometheus** — Metrics collection
- **Grafana** — Auto-provisioned dashboard

Quick start:
```bash
cd test-env
docker compose up -d
```

Features:
- E-commerce SaaS schema (tenants, products, orders, customers, subscriptions)
- ~1 million rows of sample data
- Pre-built Grafana dashboard for cache monitoring
- Prometheus scrape config for PgCache metrics

**Location**: [test-env/](test-env/)

**Use case**: Fully functional local PgCache environment for testing and monitoring.

### terraform-modules-pgcache

Reusable Terraform modules for provisioning PgCache on AWS. Includes IAM, security group, SSM parameters, and EC2 instance modules.

Modules:
- **iam** — IAM role with SSM Parameter Store read access
- **security-group** — Security group for ports 5432, 9090
- **ssm-parameters** — SSM SecureString for upstream URL and TLS certs
- **ec2-instance** — EC2 instance with PgCache bootstrap

Usage:
```hcl
module "pgcache" {
  source  = "github.com/tempest98/terraform-modules-pgcache//modules/ec2-instance?ref=v0.1.0"
  environment  = "prod"
  upstream_url = "postgres://user:pass@host:5432/db?sslmode=require"
  vpc_id       = "vpc-12345"
  subnet_id    = "subnet-12345"
}
```

**Location**: [terraform-modules-pgcache/](terraform-modules-pgcache/)

**Use case**: Infrastructure as Code for deploying PgCache on AWS.

### terraform-ami

Monolithic Terraform configuration for provisioning PgCache on AWS using direct AWS provider resources. No modules - all resources defined directly.

Resources created:
- IAM role with SSM read permissions
- Security group (ports 5432, 9090, 22)
- SSM SecureString for upstream URL
- EC2 instance with bootstrap

```bash
terraform init
terraform plan -var-file="prod.tfvars"
terraform apply -var-file="prod.tfvars"
```

**Location**: [terraform-ami/](terraform-ami/)

**Use case**: Quick, self-contained Terraform setup without external module dependencies.

## Quick Start

### Run PgCache with Docker

```bash
docker run -d -p 5432:5432 -p 9090:9090 pgcache/pgcache \
  --upstream postgres://user:password@your-db-host:5432/myapp
```

### Prerequisites

- PostgreSQL 16+ as origin database
- Logical replication enabled (`wal_level = logical`)
- Database user with REPLICATION role or superuser

On your origin database:

```sql
ALTER ROLE pgcache_user REPLICATION;
```

### Verify Caching is Active

```bash
curl http://localhost:9090/metrics | grep pgcache_queries
```

Look for `pgcache_queries_cache_hit` and `pgcache_queries_cache_miss` counters.

## Key Features

| Feature | Description |
|---------|-------------|
| Transparent proxy | Application connects to PgCache like regular PostgreSQL |
| Automatic caching | SELECT queries analyzed and cached automatically |
| CDC sync | Logical replication keeps cache fresh |
| Table allowlist | Restrict caching to specific tables |
| Pinned queries | Pre-cache and protect critical queries |
| Predicate subsumption | Serve subsets from cached supersets |
| Prometheus metrics | Full observability via `/metrics` endpoint |

## Architecture

```
┌──────────┐    queries     ┌──────────┐    uncacheable    ┌──────────┐
│          │ ─────────────▶ │          │ ────────────────▶ │          │
│   App    │                │ pgcache  │                   │PostgreSQL│
│          │ ◀───────────── │          │ ◀──────────────── │ (origin) │
└──────────┘   responses    └────┬──┬──┘    responses      └─────┬────┘
                                 │  │                            │
                           cache │  │    CDC stream               │
                           read/ │  │   (logical replication)    │
                           write │  └────────────────────────────┘
                                 ▼
                            ┌──────────┐
                            │  Cache   │
                            │   DB     │
                            └──────────┘
```

## Monitoring

PgCache exposes Prometheus-compatible metrics:

| Endpoint | Description |
|----------|-------------|
| `GET /metrics` | Prometheus metrics in text format |
| `GET /healthz` | Liveness check |
| `GET /readyz` | Readiness check |
| `GET /status` | JSON with cache, CDC, and query status |

Example Prometheus queries:

```promql
# Cache hit ratio
rate(pgcache_queries_cache_hit_total[5m]) /
(rate(pgcache_queries_cache_hit_total[5m]) + rate(pgcache_queries_cache_miss_total[5m]))

# CDC lag
pgcache_cdc_lag_seconds

# Query latency p95
pgcache_query_latency_seconds{quantile="0.95"}
```

## Resources

- [PgCache GitHub](https://github.com/tempest98/pgcache)
- [PgCache Documentation](https://www.pgcache.com/docs/)
- [AWS Marketplace](https://www.pgcache.com/docs/aws-marketplace/)

## License

MIT
