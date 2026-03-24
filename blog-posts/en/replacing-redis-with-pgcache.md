# From UNLOGGED Tables to PgCache: The Definitive Guide to PostgreSQL Caching

You've probably seen the posts: "I replaced Redis with PostgreSQL using UNLOGGED tables." It's been circulating for years. The logic is sound: since UNLOGGED tables don't write to the WAL, they're faster for caching operations. You implement it, it works great in dev, and then... boom.

I'm going to show you exactly how this pattern works, why it seems like a good idea, and why PgCache is a better solution — for real.

## How the UNLOGGED Tables Pattern Works

The idea behind using PostgreSQL as a cache with UNLOGGED is elegant in its simplicity. Since the table doesn't write to the Write-Ahead Log, you get performance without replication overhead.

### The Typical Implementation

The code you see around the web usually looks like this:

```sql
-- Create the cache table
CREATE UNLOGGED TABLE cache (
    cache_key TEXT PRIMARY KEY,
    cache_value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    accessed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for fast lookups
CREATE INDEX idx_cache_accessed ON cache (accessed_at);
```

```python
# Python example with psycopg2
import psycopg2
import json
from datetime import datetime

def cache_get(conn, key):
    """Get from cache and update accessed_at"""
    with conn.cursor() as cur:
        cur.execute("""
            UPDATE cache 
            SET accessed_at = NOW() 
            WHERE cache_key = %s 
            RETURNING cache_value
        """, (key,))
        result = cur.fetchone()
        return json.loads(result[0]) if result else None

def cache_set(conn, key, value, ttl_seconds=300):
    """Store in cache with manual TTL"""
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cache (cache_key, cache_value, created_at, accessed_at)
            VALUES (%s, %s, NOW(), NOW())
            ON CONFLICT (cache_key) 
            DO UPDATE SET cache_value = EXCLUDED.cache_value, accessed_at = NOW()
        """, (key, json.dumps(value)))

def cache_delete(conn, key):
    """Remove from cache"""
    with conn.cursor() as cur:
        cur.execute("DELETE FROM cache WHERE cache_key = %s", (key,))

def cleanup_expired(conn, ttl_seconds=300):
    """Clean expired entries - needs to run via cron or background worker"""
    with conn.cursor() as cur:
        cur.execute("""
            DELETE FROM cache 
            WHERE accessed_at < NOW() - INTERVAL '%s seconds'
        """, (ttl_seconds,))
```

### The "Optimized" Version Everyone Uses

When the blog post starts scaling, you see this kind of thing:

```python
# More "sophisticated" - cache layer with decorators
import functools
import json
import psycopg2

class PostgresCache:
    def __init__(self, conn_string, ttl=300):
        self.conn_string = conn_string
        self.ttl = ttl
        self._conn = None
    
    @property
    def conn(self):
        if not self._conn or self._conn.closed:
            self._conn = psycopg2.connect(self.conn_string)
        return self._conn
    
    def get(self, key):
        cur = self.conn.cursor()
        cur.execute("""
            UPDATE cache SET accessed_at = NOW() 
            WHERE cache_key = %s 
            AND accessed_at > NOW() - INTERVAL '%s seconds'
            RETURNING cache_value
        """, (key, self.ttl))
        result = cur.fetchone()
        if result:
            return json.loads(result[0])
        
        # Try to restore from "expired" cache if no hit in warm cache
        cur.execute("SELECT cache_value FROM cache WHERE cache_key = %s", (key,))
        result = cur.fetchone()
        return json.loads(result[0]) if result else None
    
    def set(self, key, value):
        cur = self.conn.cursor()
        cur.execute("""
            INSERT INTO cache (cache_key, cache_value) 
            VALUES (%s, %s)
            ON CONFLICT (cache_key) 
            DO UPDATE SET cache_value = EXCLUDED.cache_value, accessed_at = NOW()
        """, (key, json.dumps(value)))
        self.conn.commit()
    
    def invalidate(self, key):
        self.delete(key)
    
    def delete(self, key):
        cur = self.conn.cursor()
        cur.execute("DELETE FROM cache WHERE cache_key = %s", (key,))
        self.conn.commit()
    
    def clear_pattern(self, pattern):
        """Remove all keys matching a pattern - VERY SLOW IN PRACTICE"""
        cur = self.conn.cursor()
        cur.execute("DELETE FROM cache WHERE cache_key LIKE %s", (pattern.replace('%', '%%'),))
        self.conn.commit()
```

