import { Pool } from 'pg';

// Cache pools to avoid creating too many connections during hot reloads
const pools: Record<string, Pool> = {};

export async function createDbClient(url: string, credentials: any) {
  const poolKey = `${url}-${credentials.user}-${credentials.database}`;
  
  if (!pools[poolKey]) {
    const [host, port] = url.split(':');
    pools[poolKey] = new Pool({
      host,
      port: parseInt(port || '5432'),
      user: credentials.user,
      password: credentials.password,
      database: credentials.database,
      max: 20, // Allow up to 20 concurrent connections
      idleTimeoutMillis: 30000,
    });
  }
  
  // Test connection
  const client = await pools[poolKey].connect();
  client.release();
  
  return pools[poolKey];
}
