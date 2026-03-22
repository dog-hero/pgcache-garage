# pgcache-garage

A workspace for PgCache experiments, labs, and tooling. This repository contains resources for exploring, testing, and integrating PgCache in various scenarios.

## What is PgCache?

PgCache is a transparent caching proxy for PostgreSQL that sits between your application and database. It automatically caches SELECT query results and uses Change Data Capture (CDC) via logical replication to keep the cache synchronized with the origin.

For the main project, see: [tempest98/pgcache](https://github.com/tempest98/pgcache)

## Repository Structure

This repository is organized into experiments and tooling:

```
pgcache-garage/
├── README.md              # This file
├── llm.txt                # Full PgCache documentation for LLM context
├── pgcache.skill.md       # PgCache skill definition for AI agents
└── experiments/           # (future) Experimental configurations and tests
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
