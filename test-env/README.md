# PgCache Test Environment

A complete, self-contained test environment for PgCache with sample e-commerce SaaS data.

## Stack

| Service | Port | Description |
|---------|------|-------------|
| PostgreSQL Origin | 5433 | Source database with 1M+ rows |
| PgCache | 5432 | Caching proxy |
| Prometheus | 9091 | Metrics collection |
| Grafana | 3000 | Visualization dashboard |

## Quick Start

```bash
cd test-env
docker compose up -d
```

Wait for services to be ready (especially the data generation):

```bash
# Watch logs for data generation completion
docker compose logs -f generate_data

# Check PgCache is healthy
curl http://localhost:9090/healthz
```

## Services

### PgCache Proxy
- **Port**: 5432 (mapped to localhost)
- **Metrics**: http://localhost:9090/metrics
- **Health**: http://localhost:9090/healthz
- **Status**: http://localhost:9090/status

Connect your app:
```bash
psql postgres://store_user:store_secret@localhost:5432/store
```

### Grafana Dashboard
- **URL**: http://localhost:3000
- **Username**: admin
- **Password**: admin
- **Dashboard**: PgCache Overview (auto-provisioned)

### Prometheus
- **URL**: http://localhost:9091

## Sample Database Schema

E-commerce SaaS (Shopify-style multi-tenant):

```
tenants (stores/merchants)
├── categories
├── products
├── customers
├── orders
│   └── order_items
├── inventory
├── subscriptions
├── usage_events
└── invoices
```

## Testing Queries

Connect to PgCache and run these queries:

```sql
-- Check cache is working (run twice - second should be faster)
SELECT * FROM products WHERE tenant_id = 1 LIMIT 100;

-- Aggregate query (good for cache testing)
SELECT c.name, COUNT(p.id) as product_count
FROM categories c
LEFT JOIN products p ON c.id = p.category_id
WHERE c.tenant_id = 1
GROUP BY c.id;

-- Join query
SELECT o.id, o.total, c.email
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE o.tenant_id = 1
ORDER BY o.created_at DESC
LIMIT 50;
```

## Monitoring

### Verify Metrics

```bash
curl http://localhost:9090/metrics | grep pgcache
```

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

## Connecting pgcache-playground

Update `pgcache-playground/.env`:

```env
POSTGRES_URL=localhost:5433
PGCACHE_URL=localhost:5432
DB_USER=store_user
DB_PASSWORD=store_secret
DB_NAME=store
```

## Data Generation

The environment generates ~1M rows:

- 10,000 customers
- 500 products
- 500,000 orders
- 1.5M order items
- 500,000 usage events
- 50,000 invoices

Generation runs automatically on `docker compose up`.

## Troubleshooting

### PgCache not starting
```bash
# Check PostgreSQL is ready
docker compose logs postgres_origin

# Verify replication settings
docker compose exec postgres_origin psql -U store_user -d store -c "SHOW wal_level;"
```

### Cache not populating
```bash
# Check metrics
curl http://localhost:9090/metrics | grep pgcache_queries

# Check CDC is working
curl http://localhost:9090/status | jq '.cdc'
```

### Grafana dashboards not loading
```bash
# Check datasources
docker compose logs grafana | grep datasources
```

## Cleanup

```bash
docker compose down -v  # Removes volumes
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `UPSTREAM_URL` | postgres://... | Origin database URL |
| `NUM_WORKERS` | 4 | Worker threads |
| `CACHE_SIZE` | 1073741824 | Cache size (1GB) |
| `CACHE_POLICY` | clock | Eviction policy |
| `ADMISSION_THRESHOLD` | 2 | Queries before caching |
