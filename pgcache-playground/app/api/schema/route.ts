import { NextResponse } from 'next/server';
import { createDbClient } from '@/lib/db';

export async function POST(req: Request) {
  const { dbUrl, user, password, database } = await req.json();
  const credentials = { user, password, database };
  try {
    const client = await createDbClient(dbUrl, credentials);
    const res = await client.query(`
      SELECT table_name, column_name 
      FROM information_schema.columns 
      WHERE table_schema = 'public'
    `);
    return NextResponse.json({ schema: res.rows });
  } catch (error) {
    return NextResponse.json({ error: String(error) }, { status: 400 });
  }
}
