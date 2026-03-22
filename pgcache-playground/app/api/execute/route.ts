import { NextResponse } from 'next/server';
import { createDbClient } from '@/lib/db';
import { performance } from 'perf_hooks';

export async function POST(req: Request) {
  const { postgresUrl, pgCacheUrl, query, params, user, password, database } = await req.json();
  const credentials = { user, password, database };
  
  const runQuery = async (url: string) => {
    const client = await createDbClient(url, credentials);
    const start = performance.now();
    await client.query(query, params);
    const end = performance.now();
    return end - start;
  };

  try {
    const [dbTime, pgCacheTime] = await Promise.all([
      runQuery(postgresUrl),
      runQuery(pgCacheUrl)
    ]);
    
    return NextResponse.json({ dbTime, pgCacheTime });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 400 });
  }
}
