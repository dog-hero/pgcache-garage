'use client';

import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import * as z from 'zod';
import { X } from 'lucide-react';
import { useLogs } from './LogProvider';

const configSchema = z.object({
  postgresUrl: z.string().min(1),
  pgCacheUrl: z.string().min(1),
  user: z.string().min(1),
  password: z.string().min(1),
  database: z.string().min(1),
});

export default function ConfigurationModal({ 
  isOpen, 
  onClose, 
  onConnect 
}: { 
  isOpen: boolean; 
  onClose: () => void; 
  onConnect: (data: any) => void; 
}) {
  const [isEnvLoading, setIsEnvLoading] = useState(false);
  const { addLog } = useLogs();
  const { register, handleSubmit, formState: { errors, isSubmitting } } = useForm({
    resolver: zodResolver(configSchema),
    defaultValues: {
      postgresUrl: 'localhost:5432',
      pgCacheUrl: 'localhost:6432',
      database: '',
      user: '',
      password: ''
    }
  });

  if (!isOpen) return null;

  const onSubmit = async (data: any) => {
    try {
      addLog('info', 'Attempting to connect with provided credentials...');
      const res = await fetch('/api/connect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
      });
      const result = await res.json();
      if (res.ok && result.success) {
        addLog('success', 'Successfully connected to databases');
        onConnect(result.config);
        onClose();
      } else {
        const errorMsg = result.error || 'Failed to connect to databases';
        addLog('error', 'Connection failed', errorMsg);
        alert(errorMsg);
      }
    } catch (e: any) {
      addLog('error', 'Error connecting to databases', e.message || String(e));
      alert('Error connecting to databases');
    }
  };

  const handleUseEnv = async () => {
    setIsEnvLoading(true);
    try {
      addLog('info', 'Attempting to connect using .env variables...');
      const res = await fetch('/api/connect', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ useEnv: true }),
      });
      const result = await res.json();
      if (res.ok && result.success) {
        addLog('success', 'Successfully connected to databases using .env variables');
        onConnect(result.config);
        onClose();
      } else {
        const errorMsg = result.error || 'Failed to connect using .env variables';
        addLog('error', 'Connection failed', errorMsg);
        alert(errorMsg);
      }
    } catch (e: any) {
      addLog('error', 'Error connecting using .env variables', e.message || String(e));
      alert('Error connecting using .env variables');
    } finally {
      setIsEnvLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-2xl shadow-xl w-full max-w-md relative overflow-hidden">
        <div className="flex justify-between items-center p-6 border-b border-zinc-100">
          <h2 className="text-xl font-bold text-zinc-900">Database Connection</h2>
          <button onClick={onClose} className="text-zinc-400 hover:text-zinc-600">
            <X size={20} />
          </button>
        </div>
        
        <form onSubmit={handleSubmit(onSubmit)} className="p-6 space-y-5">
          <div className="space-y-4">
            <div>
              <label className="block text-xs font-semibold text-zinc-600 uppercase tracking-wider mb-1">Database URL</label>
              <input {...register('postgresUrl')} placeholder="host:port" className="w-full border border-zinc-200 rounded-lg p-2.5 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
            </div>
            <div>
              <label className="block text-xs font-semibold text-zinc-600 uppercase tracking-wider mb-1">pgCache URL</label>
              <input {...register('pgCacheUrl')} placeholder="host:port" className="w-full border border-zinc-200 rounded-lg p-2.5 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
            </div>
            <div>
              <label className="block text-xs font-semibold text-zinc-600 uppercase tracking-wider mb-1">Database</label>
              <input {...register('database')} placeholder="Database Name" className="w-full border border-zinc-200 rounded-lg p-2.5 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
            </div>
            <div>
              <label className="block text-xs font-semibold text-zinc-600 uppercase tracking-wider mb-1">User</label>
              <input {...register('user')} placeholder="Username" className="w-full border border-zinc-200 rounded-lg p-2.5 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
            </div>
            <div>
              <label className="block text-xs font-semibold text-zinc-600 uppercase tracking-wider mb-1">Password</label>
              <input {...register('password')} type="password" placeholder="Password" className="w-full border border-zinc-200 rounded-lg p-2.5 text-sm focus:ring-2 focus:ring-emerald-500 outline-none" />
            </div>
          </div>

          <div className="pt-2 flex flex-col gap-3">
            <button type="submit" disabled={isSubmitting || isEnvLoading} className="w-full bg-emerald-600 text-white font-semibold py-2.5 rounded-lg hover:bg-emerald-700 transition disabled:opacity-50 flex items-center justify-center gap-2">
              {isSubmitting && <div className="w-4 h-4 border-2 border-emerald-300 border-t-white rounded-full animate-spin"></div>}
              {isSubmitting ? 'Connecting...' : 'Connect'}
            </button>
            <div className="relative flex items-center py-2">
              <div className="flex-grow border-t border-zinc-200"></div>
              <span className="flex-shrink-0 mx-4 text-zinc-400 text-sm">or</span>
              <div className="flex-grow border-t border-zinc-200"></div>
            </div>
            <button type="button" onClick={handleUseEnv} disabled={isEnvLoading || isSubmitting} className="w-full bg-zinc-100 text-zinc-700 font-semibold py-2.5 rounded-lg hover:bg-zinc-200 transition disabled:opacity-50 flex items-center justify-center gap-2">
              {isEnvLoading && <div className="w-4 h-4 border-2 border-zinc-300 border-t-zinc-600 rounded-full animate-spin"></div>}
              {isEnvLoading ? 'Connecting...' : 'Use .env Variables'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
