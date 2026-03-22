'use client';

import { useLogs } from './LogProvider';
import { Trash2, Info, CheckCircle2, AlertTriangle, XCircle } from 'lucide-react';

export default function LogViewer() {
  const { logs, clearLogs } = useLogs();

  const getIcon = (level: string) => {
    switch (level) {
      case 'info': return <Info size={14} className="text-blue-500" />;
      case 'success': return <CheckCircle2 size={14} className="text-emerald-500" />;
      case 'warning': return <AlertTriangle size={14} className="text-amber-500" />;
      case 'error': return <XCircle size={14} className="text-red-500" />;
      default: return <Info size={14} className="text-zinc-500" />;
    }
  };

  return (
    <div className="w-full h-full flex flex-col bg-zinc-950 text-zinc-300 font-mono text-xs overflow-hidden">
      <div className="flex items-center justify-between px-4 py-2 bg-zinc-900 border-b border-zinc-800 shrink-0">
        <span className="font-semibold text-zinc-400">System Logs</span>
        <button 
          onClick={clearLogs}
          className="flex items-center gap-1.5 text-zinc-400 hover:text-red-400 transition-colors px-2 py-1 rounded hover:bg-zinc-800"
        >
          <Trash2 size={12} /> Clear
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-4 space-y-3">
        {logs.length === 0 ? (
          <div className="text-zinc-600 text-center mt-10 italic">No logs available.</div>
        ) : (
          logs.map(log => (
            <div key={log.id} className="flex flex-col gap-1 border-b border-zinc-800/50 pb-3 last:border-0">
              <div className="flex items-start gap-2">
                <span className="text-zinc-500 shrink-0 mt-0.5">
                  [{log.timestamp.toLocaleTimeString()}]
                </span>
                <span className="shrink-0 mt-0.5">{getIcon(log.level)}</span>
                <span className={`font-medium ${log.level === 'error' ? 'text-red-400' : log.level === 'success' ? 'text-emerald-400' : log.level === 'warning' ? 'text-amber-400' : 'text-blue-400'}`}>
                  {log.message}
                </span>
              </div>
              {log.details && (
                <div className="ml-[72px] bg-zinc-900/50 p-2 rounded border border-zinc-800 text-zinc-400 whitespace-pre-wrap break-all">
                  {log.details}
                </div>
              )}
            </div>
          ))
        )}
      </div>
    </div>
  );
}
