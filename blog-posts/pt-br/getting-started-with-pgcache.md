# Postgres Como Cache? Tem Um Jeito Melhor

Se você usa PostgreSQL há um tempo, provavelmente já ouviu o conselho: "É só colocar uma camada de cache na frente do seu banco." E talvez você tenha olhado para Redis, Memcached, ou outras soluções de caching. Mas tem overhead em gerenciar outro serviço. E se seu banco pudesse lidar com caching nativamente?

É pra isso que PgCache foi feito.

## A Configuração

Colocar PgCache para rodar leva mais ou menos 2 minutos:

```bash
docker run -d -p 5432:5432 -p 9090:9090 pgcache/pgcache \
  --upstream postgres://user:password@seu-db:5432/myapp
```

Aponte sua aplicação para a porta 5432 ao invés do banco diretamente. É isso. Queries começam a passar pelo cache automaticamente.

## O Que PgCache Faz Cache

PgCache é esperto sobre o que ele faz cache. Ele analisa seu SQL e só faz cache de queries onde pode garantir resultados corretos. Coisas como:

- SELECTs simples: `SELECT * FROM products WHERE active = true`
- JOINs: `SELECT u.name, o.total FROM users u JOIN orders o ON u.id = o.user_id`
- Agregações: `SELECT COUNT(*), SUM(amount) FROM orders GROUP BY status`
- CTEs e subqueries
- Funções de janela

E ele mantém o cache fresco usando logical replication do PostgreSQL. Quando dados no seu banco mudam, o cache atualiza automaticamente.

## O Que Não Vai Para Cache

Queries que modificam dados (INSERT, UPDATE, DELETE) vão direto para a origem. Assim como queries com funções voláteis, cláusulas de lock, ou views. PgCache é conservador — se não pode garantir correctness, ele não faz cache.

## Monitoramento

Métricas Prometheus vêm built-in na porta 9090:

```bash
curl http://localhost:9090/metrics | grep pgcache
```

Métricas importantes:
- `pgcache_queries_cache_hit` / `pgcache_queries_cache_miss` — sua taxa de acerto
- `pgcache_cdc_lag_seconds` — quão fresco seu cache está
- `pgcache_cache_size_bytes` — utilização do cache

## Funciona Com Meu ORM?

Sim. PgCache fala o protocolo wire do PostgreSQL. Seja você usando psycopg2, SQLAlchemy, Prisma, Hibernate, ou qualquer outra coisa, funciona direto. Sem mudança de biblioteca cliente necessária.

## Você Deve Usar?

PgCache brilha quando:
- Você tem workloads heavy de leitura
- Suas queries seguem padrões previsíveis
- Você quer reduzir load no seu banco de origem
- Você não quer gerenciar infraestrutura separada de caching

Não é uma bala de prata — se você precisa de cache distribuído entre múltiplas instâncias de aplicação, ou se seu caso de uso requer algo fora do modelo de query do PostgreSQL, Redis ou similar ainda pode fazer sentido.

Mas se você já roda PostgreSQL e quer extrair mais performance da sua infraestrutura existente, PgCache vale uma olhada.

---

*Docs e mais em pgcache.com. GitHub em github.com/tempest98/pgcache.*
