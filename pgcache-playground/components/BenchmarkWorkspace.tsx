'use client';

import { useState } from 'react';
import { Play, Settings2, BarChart2, Activity, Terminal } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { useLogs } from './LogProvider';
import LogViewer from './LogViewer';

export default function BenchmarkWorkspace({ config }: { config: any }) {
  const [query, setQuery] = useState('SELECT * FROM users LIMIT 100;');
  const [paramsList, setParamsList] = useState('[\n  { "id": 1 },\n  { "id": 2 }\n]');
  const [runs, setRuns] = useState(10);
  const [target, setTarget] = useState('both');
  const [isRunning, setIsRunning] = useState(false);
  const [results, setResults] = useState<{ postgresTimes: number[], pgCacheTimes: number[] } | null>(null);
  const [error, setError] = useState('');
  const [activeTab, setActiveTab] = useState<'chart' | 'logs'>('chart');
  const { addLog, logs } = useLogs();

  const handleRun = async () => {
    if (!config) {
      setError('Please connect to the databases first.');
      return;
    }

    setIsRunning(true);
    setError('');
    setResults(null);
    setActiveTab('chart');

    try {
      let parsedParams = [];
      try {
        parsedParams = JSON.parse(paramsList);
        if (!Array.isArray(parsedParams)) throw new Error('Params must be an array of objects');
        // Convert objects to arrays of values for pg
        parsedParams = parsedParams.map(p => typeof p === 'object' && p !== null ? Object.values(p) : p);
      } catch (e) {
        throw new Error('Invalid JSON format. Expected an array of objects.');
      }

      addLog('info', `Starting benchmark run (${runs} iterations per param set)`);

      const res = await fetch('/api/benchmark', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          config,
          query,
          paramsList: parsedParams,
          runs,
          target
        }),
      });

      const data = await res.json();
      if (res.ok) {
        setResults({ postgresTimes: data.postgresTimes, pgCacheTimes: data.pgCacheTimes });
        addLog('success', 'Benchmark completed successfully');
        
        // Log some basic stats
        if (data.postgresTimes && data.postgresTimes.length > 0) {
          const pgAvg = (data.postgresTimes.reduce((a: number, b: number) => a + b, 0) / data.postgresTimes.length).toFixed(2);
          addLog('info', `PostgreSQL average execution time: ${pgAvg}ms`);
        }
        if (data.pgCacheTimes && data.pgCacheTimes.length > 0) {
          const cacheAvg = (data.pgCacheTimes.reduce((a: number, b: number) => a + b, 0) / data.pgCacheTimes.length).toFixed(2);
          addLog('info', `pgCache average execution time: ${cacheAvg}ms`);
        }

      } else {
        const errorMsg = data.error || 'Benchmark failed';
        setError('An error occurred. Please check the logs for more details.');
        addLog('error', 'Benchmark execution failed', errorMsg);
        setActiveTab('logs');
      }
    } catch (e: any) {
      const errorMsg = e.message || 'An error occurred during benchmark';
      setError('An error occurred. Please check the logs for more details.');
      addLog('error', 'Benchmark execution failed', errorMsg);
      setActiveTab('logs');
    } finally {
      setIsRunning(false);
    }
  };

  const calculateStats = (times: number[]) => {
    if (!times || times.length === 0) return { mean: '0.00', median: '0.00', stdDev: '0.00', min: '0.00', max: '0.00' };
    const sorted = [...times].sort((a, b) => a - b);
    const sum = sorted.reduce((a, b) => a + b, 0);
    const mean = sum / sorted.length;
    const mid = Math.floor(sorted.length / 2);
    const median = sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    const stdDev = Math.sqrt(sorted.reduce((sq, n) => sq + Math.pow(n - mean, 2), 0) / (sorted.length - 1 || 1));
    return {
      mean: mean.toFixed(2),
      median: median.toFixed(2),
      stdDev: stdDev.toFixed(2),
      min: sorted[0].toFixed(2),
      max: sorted[sorted.length - 1].toFixed(2)
    };
  };

  const chartData = results ? Array.from({ length: Math.max(results.postgresTimes.length, results.pgCacheTimes.length) }).map((_, index) => {
    const data: any = { run: index + 1 };
    if (results.postgresTimes.length > 0) data.PostgreSQL = results.postgresTimes[index];
    if (results.pgCacheTimes.length > 0) data.pgCache = results.pgCacheTimes[index];
    return data;
  }) : [];

  const pgStats = results && results.postgresTimes.length > 0 ? calculateStats(results.postgresTimes) : null;
  const cacheStats = results && results.pgCacheTimes.length > 0 ? calculateStats(results.pgCacheTimes) : null;

  return (
    <div className="flex flex-col h-full gap-6">
      {/* Editor Section */}
      <div className="bg-white rounded-xl shadow-sm border border-zinc-200 flex flex-col overflow-hidden shrink-0">
        <div className="bg-zinc-50 border-b border-zinc-200 px-4 py-3 flex items-center justify-between">
          <div className="flex items-center gap-2 text-zinc-700 font-semibold text-sm">
            <Activity size={16} /> SQL Editor
          </div>
          <div className="flex items-center gap-3">
            <select 
              value={target}
              onChange={(e) => setTarget(e.target.value)}
              className="border border-zinc-200 rounded-md text-sm px-3 py-1.5 outline-none focus:ring-2 focus:ring-emerald-500 bg-white text-zinc-700"
            >
              <option value="both">Both (Postgres & pgCache)</option>
              <option value="postgres">PostgreSQL Only</option>
              <option value="pgcache">pgCache Only</option>
            </select>
            <button 
              onClick={handleRun}
              disabled={isRunning || !config}
              className="bg-emerald-600 hover:bg-emerald-700 disabled:opacity-50 text-white px-4 py-1.5 rounded-md text-sm font-medium flex items-center gap-2 transition"
            >
              <Play size={14} /> {isRunning ? 'Running...' : 'Run Benchmark'}
            </button>
          </div>
        </div>
        <div className="p-4 flex flex-col gap-4">
          <div className="flex flex-col">
            <label className="text-xs font-semibold text-zinc-500 uppercase mb-2">Query</label>
            <textarea 
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              className="w-full border border-zinc-200 rounded-lg p-3 font-mono text-sm focus:ring-2 focus:ring-emerald-500 outline-none resize-y min-h-[120px]"
              placeholder="SELECT * FROM users WHERE id = $1;"
            />
          </div>
          <div className="flex gap-4">
            <div className="flex-1 flex flex-col">
              <div className="flex justify-between items-end mb-2">
                <label className="text-xs font-semibold text-zinc-500 uppercase">Parameters (JSON Array of Objects)</label>
                <span className="text-[10px] text-zinc-400">Values are extracted in order (e.g. {"{"}"id": 1{"}"} maps to $1)</span>
              </div>
              <textarea 
                value={paramsList}
                onChange={(e) => setParamsList(e.target.value)}
                className="w-full border border-zinc-200 rounded-lg p-3 font-mono text-xs focus:ring-2 focus:ring-emerald-500 outline-none resize-y min-h-[100px]"
                placeholder="[\n  { &quot;id&quot;: 1 },\n  { &quot;id&quot;: 2 }\n]"
              />
            </div>
            <div className="w-32 flex flex-col">
              <label className="text-xs font-semibold text-zinc-500 uppercase mb-2">Runs per Param</label>
              <input 
                type="number"
                value={runs}
                onChange={(e) => setRuns(parseInt(e.target.value) || 1)}
                min="1"
                className="w-full border border-zinc-200 rounded-lg p-3 text-sm focus:ring-2 focus:ring-emerald-500 outline-none"
              />
            </div>
          </div>
        </div>
      </div>

      {/* Chart & Logs Section */}
      <div className="bg-white rounded-xl shadow-sm border border-zinc-200 flex flex-col overflow-hidden h-96 shrink-0">
        <div className="bg-zinc-50 border-b border-zinc-200 flex items-center text-sm">
          <button 
            onClick={() => setActiveTab('chart')}
            className={`px-4 py-3 flex items-center gap-2 font-semibold border-b-2 transition-colors ${activeTab === 'chart' ? 'border-emerald-500 text-emerald-600 bg-white' : 'border-transparent text-zinc-600 hover:text-zinc-800'}`}
          >
            <BarChart2 size={16} /> Performance Chart
          </button>
          <button 
            onClick={() => setActiveTab('logs')}
            className={`px-4 py-3 flex items-center gap-2 font-semibold border-b-2 transition-colors ${activeTab === 'logs' ? 'border-emerald-500 text-emerald-600 bg-white' : 'border-transparent text-zinc-600 hover:text-zinc-800'}`}
          >
            <Terminal size={16} /> Logs
            {logs.length > 0 && (
              <span className="bg-zinc-200 text-zinc-700 text-[10px] px-1.5 py-0.5 rounded-full font-mono">
                {logs.length}
              </span>
            )}
          </button>
        </div>
        <div className="p-4 flex-1 flex items-center justify-center relative overflow-hidden">
          {activeTab === 'chart' ? (
            <>
              {error && (
                <div className="absolute inset-0 bg-white/90 z-10 flex items-center justify-center p-6 text-center">
                  <p className="text-red-500 font-medium bg-red-50 px-4 py-2 rounded-lg border border-red-100">{error}</p>
                </div>
              )}
              
              {!results && !isRunning && !error && (
                <p className="text-zinc-400 text-sm">Run a benchmark to see results</p>
              )}
              
              {isRunning && (
                <div className="flex flex-col items-center gap-3 text-emerald-600">
                  <div className="w-8 h-8 border-4 border-emerald-200 border-t-emerald-600 rounded-full animate-spin"></div>
                  <p className="text-sm font-medium animate-pulse">Executing queries...</p>
                </div>
              )}
              
              {results && !isRunning && (
                <ResponsiveContainer width="100%" height="100%">
                  <LineChart data={chartData} margin={{ top: 10, right: 30, left: 0, bottom: 0 }}>
                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e4e4e7" />
                    <XAxis dataKey="run" tick={{fontSize: 12}} tickLine={false} axisLine={false} />
                    <YAxis tick={{fontSize: 12}} tickLine={false} axisLine={false} unit="ms" />
                    <Tooltip 
                      contentStyle={{ borderRadius: '8px', border: '1px solid #e4e4e7', boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)' }}
                      formatter={(value: any) => [`${Number(value).toFixed(2)} ms`]}
                    />
                    <Legend iconType="circle" wrapperStyle={{ fontSize: '12px', paddingTop: '10px' }} />
                    {pgStats && <Line type="monotone" dataKey="PostgreSQL" stroke="#3b82f6" strokeWidth={2} dot={false} activeDot={{ r: 4 }} />}
                    {cacheStats && <Line type="monotone" dataKey="pgCache" stroke="#10b981" strokeWidth={2} dot={false} activeDot={{ r: 4 }} />}
                  </LineChart>
                </ResponsiveContainer>
              )}
            </>
          ) : (
            <LogViewer />
          )}
        </div>
      </div>

      {/* Stats Section */}
      {results && (pgStats || cacheStats) && (
        <div className="bg-white rounded-xl shadow-sm border border-zinc-200 overflow-hidden shrink-0">
          <div className="bg-zinc-50 border-b border-zinc-200 px-4 py-3 flex items-center gap-2 text-zinc-700 font-semibold text-sm">
            <Settings2 size={16} /> Statistical Summary
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-sm">
              <thead className="bg-zinc-50/50 text-zinc-500 uppercase text-xs">
                <tr>
                  <th className="px-6 py-3 font-semibold">Metric</th>
                  {pgStats && <th className="px-6 py-3 font-semibold text-blue-600">PostgreSQL</th>}
                  {cacheStats && <th className="px-6 py-3 font-semibold text-emerald-600">pgCache</th>}
                  {pgStats && cacheStats && <th className="px-6 py-3 font-semibold">Difference</th>}
                </tr>
              </thead>
              <tbody className="divide-y divide-zinc-100">
                {[
                  { label: 'Mean Time', key: 'mean' },
                  { label: 'Median Time', key: 'median' },
                  { label: 'Min Time', key: 'min' },
                  { label: 'Max Time', key: 'max' },
                  { label: 'Std Deviation', key: 'stdDev' },
                ].map((row) => {
                  const pgVal = pgStats ? parseFloat(pgStats[row.key as keyof typeof pgStats]) : 0;
                  const cacheVal = cacheStats ? parseFloat(cacheStats[row.key as keyof typeof cacheStats]) : 0;
                  const diff = pgVal - cacheVal;
                  const percent = pgVal > 0 ? ((diff / pgVal) * 100).toFixed(1) : '0.0';
                  
                  return (
                    <tr key={row.key} className="hover:bg-zinc-50/50 transition">
                      <td className="px-6 py-3 font-medium text-zinc-700">{row.label}</td>
                      {pgStats && <td className="px-6 py-3 font-mono">{pgVal.toFixed(2)} ms</td>}
                      {cacheStats && <td className="px-6 py-3 font-mono">{cacheVal.toFixed(2)} ms</td>}
                      {pgStats && cacheStats && (
                        <td className="px-6 py-3 font-mono">
                          <span className={diff > 0 ? 'text-emerald-600' : diff < 0 ? 'text-red-500' : 'text-zinc-500'}>
                            {diff > 0 ? '-' : '+'}{Math.abs(diff).toFixed(2)} ms ({percent}%)
                          </span>
                        </td>
                      )}
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        </div>
      )}
    </div>
  );
}

