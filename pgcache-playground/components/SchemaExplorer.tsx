'use client';

import { useState, useEffect } from 'react';
import { Database, Table, Columns, AlertCircle, ChevronRight, ChevronDown } from 'lucide-react';

export default function SchemaExplorer({ config }: { config: any }) {
  const [schema, setSchema] = useState<any[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [expandedTables, setExpandedTables] = useState<Record<string, boolean>>({});

  useEffect(() => {
    if (!config) return;
    
    const fetchSchema = async () => {
      setLoading(true);
      try {
        const res = await fetch('/api/schema', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ dbUrl: config.postgresUrl, ...config }),
        });
        const data = await res.json();
        if (res.ok) {
          setSchema(data.schema);
        } else {
          setError(data.error);
        }
      } catch (e) {
        setError('Failed to fetch schema');
      } finally {
        setLoading(false);
      }
    };

    fetchSchema();
  }, [config]);

  const toggleTable = (tableName: string) => {
    setExpandedTables(prev => ({
      ...prev,
      [tableName]: !prev[tableName]
    }));
  };

  if (!config) {
    return (
      <div className="p-6 flex flex-col items-center justify-center text-center text-zinc-500 h-full">
        <Database size={48} className="mb-4 text-zinc-300" />
        <p className="text-sm">Connect to a database to view its schema.</p>
      </div>
    );
  }

  if (loading) return <div className="p-6 text-zinc-500 text-sm animate-pulse">Loading schema...</div>;
  if (error) return <div className="p-6 text-red-500 text-sm flex items-center gap-2"><AlertCircle size={16} /> {error}</div>;

  const tables = [...new Set(schema.map((s) => s.table_name))];

  return (
    <div className="p-4">
      <h3 className="text-xs font-bold text-zinc-400 uppercase tracking-wider mb-4 px-2">Database Schema</h3>
      <div className="space-y-4">
        {tables.map((table) => {
          const isExpanded = expandedTables[table as string];
          return (
            <div key={table as string} className="bg-white rounded-lg border border-zinc-200 shadow-sm overflow-hidden">
              <button 
                onClick={() => toggleTable(table as string)}
                className="w-full bg-zinc-50 px-3 py-2 border-b border-zinc-200 flex items-center justify-between hover:bg-zinc-100 transition"
              >
                <div className="flex items-center gap-2">
                  <Table size={16} className="text-zinc-500" />
                  <span className="font-semibold text-sm text-zinc-800">{table as string}</span>
                </div>
                {isExpanded ? <ChevronDown size={14} className="text-zinc-400" /> : <ChevronRight size={14} className="text-zinc-400" />}
              </button>
              {isExpanded && (
                <ul className="divide-y divide-zinc-100 max-h-48 overflow-y-auto">
                  {schema
                    .filter((s) => s.table_name === table)
                    .map((col) => (
                      <li key={col.column_name} className="px-3 py-1.5 text-xs text-zinc-600 flex items-center gap-2">
                        <Columns size={12} className="text-zinc-400" />
                        {col.column_name}
                      </li>
                    ))}
                </ul>
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}
