import { NextResponse } from 'next/server';
import { createDbClient } from '@/lib/db';

export async function POST(req: Request) {
  try {
    const body = await req.json().catch(() => ({}));
    
    let postgresUrl, pgCacheUrl, user, password, database;

    if (body.useEnv) {
      postgresUrl = process.env.POSTGRES_URL;
      pgCacheUrl = process.env.PGCACHE_URL;
      user = process.env.DB_USER;
      password = process.env.DB_PASSWORD;
      database = process.env.DB_NAME;

      if (!postgresUrl || !pgCacheUrl || !user || !password || !database) {
        return NextResponse.json({ success: false, error: 'Missing environment variables' }, { status: 400 });
      }
    } else {
      ({ postgresUrl, pgCacheUrl, user, password, database } = body);
    }

    const credentials = { user, password, database };
    
    const [pool1, pool2] = await Promise.all([
      createDbClient(postgresUrl, credentials),
      createDbClient(pgCacheUrl, credentials)
    ]);
    
    // Test queries to ensure connection is valid
    await Promise.all([
      pool1.query('SELECT 1'),
      pool2.query('SELECT 1')
    ]);

    return NextResponse.json({ 
      success: true, 
      config: { postgresUrl, pgCacheUrl, user, password, database } 
    });
  } catch (error) {
    return NextResponse.json({ success: false, error: String(error) }, { status: 400 });
  }
}
