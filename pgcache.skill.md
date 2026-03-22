# PgCache Skill

## Description

PgCache is a transparent caching proxy for PostgreSQL that sits between your application and database. It automatically caches SELECT query results and uses Change Data Capture (CDC) via logical replication to keep the cache synchronized with the origin.

Use this skill when:
- Working with PgCache configuration, deployment, or troubleshooting
- Building integrations with PgCache
- Understanding caching behavior and invalidation patterns
- Setting up monitoring and metrics for PgCache

## Architecture

```
App → PgCache → Origin PostgreSQL
         ↓
    Cache DB (embedded PostgreSQL)
         ↑
    CDC (logical replication)
```

Key Components:
- **Proxy**: Accepts PostgreSQL connections, analyzes queries, serves cached results or forwards to origin
- **Cache DB**: Embedded PostgreSQL storing cached query results
- **CDC Worker**: Subscribes to origin's logical replication stream, invalidates/updates cache entries

## Quick Start

```bash
# Docker run
docker run -d -p 5432:5432 -p 9090:9090 pgcache/pgcache \
  --upstream postgres://user:password@your-db-host:5432/myapp

# Docker Compose
services:
  pgcache:
    image: pgcache/pgcache
    ports:
      - "5432:5432"
      - "9090:9090"
    environment:
      UPSTREAM_URL: postgres://user:password@db:5432/myapp
      NUM_WORKERS: 4
```

## Configuration Methods

Priority: CLI > TOML > Environment

| Method | Usage |
|--------|-------|
| Environment variables | `UPSTREAM_URL=postgres://...` (Docker recommended) |
| CLI arguments | `--upstream postgres://...` |
| TOML file | Mount at `/etc/pgcache/config.toml` |

### Key Configuration Options

```toml
# Minimal config
num_workers = 4
[origin]
host = "db.example.com"
port = 5432
user = "app_user"
password = "secret"
database = "myapp"

# With caching controls
cache_size = 1073741824  # 1 GB
allowed_tables = ["users", "orders"]
pinned_queries = ["SELECT * FROM config"]
pinned_tables = ["categories"]
```

### CLI Flags

| Flag | Description |
|------|-------------|
| `--upstream` | Origin database URL |
| `--num_workers` | Worker threads |
| `--cache_size` | Max cache size in bytes |
| `--allowed_tables` | Comma-separated tables to cache |
| `--pinned_queries` | Semicolon-separated queries to pin |
| `--pinned_tables` | Comma-separated tables to pin |
| `--config` | Path to TOML config file |

## Cache Behavior

### What Gets Cached

- Single-table SELECT statements
- INNER/LEFT/RIGHT JOIN with equality conditions
- WHERE clauses: `=`, `!=`, `<`, `<=`, `>`, `>=`, AND, OR, NOT
- IN/NOT IN, IS NULL, LIKE/ILIKE, BETWEEN
- GROUP BY, ORDER BY, HAVING
- Aggregate functions: COUNT, SUM, AVG, etc.
- Window functions: ROW_NUMBER, RANK, etc.
- Subqueries (correlated and uncorrelated)
- CTEs (MATERIALIZED/NOT MATERIALIZED)
- Set operations: UNION, INTERSECT, EXCEPT
- LIMIT/OFFSET (queries differ only in LIMIT share cache entry)
- Functions in SELECT and immutable functions in WHERE

### NOT Cached (Forwarded to Origin)

- INSERT, UPDATE, DELETE, DDL
- FULL JOIN, CROSS JOIN
- LATERAL subqueries
- Non-immutable functions outside SELECT
- RECURSIVE CTEs
- Locking clauses: FOR UPDATE, FOR SHARE

## Cache Invalidation

- **CDC**: Changes streamed via logical replication; cache entries updated directly or invalidated
- **Predicate subsumption**: Query result covered by existing cached query (e.g., `SELECT * FROM users WHERE id = 1` served from cached `SELECT * FROM users`)
- **Admission threshold**: Query must be seen N times (default 2) before caching (CLOCK policy)
- **Pinned queries**: Protected from eviction, auto-repopulated after CDC invalidation

## Monitoring

| Endpoint | Description |
|----------|-------------|
| `GET /metrics` | Prometheus metrics |
| `GET /healthz` | Liveness check |
| `GET /readyz` | Readiness check |
| `GET /status` | JSON cache/CDC/query status |

### Key Metrics

```promql
# Cache hit ratio
rate(pgcache_queries_cache_hit_total[5m]) /
(rate(pgcache_queries_cache_hit_total[5m]) + rate(pgcache_queries_cache_miss_total[5m]))

# CDC lag
pgcache_cdc_lag_seconds

# Query latency p95
pgcache_query_latency_seconds{quantile="0.95"}
```

## Prerequisites

- PostgreSQL 16+ origin with `wal_level = logical`
- User with REPLICATION role or superuser
- Docker for running PgCache

Enable on origin:
```sql
wal_level = logical
max_replication_slots = 10
max_wal_senders = 10
ALTER ROLE pgcache_user REPLICATION;
```

## Deployment Examples

### With replication override (PgBouncer)
```bash
docker run -d -p 5432:5432 pgcache/pgcache \
  --upstream postgres://user@pgbouncer:6432/myapp \
  --replication-host db-direct.example.com \
  --replication-port 5432
```

### With table allowlist and pinned tables
```bash
docker run -d -p 5432:5432 \
  -e UPSTREAM_URL=postgres://user@db:5432/myapp \
  -e ALLOWED_TABLES=users,orders,products \
  -e PINNED_TABLES=users,products \
  pgcache/pgcache
```

### AWS Marketplace
```bash
/opt/pgcache/bootstrap.sh --ssm-prefix /pgcache/prod \
  --workers 4 \
  --cache-size 4294967296 \
  --allowed-tables users,orders,products
```

## Limitations

- Cache fully reset on every startup (cold cache after restart)
- Single-node only (no distributed cache)
- COPY protocol not proxied
- LISTEN/NOTIFY not proxied
- WAL can accumulate if PgCache down extended period
- PostgreSQL 15 and below not supported

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cache not populating | Check `pgcache.queries.cache_miss` vs `cache_hit`; verify CDC is working via `pgcache.cdc.events_processed` |
| High CDC lag | Check `pgcache.cdc.lag_seconds`; ensure network connectivity to origin |
| Queries not cached | Check `pgcache.queries.uncacheable`; ensure query matches cacheable patterns |
| Connection issues | Verify `wal_level = logical` on origin; check user has REPLICATION role |
