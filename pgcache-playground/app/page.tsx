'use client';

import { useState, useEffect } from 'react';
import { Database, Server, Settings, Zap } from 'lucide-react';
import ConfigurationModal from '@/components/ConfigurationModal';
import SchemaExplorer from '@/components/SchemaExplorer';
import BenchmarkWorkspace from '@/components/BenchmarkWorkspace';
import { LogProvider, useLogs } from '@/components/LogProvider';

function HomeContent() {
  const [config, setConfig] = useState<any>(null);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const { addLog } = useLogs();

  useEffect(() => {
    // Try to connect using .env on load
    const tryEnvConnect = async () => {
      try {
        addLog('info', 'Attempting to connect using .env variables...');
        const res = await fetch('/api/connect', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ useEnv: true }),
        });
        const data = await res.json();
        if (res.ok && data.success) {
          setConfig(data.config);
          addLog('success', 'Successfully connected to databases using .env variables');
        } else {
          addLog('warning', 'Could not connect using .env variables', data.error || 'Unknown error');
          setIsModalOpen(true);
        }
      } catch (e: any) {
        addLog('error', 'Failed to connect using .env variables', e.message || String(e));
        setIsModalOpen(true);
      } finally {
        setIsInitialLoading(false);
      }
    };
    tryEnvConnect();
  }, [addLog]);

  if (isInitialLoading) {
    return (
      <div className="min-h-screen bg-zinc-100 flex flex-col items-center justify-center font-sans text-zinc-900">
        <div className="flex flex-col items-center gap-4">
          <div className="w-10 h-10 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
          <p className="text-zinc-600 font-medium animate-pulse">Connecting to databases...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-zinc-100 flex flex-col font-sans text-zinc-900">
      {/* Top Bar */}
      <header className="h-14 bg-white border-b border-zinc-200 flex items-center justify-between px-6 shrink-0 shadow-sm z-10">
        <div className="flex items-center gap-2 text-emerald-600 font-bold text-lg tracking-tight">
          <Zap size={20} className="fill-emerald-600" />
          pgCache Playground
        </div>
        
        <div className="flex items-center gap-6">
          <div className="flex items-center gap-4 text-xs font-medium">
            <div className="flex items-center gap-1.5">
              <Database size={14} className="text-zinc-400" />
              <span className="text-zinc-600">PostgreSQL:</span>
              <span className={`flex items-center gap-1 ${config ? 'text-emerald-600' : 'text-zinc-400'}`}>
                <span className={`w-2 h-2 rounded-full ${config ? 'bg-emerald-500' : 'bg-zinc-300'}`}></span>
                {config ? 'Connected' : 'Disconnected'}
              </span>
            </div>
            <div className="w-px h-4 bg-zinc-200"></div>
            <div className="flex items-center gap-1.5">
              <Server size={14} className="text-zinc-400" />
              <span className="text-zinc-600">pgCache:</span>
              <span className={`flex items-center gap-1 ${config ? 'text-emerald-600' : 'text-zinc-400'}`}>
                <span className={`w-2 h-2 rounded-full ${config ? 'bg-emerald-500' : 'bg-zinc-300'}`}></span>
                {config ? 'Connected' : 'Disconnected'}
              </span>
            </div>
          </div>
          
          <button 
            onClick={() => setIsModalOpen(true)}
            className="bg-zinc-100 hover:bg-zinc-200 text-zinc-700 px-3 py-1.5 rounded-md text-xs font-semibold flex items-center gap-1.5 transition"
          >
            <Settings size={14} />
            {config ? 'Settings' : 'Connect'}
          </button>
        </div>
      </header>

      {/* Main Content */}
      <div className="flex-1 flex overflow-hidden">
        {/* Left Sidebar - Schema Explorer */}
        <aside className="w-64 bg-zinc-50 border-r border-zinc-200 overflow-y-auto shrink-0 shadow-[inset_-1px_0_0_rgba(0,0,0,0.05)]">
          <SchemaExplorer config={config} />
        </aside>

        {/* Right Area - Benchmark Workspace */}
        <main className="flex-1 overflow-y-auto p-6 bg-zinc-100/50">
          <BenchmarkWorkspace config={config} />
        </main>
      </div>

      <ConfigurationModal 
        isOpen={isModalOpen} 
        onClose={() => setIsModalOpen(false)} 
        onConnect={(data) => setConfig(data)} 
      />
    </div>
  );
}

export default function Home() {
  return (
    <LogProvider>
      <HomeContent />
    </LogProvider>
  );
}