## The Real Problem: What Happens When PostgreSQL Restarts

Now the part the pretty blog posts don't tell you. Let me show you exactly what happens.

### What The Documentation Says

Straight from the official PostgreSQL docs:

> UNLOGGED tables are not crash-safe: the data is not written to the write-ahead log. Your data is lost in case of a crash or unclean shutdown. The table is automatically truncated after a crash or unclean shutdown.

And also:

> UNLOGGED tables are not replicated by streaming replication or logical replication.

Translation: if PostgreSQL restarts for any reason — crash, server reboot, maintenance — **your UNLOGGED table is automatically truncated**. This isn't a bug, it's the expected behavior.

### Simulating the Problem

Let's simulate what happens:

```bash
# Terminal 1: your app running with warmed cache
$ psql "postgres://app:secret@localhost:5432/myapp"
myapp=# SELECT COUNT(*) FROM cache;
 count
-------
 15234
(1 row)

myapp=# SELECT cache_key FROM cache LIMIT 5;
           cache_key
---------------------------
 user:42:profile
 user:42:permissions
 product:123:details
 session:abc123
 dashboard:stats
(5 rows)

# Terminal 2: someone restarts PostgreSQL
$ sudo systemctl restart postgresql

# Terminal 1: (connection drops, you reconnect)
myapp=# SELECT COUNT(*) FROM cache;
 count
-------
 0
(1 row)
```

Yes, that's right. All 15,234 rows are gone. Now imagine this happening in production at 2 PM on a Tuesday.

### The "Typical" Lifecycle of an Application Using UNLOGGED

It goes something like this:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Application in Production                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Initial deploy: "I'll use UNLOGGED tables, this is genius!" │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Cache warms up: millions of reads/s, latency drops 50ms→2ms  │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. WHOOPS! DB was restarted. Cache is gone.                     │
│    - Latency spikes back up                                      │
│    - Origin starts bleeding                                      │
│    - P95/P99 latency goes through the roof                       │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Time to "fix it": implement cache warming in the app         │
│    - Add warming logic                                           │
│    - More code, more complexity                                  │
│    - More failure points                                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Back to step 3...                                            │
└─────────────────────────────────────────────────────────────────┘
```

## The "Solutions" The World Creates (And Why They're Hacks)

When the problem starts showing up, the PostgreSQL community invents increasingly elaborate solutions. All of them work around the real problem.

### Solution 1: Application-Level Cache Warming

The most common attempt. You add logic to warm the cache when the application starts or when it detects the cache is empty.

```python
class CacheWarmer:
    def __init__(self, db_conn, cache):
        self.db = db_conn
        self.cache = cache
    
    def warm_from_database(self):
        """Run heavy queries on origin and populate cache"""
        print("Warming cache...")
        
        # "Hot" queries you know are important
        queries_to_warm = [
            ("categories", "SELECT * FROM categories ORDER BY name"),
            ("active_products", "SELECT * FROM products WHERE active = true LIMIT 100"),
            ("top_users", """
                SELECT u.id, u.name, COUNT(o.id) as order_count
                FROM users u
                LEFT JOIN orders o ON u.id = o.user_id
                WHERE u.created_at > NOW() - INTERVAL '30 days'
                GROUP BY u.id, u.name
                ORDER BY order_count DESC
                LIMIT 50
            """),
            # ... you need to add EVERY query you want cached
            # And remember to keep this list updated
        ]
        
        for name, query in queries_to_warm:
            with self.db.cursor() as cur:
                cur.execute(query)
                results = cur.fetchall()
                
                # Serialize and store
                self.cache.set(name, {
                    'data': results,
                    'queried_at': datetime.now().isoformat()
                })
        
        print(f"Cache warmed with {len(queries_to_warm)} queries")
    
    def is_cache_empty(self):
        """Check if cache is empty"""
        with self.db.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM cache")
            return cur.fetchone()[0] == 0
    
    def warm_if_needed(self):
        """Check and warm if needed"""
        if self.is_cache_empty():
            self.warm_from_database()
