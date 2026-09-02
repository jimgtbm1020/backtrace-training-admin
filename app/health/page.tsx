'use client';

import {useState} from 'react';
import {createClient} from '@supabase/supabase-js';

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const checks=[['training_attendees','Attendee directory'],['training_requests','Training requests'],['training_attendance_sessions','Classes and attendance'],['training_completion_records','Completion records'],['agencies','Agency directory'],['training_notifications','Notifications']] as const;

export default function HealthPage(){
  const [results,setResults]=useState<Record<string,string>>({});const [loading,setLoading]=useState(false);const [error,setError]=useState('');
  async function run(){setLoading(true);setError('');setResults({});const {data:auth}=await supabase.auth.getSession();if(!auth.session){setError('Administrator sign-in is required.');setLoading(false);return;}const next:Record<string,string>={authentication:'Passed'};for(const [table] of checks){const {error}=await supabase.from(table).select('*',{count:'exact',head:true});next[table]=error?'Failed: '+error.message:'Passed';}setResults(next);setLoading(false);}
  const passed=Object.values(results).filter(value=>value==='Passed').length;
  return <main className="shell"><header className="header"><div><div className="brand">System Health</div><div className="subtitle">Read-only connectivity and access checks</div></div><a href="/">Back to dashboard</a></header><section className="card"><p>These checks do not change records, send notifications, or enable release actions.</p><button disabled={loading} onClick={run}>{loading?'Checking…':'Run health checks'}</button>{error&&<p>{error}</p>}{Object.keys(results).length>0&&<><h2>Results</h2><p>{passed} of {checks.length+1} checks passed.</p><table className="table"><thead><tr><th>Check</th><th>Result</th></tr></thead><tbody><tr><td>Administrator authentication</td><td><span className="pill">{results.authentication}</span></td></tr>{checks.map(([table,label])=><tr key={table}><td>{label}</td><td><span className="pill">{results[table]}</span></td></tr>)}</tbody></table></>}</section></main>;
}
