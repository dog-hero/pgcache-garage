# Aquecimento de Cache Sem Downtime: Como PgCache Lida com CDC e Você Não Precisa Fazer Nada

Uma das partes mais complicadas de caching é manter o cache fresco. Com abordagens tradicionais, você ou está brigando com TTLs ou invalidando entradas manualmente. PgCache toma um caminho diferente — ele escuta as mudanças do seu banco e atualiza o cache automaticamente. Vamos falar sobre como isso funciona.

## O Problema da Invalidação de Cache

A maioria dos caches tem uma tensão fundamental: você quer dados frescos, mas verificar frescor é caro. Então você acaba com:

- **Expiração por TTL**: Simples, mas dados podem estar velhos até o TTL expirar
- **Invalidation manual**: Correto, mas propenso a erros e requer mudanças no código
- **Write-through**: Writes rápidos viram writes lentos
- **Write-behind**: Precisa trackear toda mutação

Nenhum desses é ótimo. Ou aceitam stale data ou adicionam complexidade.

## A Abordagem CDC do PgCache

PgCache conecta no seu PostgreSQL de origem usando logical replication. Quando dados mudam na origem (INSERT, UPDATE, DELETE, TRUNCATE), essas mudanças são streamadas para PgCache automaticamente.

O fluxo é esse:

1. PgCache cria uma publication e replication slot no seu banco de origem
2. Mudanças são capturadas conforme acontecem via WAL
3. PgCache identifica quais queries em cache são afetadas
4. Entradas afetadas são atualizadas diretamente ou invalidadas para refresh preguiçoso

O resultado: seu cache fica sincronizado com seu banco sem nenhuma mudança de código ou intervenção manual.

## O Que É Atualizado

Para queries simples de tabela única pinadas como:

```sql
SELECT * FROM categories
```

PgCache atualiza o cache no lugar quando linhas mudam. Sem invalidação necessária. A entrada do cache está sempre fresca.

Para queries mais complexas, PgCache invalida as entradas afetadas. Na próxima vez que a query rodar, ela pega dados frescos da origem.

## Monitorando o Sync

Como CDC é um pipeline, PgCache expõe métricas para monitorar saúde:

```
pgcache_cdc_lag_seconds       # Quão atrás o cache está
pgcache_cdc_events_processed  # Total de eventos processados
pgcache_cache_invalidations   # Quantas entradas foram invalidadas
```

Se você ver o lag crescer, você sabe que algo está errado antes dos usuários começarem a reclamar.

## Por Que Isso É Melhor Que Invalidar Manualmente

Com invalidation manual, você provavelmente está fazendo algo tipo:

```python
def update_user(user_id, data):
    db.update(user_id, data)
    cache.delete(f"user:{user_id}")
    cache.delete("users:list")  # Tomara que você não esqueça dessa aqui
```

Todo code path que modifica dados precisa saber sobre toda entrada de cache que depende dele. É frágil.

Com PgCache, você só escreve no banco:

```python
def update_user(user_id, data):
    db.update(user_id, data)
    # É isso. PgCache cuida do resto.
```

## O Verdadeiro Benefício

Caching baseado em CDC significa que seu código de aplicação fica simples. Você não precisa de hooks aware de cache no ORM ou lógica na service layer para manter o cache válido. A infraestrutura cuida disso.

Se você está cansado de bugs de invalidation de cache, ou se você tem evitado caching porque manter em sync parece um fardo de manutenção, PgCache pode ser o que você está procurando.

---

*Veja os docs em pgcache.com para ver todos os padrões de query suportados e começar em minutos.*
