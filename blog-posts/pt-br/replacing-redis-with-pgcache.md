# De Tabelas UNLOGGED para PgCache: O Guia Definitivo Sobre Cache com PostgreSQL

Você provavelmente já viu posts dizendo "eu substituí o Redis pelo PostgreSQL" usando tabelas UNLOGGED. É um truque que circula há anos: desde que tabelas UNLOGGED não escrevem no WAL, elas são mais rápidas para operações de cache. Aí você implementa, funciona bonito em dev, e depois... boom.

Vou te mostrar exatamente como esse pattern funciona, por que ele parece uma boa ideia, e por que o PgCache é uma solução melhor — de verdade.

## Como Funciona o Pattern de Tabelas UNLOGGED

A ideia por trás de usar PostgreSQL como cache com UNLOGGED é elegante na sua simplicidade. Como a tabela não escreve no Write-Ahead Log, você ganha performance sem overhead de replicação.

### A Implementação Típica

O código que você vê por aí geralmente é algo assim:

```sql
-- Criação da tabela de cache
CREATE UNLOGGED TABLE cache (
    cache_key TEXT PRIMARY KEY,
    cache_value JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    accessed_at TIMESTAMPTZ DEFAULT NOW()
);

-- Índice para buscas rápidas
CREATE INDEX idx_cache_accessed ON cache (accessed_at);
```

```python
# Exemplo em Python com psycopg2
import psycopg2
import json
from datetime import datetime

def cache_get(conn, key):
    """Pega do cache e atualiza accessed_at"""
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
    """Armazena no cache com TTL manual"""
    with conn.cursor() as cur:
        cur.execute("""
            INSERT INTO cache (cache_key, cache_value, created_at, accessed_at)
            VALUES (%s, %s, NOW(), NOW())
            ON CONFLICT (cache_key) 
            DO UPDATE SET cache_value = EXCLUDED.cache_value, accessed_at = NOW()
        """, (key, json.dumps(value)))

def cache_delete(conn, key):
    """Remove do cache"""
    with conn.cursor() as cur:
        cur.execute("DELETE FROM cache WHERE cache_key = %s", (key,))

def cleanup_expired(conn, ttl_seconds=300):
    """Limpa entradas expiradas - precisa rodar via cron ou background worker"""
    with conn.cursor() as cur:
        cur.execute("""
            DELETE FROM cache 
            WHERE accessed_at < NOW() - INTERVAL '%s seconds'
        """, (ttl_seconds,))
```

### A Versão "Otimizada" Que Todo Mundo Usa

Quando o post do blog começa a escalar, você vê esse tipo de coisa:

```python
# Exemplo mais "sofisticado" - camada de cache com decorators
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
        
        # Tenta restaurar de cache "expirado" se não tiver hit no cache quente
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
        """Remove todas as chaves que|matchem um pattern - UTI LENTO"""
        cur = self.conn.cursor()
        cur.execute("DELETE FROM cache WHERE cache_key LIKE %s", (pattern.replace('%', '%%'),))
        self.conn.commit()
```

## O Problema Real: O Que Acontece Quando o PostgreSQL Reinicia

Agora a parte que os posts bonitinhos não contam. Vou mostrar exatamente o que acontece.

### O Que A Documentação Diz

Da documentação oficial do PostgreSQL:

> UNLOGGED tables are not crash-safe: the data is not written to the write-ahead log. Your data is lost in case of a crash or unclean shutdown. The table is automatically truncated after a crash or unclean shutdown.

E também:

> UNLOGGED tables are not replicated by streaming replication or logical replication.

Tradução: se o PostgreSQL reiniciar por qualquer motivo — crash, reboot do servidor, manutenção — **sua tabela UNLOGGED é automaticamente truncada**. Não é um bug, é o comportamento esperado.

### Simulando o Problema

Vamos simular o que acontece:

```bash
# Terminal 1: sua aplicação rodando com cache aquecido
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

# Terminal 2: alguém reinicia o PostgreSQL
$ sudo systemctl restart postgresql

# Terminal 1: (a conexão vai derrubar, você reconecta)
myapp=# SELECT COUNT(*) FROM cache;
 count
-------
 0
(1 row)
```

Sim, é isso mesmo. Todas as 15.234 linhas sumiram. Agora imagine isso happening em produção às 14h de uma terça-feira.

