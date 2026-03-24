# Postgres as a Cache? There's a Better Way

If you've been using PostgreSQL for a while, you've probably heard the advice: "Just use a cache layer in front of your database." And maybe you've looked at Redis, Memcached, or other caching solutions. But there's overhead in managing another service. What if your database could handle caching natively?

That's what PgCache is built for.

## The Setup

Getting PgCache running takes about 2 minutes:

```bash
docker run -d -p 5432:5432 -p 9090:9090 pgcache/pgcache \
  --upstream postgres://user:password@your-db:5432/myapp
```

Point your application at port 5432 instead of your database directly. That's it. Queries start going through the cache automatically.

## What PgCache Caches

PgCache is smart about what it caches. It analyzes your SQL and only caches queries where it can guarantee correct results. Things like:

- Simple SELECTs: `SELECT * FROM products WHERE active = true`
- JOINs: `SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id`
- Aggregations: `SELECT COUNT(*), SUM(amount) FROM orders GROUP BY status`
- CTEs and subqueries
- Window functions

And it keeps the cache fresh using PostgreSQL's logical replication. When data in your database changes, the cache updates automatically.

## What Doesn't Get Cached

Queries that modify data (INSERT, UPDATE, DELETE) go directly to the origin. So do queries with volatile functions, locking clauses, or views. PgCache is conservative — if it can't guarantee correctness, it doesn't cache.

## Monitoring

Prometheus metrics come built-in on port 9090:

```bash
curl http://localhost:9090/metrics | grep pgcache
```

Key metrics to watch:
- `pgcache_queries_cache_hit` / `pgcache_queries_cache_miss` — your hit ratio
- `pgcache_cdc_lag_seconds` — how fresh your cache is
- `pgcache_cache_size_bytes` — cache utilization

## Does It Work With My ORM?

Yes. PgCache speaks the PostgreSQL wire protocol. Whether you're using psycopg2, SQLAlchemy, Prisma, Hibernate, or anything else, it just works. No client library changes needed.

## Should You Use It?

PgCache shines when:
- You have read-heavy workloads
- Your queries follow predictable patterns
- You want to reduce load on your origin database
- You don't want to manage separate caching infrastructure

It's not a silver bullet — if you need distributed caching across multiple application instances, or if your use case requires something outside PostgreSQL's query model, you might still want Redis or similar.

But if you're already running PostgreSQL and want to squeeze more performance out of your existing setup, PgCache is worth a look.

---

*Docs and more at pgcache.com. GitHub at github.com/tempest98/pgcache.*
