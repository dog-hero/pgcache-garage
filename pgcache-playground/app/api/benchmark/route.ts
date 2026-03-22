import { NextResponse } from 'next/server';
import { createDbClient } from '@/lib/db';
import { performance } from 'perf_hooks';

export async function POST(req: Request) {
  try {
    const { config, query, paramsList, runs, target = 'both' } = await req.json();
    
    if (!config || !query || !runs) {
      return NextResponse.json({ error: 'Missing required parameters' }, { status: 400 });
    }

    const credentials = { 
      user: config.user, 
      password: config.password, 
      database: config.database 
    };

    const runBenchmark = async (url: string) => {
      const pool = await createDbClient(url, credentials);
      const times: number[] = [];
      
      // If no parameters provided, just run the query `runs` times
      const sets = paramsList && paramsList.length > 0 ? paramsList : [[]];

      for (const params of sets) {
        for (let i = 0; i < runs; i++) {
          const start = performance.now();
          await pool.query(query, params);
          const end = performance.now();
          times.push(end - start);
        }
      }
      return times;
    };

    const [postgresTimes, pgCacheTimes] = await Promise.all([
      (target === 'both' || target === 'postgres') ? runBenchmark(config.postgresUrl) : Promise.resolve([]),
      (target === 'both' || target === 'pgcache') ? runBenchmark(config.pgCacheUrl) : Promise.resolve([])
    ]);

    return NextResponse.json({ postgresTimes, pgCacheTimes });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 400 });
  }
}