### O Ciclo de Vida "Típico" de Uma Aplicação Com UNLOGGED

É mais ou menos assim:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Aplicação em Produção                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. Deploy inicial: "Vou usar UNLOGGED tables, é genius!"        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. Cache aquece: milhões de reads/s, latency cai de 50ms pra 2ms │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. OPOs! Reiniciaram o banco. Cache zerou.                      │
│    - Latency volta pro mínimo                                    │
│    - Origin começa a sangrar                                      │
│    - P95/P99 latency dispara                                     │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. Hora de "consertar": implementar cache warming no app         │
│    - Adiciona lógica de warming                                  │
│    - Mais código, mais complexidade                              │
│    - Mais pontos de falha                                        │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. Volta pro passo 3...                                         │
└─────────────────────────────────────────────────────────────────┘
```

## As "Soluções" Que O Mundo Cria (E Por Que São Gambiarras)

Quando o problema começa a aparecer, a comunidade PostgreSQL inventa soluções cada vez mais elaboradas. Todas são trabalho ao redor do problema real.

### Solução 1: Cache Warming na Aplicação

A tentativa mais comum. Você adiciona lógica para aquecer o cache quando a aplicação inicia ou quando detecta que o cache está vazio.

```python
class CacheWarmer:
    def __init__(self, db_conn, cache):
        self.db = db_conn
        self.cache = cache
    
    def warm_from_database(self):
        """Roda queries pesadas na origem e popula o cache"""
        print("Warming cache...")
        
        # Queries "quentes" que você sabe que são importantes
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
            # ... você precisa adicionar TODA query que quer em cache
            # E lembrar de manter essa lista atualizada
        ]
        
        for name, query in queries_to_warm:
            with self.db.cursor() as cur:
                cur.execute(query)
                results = cur.fetchall()
                
                # Serializa e armazena
                self.cache.set(name, {
                    'data': results,
                    'queried_at': datetime.now().isoformat()
                })
        
        print(f"Cache aquecido com {len(queries_to_warm)} queries")
    
    def is_cache_empty(self):
        """Verifica se o cache está vazio"""
        with self.db.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM cache")
            return cur.fetchone()[0] == 0
    
    def warm_if_needed(self):
        """Verifica e aquece se necessário"""
        if self.is_cache_empty():
            self.warm_from_database()
```

**Problemas:**
- Você precisa saber de antemão todas as queries que quer em cache
- Queries dinâmicas? Esquece. Precisa de query builder específico.
- Se uma tabela muda de schema, seu warming pode quebrar silenciosamente
- Tempo de warming pode ser minutos para bases grandes
- Você está essencialmente re-implementando um cache na mão

### Solução 2: Checkpoint Script Via Cron

Você detecta se o banco reiniciou e roda o warming automaticamente:

```bash
#!/bin/bash
# check_cache.sh - roda via cron a cada 5 minutos

# Verifica se tem cache
CACHE_COUNT=$(psql -t -c "SELECT COUNT(*) FROM cache" $DATABASE_URL)

if [ "$CACHE_COUNT" -eq 0 ]; then
    echo "$(date): Cache vazio, disparando warming..."
    curl -X POST http://your-app.internal/api/cache/warm
else
    echo "$(date): Cache OK ($CACHE_COUNT entradas)"
fi
```

```python
# No lado da aplicação - endpoint de warming
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

**Problemas:**
- Delay entre restart e warming (até 5 minutos no exemplo)
- Se o cron morrer, você não sabe até alguém投诉
- endpoint de warming é um vector de ataque se mal configurado
- Lógica de warming fica fora do cache, difícil de manter

### Solução 3: Dual-Write Com Tabela Normal (A Gambiarra King)

Quando as coisas ficam sérias, você vê isso:

```sql
-- Tabela "backup" que élogged para recovery
CREATE TABLE cache_backup (
    cache_key TEXT PRIMARY KEY,
    cache_value JSONB NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger para manter sync
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
    """Roda depois de restart para restaurar UNLOGGED do backup"""
    with conn.cursor() as cur:
        # Primeiro mata tudo que tá lá (pra garantir)
        cur.execute("TRUNCATE cache")
        
        # Copia do backup
        cur.execute("""
            INSERT INTO cache (cache_key, cache_value)
            SELECT cache_key, cache_value FROM cache_backup
        """)
        conn.commit()
```

