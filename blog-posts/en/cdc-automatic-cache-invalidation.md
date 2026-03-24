# Zero-Downtime Cache Warming: How PgCache Handles CDC and You Don't Have To

One of the trickiest parts of caching is keeping the cache fresh. With traditional approaches, you're either fighting with TTLs or manually invalidating entries. PgCache takes a different path — it listens to your database changes and updates the cache automatically. Let's talk about how that works.

## The Cache Invalidation Problem

Most caches have a fundamental tension: you want data fresh, but checking freshness is expensive. So you end up with:

- **TTL-based expiration**: Simple, but data can be stale until the TTL hits
- **Manual invalidation**: Correct, but error-prone and requires code changes
- **Write-through**: Fast writes become slow writes
- **Write-behind**: Need to track every mutation

None of these are great. They either accept staleness or add complexity.

## PgCache's CDC Approach

PgCache connects to your PostgreSQL origin using logical replication. When data changes in the origin (INSERT, UPDATE, DELETE, TRUNCATE), those changes are streamed to PgCache automatically.

Here's the flow:

1. PgCache creates a publication and replication slot on your origin database
2. Changes are captured as they happen via the WAL
3. PgCache identifies which cached queries are affected
4. Affected entries are updated directly or invalidated for lazy refresh

The result: your cache stays synchronized with your database without any code changes or manual intervention.

## What Gets Updated

For simple single-table pinned queries like:

```sql
SELECT * FROM categories
```

PgCache updates the cache in place when rows change. No invalidation needed. The cache entry is always fresh.

For more complex queries, PgCache invalidates the affected entries. The next time the query runs, it gets fresh data from the origin.

## Monitoring the Sync

Since CDC is a pipeline, PgCache exposes metrics to monitor health:

```
pgcache_cdc_lag_seconds       # How far behind is the cache
pgcache_cdc_events_processed  # Total events processed
pgcache_cache_invalidations   # How many entries were invalidated
```

If you're seeing lag grow, you know something's up before users start complaining.

## Why This Beats Manual Invalidation

With manual invalidation, you're probably doing something like:

```python
def update_user(user_id, data):
    db.update(user_id, data)
    cache.delete(f"user:{user_id}")
    cache.delete("users:list")  # Hope you don't forget this one
```

Every code path that modifies data needs to know about every cache entry that depends on it. It's fragile.

With PgCache, you just write to the database:

```python
def update_user(user_id, data):
    db.update(user_id, data)
    # That's it. PgCache handles the rest.
```

## The Real Benefit

CDC-based caching means your application code stays simple. You don't need cache-aware ORM hooks or service layer logic to keep the cache valid. The infrastructure handles it.

If you're tired of cache invalidation bugs, or if you've been avoiding caching because keeping it in sync feels like a maintenance burden, PgCache might be what you're looking for.

---

*Check out the docs at pgcache.com to see all supported query patterns and get started in minutes.*