```

**Problems:**
- You need to know all queries you want cached upfront
- Dynamic queries? Forget it. You need a specific query builder.
- If a table schema changes, your warming may break silently
- Warming time can be minutes for large databases
- You're essentially re-implementing a cache by hand

### Solution 2: Checkpoint Script Via Cron

You detect if the database restarted and run warming automatically:

```bash
#!/bin/bash
# check_cache.sh - run via cron every 5 minutes

# Check if cache has data
CACHE_COUNT=$(psql -t -c "SELECT COUNT(*) FROM cache" $DATABASE_URL)

if [ "$CACHE_COUNT" -eq 0 ]; then
    echo "$(date): Cache empty, triggering warming..."
    curl -X POST http://your-app.internal/api/cache/warm
else
    echo "$(date): Cache OK ($CACHE_COUNT entries)"
fi
```

```python
# On the application side - warming endpoint
@app.route('/api/cache/warm', methods=['POST'])
def warm_cache():
    if not request.headers.get('X-Internal-Token') == os.environ.get('WARM_TOKEN'):
        return 'forbidden', 403
    
    try:
        warmer = CacheWarmer(get_db_connection(), cache)
        warmer.warm_from_database()
        return jsonify({'status': 'ok', 'warmed_at': datetime.now().isoformat()})
    except Exception as e:
        logger.error(f"Cache warming failed: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500
```

**Problems:**
- Delay between restart and warming (up to 5 minutes in the example)
- If cron dies, you don't know until someone complains
- Warming endpoint is an attack vector if misconfigured
- Warming logic is outside the cache, hard to maintain

### Solution 3: Dual-Write With Normal Table (The King of Hacks)

When things get serious, you see this:

```sql
-- "Backup" table that is logged for recovery
CREATE TABLE cache_backup (
    cache_key TEXT PRIMARY KEY,
    cache_value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to keep sync
CREATE OR REPLACE FUNCTION sync_cache_backup()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        DELETE FROM cache_backup WHERE cache_key = OLD.cache_key;
        RETURN OLD;
    ELSE
        INSERT INTO cache_backup (cache_key, cache_value)
        VALUES (NEW.cache_key, NEW.cache_value)
        ON CONFLICT (cache_key) 
        DO UPDATE SET cache_value = NEW.cache_value, updated_at = NOW();
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cache_sync
AFTER INSERT OR UPDATE OR DELETE ON cache
FOR EACH ROW EXECUTE FUNCTION sync_cache_backup();
```

```python
def restore_cache_from_backup():
    """Run after restart to restore UNLOGGED from backup"""
    with conn.cursor() as cur:
        # First kill everything there (to be safe)
        cur.execute("TRUNCATE cache")
        
        # Copy from backup
        cur.execute("""
            INSERT INTO cache (cache_key, cache_value)
            SELECT cache_key, cache_value FROM cache_backup
        """)
        conn.commit()
```

**Problems:**
- You essentially have TWO tables doing the job of one real cache
- Trigger overhead on EVERY write
- TRUNCATE + bulk insert is slow (seconds to minutes)
- If backup grows too large, you have storage problems
- Transaction wrap-up can explode in high-write scenarios
- All of this just to simulate what PgCache does naturally

## PgCache: The Solution That Actually Works

PgCache solves the problem differently: instead of using PostgreSQL's UNLOGGED tables, it uses a **separate embedded PostgreSQL instance** as the cache database. This embedded PostgreSQL persists data normally and survives restarts.

### How It Works

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Your Server                                   │
│                                                                       │
│   ┌─────────────────────────────────┐    ┌────────────────────────┐   │
│   │      PostgreSQL (Origin)          │    │    PgCache Process     │   │
│   │                                 │    │                        │   │
│   │   Port 5432 (original)          │    │   Port 5433 (cache)     │   │
│   │                                 │    │                        │   │
│   │   Your app used to connect here ─┼───▶│   Your app connects    │   │
│   │                                 │    │   here now             │   │
│   │   Logical replication           │    │                        │   │
│   │   (CDC)                         │    │   Cache DB embedded     │   │
│   │   ◀─────────────────────────────┼────│   persists across      │   │
│   │                                 │    │   restarts             │   │
│   └─────────────────────────────────┘    └────────────────────────┘   │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

When you restart PostgreSQL:
1. **PostgreSQL restarts** → PgCache detects and reconnects automatically
2. **The embedded cache does NOT die** → unless you kill the container/process
3. **Cache data remains intact** → no data loss

### Two-Line Setup

```bash
docker run -d \
  --name pgcache \
  -p 5432:5432 \
  -p 9090:9090 \
  pgcache/pgcache \
  --upstream postgres://app:password@postgres-origin:5432/myapp
```

The only change in your application is the database host:

```python
# Before (pointing directly to PostgreSQL)
DATABASE_URL = "postgres://app:secret@postgres-origin:5432/myapp"

# After (pointing to PgCache)
DATABASE_URL = "postgres://app:secret@pgcache-host:5432/myapp"
```

The credentials are the same. PgCache does transparent proxy to the origin.

### More Complete Configuration

```bash
docker run -d \
  --name pgcache \
  -p 5432:5432 \
  -p 9090:9090 \
  pgcache/pgcache \
  --upstream postgres://app:password@postgres-origin:5432/myapp \
  --num-workers 4 \
  --cache-size 1073741824 \
  --allowed-tables users,products,categories,orders \
  --pinned-tables categories,settings \
  --log-level info
```

Or via TOML for version control:

```toml
# pgcache.toml
num_workers = 4
cache_size = 1073741824  # 1GB
log_level = "info"

[origin]
host = "postgres-origin"
port = 5432
user = "app_user"
password = "secret"
database = "myapp"
ssl_mode = "require"

[cdc]
publication_name = "pgcache_pub"
slot_name = "pgcache_slot"

[listen]
socket = "0.0.0.0:5432"

[metrics]
socket = "0.0.0.0:9090"
```

### For AWS (AMI on Marketplace)

```bash
# 1. Store credentials in SSM
aws ssm put-parameter --name "/pgcache/prod/upstream-url" \
  --type SecureString \
  --value "postgres://app:password@rds-host.amazonaws.com:5432/myapp?sslmode=require"

# 2. Launch instance with bootstrap
aws ec2 run-instances \
  --image-id ami-XXXXXXXX \
  --instance-type m6g.large \
  --iam-instance-profile Name=pgcache-ec2 \
  --user-data '#!/bin/bash
/opt/pgcache/bootstrap.sh --ssm-prefix /pgcache/prod --workers 4'
```

The bootstrap automates EVERYTHING: creates publications, slots, pulls credentials from SSM, configures the service.

## Detailed Comparison

| Aspect | UNLOGGED Tables | UNLOGGED + Warming | PgCache |
|--------|-----------------|--------------------|---------|
| Read performance | ✅ Fast | ✅ Fast | ✅ Fast |
| Write performance | ✅ Fast | ⚠️ Warming overhead | ✅ Fast |
| Cache survives restart | ❌ No | ❌ No | ✅ Yes |
| Time to warm cache | Zero | Minutes to hours | Zero |
| Code maintenance | Low | High | Low |
| Automatic CDC | ❌ No | ❌ No | ✅ Yes |
| Automatic invalidation | ❌ No | ❌ No | ✅ Yes |
| Dynamic queries cached | ❌ No | ❌ Limited | ✅ Yes |
| Monitoring | ❌ None | ⚠️ DIY | ✅ Prometheus |
| Crash safety | ❌ None | ⚠️ Partial | ✅ Full |

## When Each Makes Sense

### Use UNLOGGED tables if:
- You need local cache on a **single dev/test instance**
- You have **all the time in the world** to reload cache (nightly job)
- Your cache is **completely static** (reference data that changes once a week)
- You're doing a **proof of concept** and performance doesn't matter yet

### Use PgCache if:
- You're running in production with multiple application instances
- You need **cache consistency** even after restarts
- You don't want to maintain cache code manually
- You want cache that works with normal SQL queries, not just key-value
- You want **ready monitoring**: metrics, lag, hits/misses

## Migrating from UNLOGGED to PgCache

Migrating from the UNLOGGED pattern to PgCache? Here's a guide:

### Step 1: Setup PgCache Side by Side

```bash
# Start with PgCache pointing to your current database
docker run -d \
  -p 5433:5432 \  # Use different port initially
  -p 9091:9090 \
  --name pgcache \
  pgcache/pgcache \
  --upstream postgres://app:secret@your-postgres:5432/myapp
```

### Step 2: Test Integration

```python
# Test normal query via PgCache
import psycopg2

# Connect to PgCache (port 5433)
conn_pgcache = psycopg2.connect("postgres://app:secret@localhost:5433/myapp")

# Execute a query you want cached
cur = conn_pgcache.cursor()
cur.execute("SELECT * FROM products WHERE active = true LIMIT 10")
results = cur.fetchall()

print(f"Got {len(results)} products from PgCache")
```

### Step 3: Check Metrics

```bash
# Verify it's working
curl http://localhost:9091/metrics | grep -E "pgcache_queries|pgcache_cache"

# Expected output:
# pgcache_queries_total 1
# pgcache_queries_cacheable 1
# pgcache_queries_cache_hit 0
# pgcache_queries_cache_miss 1
```

### Step 4: Migrate Application

```python
# Just change the database host
# BEFORE
DATABASE_URL = "postgres://app:secret@your-postgres:5432/myapp"

# AFTER
DATABASE_URL = "postgres://app:secret@localhost:5432/myapp"  # PgCache on 5432
```

### Step 5: Remove Old Cache Code

Now you can remove:
- UNLOGGED `cache` table
- `cache_get`, `cache_set`, `cache_delete` code
- Cache warming code
- TTL/cleanup scripts
- Backup triggers

Remember to backup the old cache schema before dropping:

```sql
-- Backup before removing
CREATE TABLE cache_backup_final AS SELECT * FROM cache;

-- Only then drop
DROP TABLE IF EXISTS cache CASCADE;
DROP TABLE IF EXISTS cache_backup CASCADE;
```

## Conclusion

UNLOGGED tables as cache seem like a good idea on paper. They're simple to create, have no WAL overhead, and work great until something restarts. Then you find out:

1. The cache dies on every restart
2. Manual recovery is painful
3. Automatic solutions add complexity that shouldn't exist

PgCache offers an alternative that keeps the "postgres as cache" simplicity but adds what actually matters in production: **reliability, persistence, and zero maintenance**.

The same 1-line change in your connection string gives you:
- Cache that survives any restart
- Automatic invalidation via CDC
- Normal SQL queries cached
- Ready monitoring: metrics, lags, hits/misses

If you're already running PostgreSQL and thinking about adding caching, spare yourself the UNLOGGED table headache and try PgCache. Your future self (and your on-call) will thank you.

---

*PgCache is open source. Docs at pgcache.com. GitHub at github.com/tempest98/pgcache. Questions? Open an issue!*