**Problemas:**
- Você essentially tem DUAS tabelas fazendo o trabalho de um cache de verdade
- Overhead de trigger em TODO write
- TRUNCATE + bulk insert é lento (segundos a minutos)
- Se o backup crescer muito, você tem problemas de storage
- Transaction wrap-up pode explodir em cenários de alta escrita
- Tudo isso só para simular o que PgCache faz naturalmente

## PgCache: A Solução Que Funciona De Verdade

PgCache resolve o problema de outra forma: ao invés de usar tabelas UNLOGGED do PostgreSQL, ele usa um **PostgreSQL separado e embutido** como banco de cache. Esse PostgreSQL embedded persiste os dados normalmente e sobrevive a reinícios.

### Como Funciona

```
┌──────────────────────────────────────────────────────────────────────┐
│                          Seu Servidor                                 │
│                                                                       │
│   ┌─────────────────────────────────┐    ┌────────────────────────┐   │
│   │      PostgreSQL (Origin)        │    │    PgCache Process     │   │
│   │                                 │    │                        │   │
│   │   Port 5432 (original)          │    │   Port 5433 (cache)     │   │
│   │                                 │    │                        │   │
│   │   Seu app conectava aqui ───────┼───▶│   Seu app conecta aqui │   │
│   │                                 │    │                        │   │
│   │  逻辑复制│                        │    │   Cache DB embedded   │   │
│   │   (logical replication)          │    │   persists across     │   │
│   │   ◀─────────────────────────────┼────│   restarts            │   │
│   │                                 │    │                        │   │
│   └─────────────────────────────────┘    └────────────────────────┘   │
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

Quando você reinicia o PostgreSQL:
1. **PostgreSQL reinicia** → PgCache detecta e re-conecta automaticamente
2. **O cache embedded NÃO morre** → a não ser que você mate o container/processo
3. **Os dados do cache permanecem intactos** → nenhuma perda

### Setup Em Duas Linhas

```bash
docker run -d \
  --name pgcache \
  -p 5432:5432 \
  -p 9090:9090 \
  pgcache/pgcache \
  --upstream postgres://app:password@postgres-origin:5432/myapp
```

A única mudança na sua aplicação é o host do banco:

```python
# Antes (apontando direto pro PostgreSQL)
DATABASE_URL = "postgres://app:secret@postgres-origin:5432/myapp"

# Depois (apontando pro PgCache)
DATABASE_URL = "postgres://app:secret@pgcache-host:5432/myapp"
```

As credenciais são as mesmas. O PgCache faz proxy transparente para a origem.

### Configuração Mais Completa

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

Ou via TOML para versionamento:

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

### Para AWS (AMI no Marketplace)

```bash
# 1. Armazena credentials no SSM
aws ssm put-parameter --name "/pgcache/prod/upstream-url" \
  --type SecureString \
  --value "postgres://app:password@rds-host.amazonaws.com:5432/myapp?sslmode=require"

# 2. Lança instância com bootstrap
aws ec2 run-instances \
  --image-id ami-XXXXXXXX \
  --instance-type m6g.large \
  --iam-instance-profile Name=pgcache-ec2 \
  --user-data '#!/bin/bash
/opt/pgcache/bootstrap.sh --ssm-prefix /pgcache/prod --workers 4'
```

O bootstrap automatiza TUDO: cria publications, slots, baixa credentials do SSM, configura o serviço.

## Comparação Detalhada

| Aspecto | Tabelas UNLOGGED | Tabelas UNLOGGED + Warming | PgCache |
|---------|-----------------|---------------------------|---------|
| Performance leitura | ✅ Rápido | ✅ Rápido | ✅ Rápido |
| Performance escrita | ✅ Rápido | ⚠️ Overhead do warming | ✅ Rápido |
| Cache sobrevive restart | ❌ Não | ❌ Não | ✅ Sim |
| Tempo até cache quente | Zero | Minutos a horas | Zero |
| Manutenção de código | Baixa | Alta | Baixa |
| CDC automático | ❌ Não | ❌ Não | ✅ Sim |
| Invalidação automática | ❌ Não | ❌ Não | ✅ Sim |
| Queries dinâmicas em cache | ❌ Não | ❌ Limitado | ✅ Sim |
| Monitoramento | ❌ Nenhum | ⚠️ DIY | ✅ Prometheus |
| Crash safety | ❌ Nenhuma | ⚠️ Parcial | ✅ Completa |

## Cenários Onde Cada Um Faz Sentido

### Use UNLOGGED tables se:
- Você precisa de cache local em **uma única instância** de dev/teste
- Você tem **todo o tempo do mundo** para recarregar o cache (job noturno)
- Seu cache é **completamente estático** (dados de referência que mudam uma vez por semana)
- Você está fazendo **proof of concept** e performance não importa ainda

### Use PgCache se:
- Você roda em produção com múltiplas instâncias de aplicação
- Você precisa de **consistência de cache** mesmo após reinícios
- Você não quer manter código de cache manualmente
- Você quer cache que funciona com queries SQL normais, não só chave-valor
- Você quer **monitoramento pronto**: métricas, lags, hits/misses

## Migração de UNLOGGED para PgCache

Migando do pattern UNLOGGED para PgCache? Aqui vai um guia:

### Passo 1: Setup PgCache Lado a Lado

```bash
# Começa com PgCache apontando pro seu banco atual
docker run -d \
  -p 5433:5432 \  # Usa porta diferente inicialmente
  -p 9091:9090 \
  --name pgcache \
  pgcache/pgcache \
  --upstream postgres://app:secret@seu-postgres:5432/myapp
```

### Passo 2: Testa Integracao

```python
# Testa query normal via PgCache
import psycopg2

# Conecta no PgCache (porta 5433)
conn_pgcache = psycopg2.connect("postgres://app:secret@localhost:5433/myapp")

# Executa uma query que você quer em cache
cur = conn_pgcache.cursor()
cur.execute("SELECT * FROM products WHERE active = true LIMIT 10")
results = cur.fetchall()

print(f"Got {len(results)} products from PgCache")
```

### Passo 3: Verifica Métricas

```bash
# Verifica se está funcionando
curl http://localhost:9091/metrics | grep -E "pgcache_queries|pgcache_cache"

# Saída esperada:
# pgcache_queries_total 1
# pgcache_queries_cacheable 1
# pgcache_queries_cache_hit 0
# pgcache_queries_cache_miss 1
```

### Passo 4: Migra Aplicação

```python
# Muda só o host do banco
# ANTES
DATABASE_URL = "postgres://app:secret@seu-postgres:5432/myapp"

# DEPOIS
DATABASE_URL = "postgres://app:secret@localhost:5432/myapp"  # PgCache na 5432
```

### Passo 5: Remove Código de Cache Antigo

Agora você pode remover:
- Tabela `cache` UNLOGGED
- Código de `cache_get`, `cache_set`, `cache_delete`
- Código de cache warming
- Scripts de TTL/cleanup
- Triggers de backup

Lembre de fazer backup do schema de cache antigo antes de dropar:

```sql
-- Backup antes de remover
CREATE TABLE cache_backup_final AS SELECT * FROM cache;

-- Só depois dropa
DROP TABLE IF EXISTS cache CASCADE;
DROP TABLE IF EXISTS cache_backup CASCADE;
```

## Conclusão

Tabelas UNLOGGED como cache parecem uma boa ideia no papel. São simples de criar, não tem overhead de WAL, e funcionam bem até o momento em que algo reinicia. Aí você descobre que:

1. O cache morre em todo restart
2. Recovery manual é doloroso
3. Soluções automáticas adicionam complexidade que não deveria existir

PgCache oferece uma alternativa que mantém a simplicidade de "postgres como cache" mas adiciona o que realmente importa em produção: **confiabilidade, persistência, e manutenção zero**.

A mesma mudança de 1 linha na connection string te dá:
- Cache que sobrevive a qualquer reinício
- Invalidação automática via CDC
- Queries SQL normais em cache
- Métricas prontas

Se você já está usando PostgreSQL e pensando em adicionar cache, poupe a si mesmo da dor de cabeça das UNLOGGED tables e experimenta PgCache. Seu futuro eu (e seu on-call) vão agradecer.

---

*PgCache é open source. Docs em pgcache.com. GitHub em github.com/tempest98/pgcache. Tem perguntas? Abre uma issue!*
