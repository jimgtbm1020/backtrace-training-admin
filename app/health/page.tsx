'use client';

import {useEffect,useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type SystemStatus={
  app?:{version?:string|null;release_date?:string|null};
  communications?:{
    email_delivery_enabled?:boolean;
    webhook_enabled?:boolean;
    tracking_enabled?:boolean;
    email_delivery_cron_active?:boolean;
  };
  queue?:{
    total?:number;
    pending?:number;
  };
  jobs?:{
    auto_close_active?:boolean;
    reminders_active?:boolean;
    session_expiration_active?:boolean;
  };
};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const checks=[['training_attendees','Attendee directory'],['training_requests','Training requests'],['training_attendance_sessions','Classes and attendance'],['training_completion_records','Completion records'],['agencies','Agency directory'],['training_notifications','Notifications']] as const;

function stateClass(ok:boolean){return ok?'system-state-ok':'system-state-warning'}
function OnOff({value,healthyWhen=false}:{value:boolean|undefined;healthyWhen?:boolean}){const healthy=Boolean(value)===healthyWhen;return <span className={'system-state '+stateClass(healthy)}>{value?'ON':'OFF'}</span>}

export default function HealthPage(){
  const [status,setStatus]=useState<SystemStatus|null>(null);
  const [results,setResults]=useState<Record<string,string>>({});
  const [loadingStatus,setLoadingStatus]=useState(true);
  const [loadingChecks,setLoadingChecks]=useState(false);
  const [error,setError]=useState('');

  useEffect(()=>{void initialize()},[]);

  async function initialize(){
    setLoadingStatus(true);setError('');
    const {data:auth}=await supabase.auth.getUser();
    if(!auth.user){setError('Administrator sign-in is required.');setLoadingStatus(false);return;}
    const {data:profile,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',auth.user.id).maybeSingle();
    if(profileError||profile?.role!=='admin'||!profile.active){setError(profileError?.message||'Administrator access is required.');setLoadingStatus(false);return;}
    const {data,error:statusError}=await supabase.rpc('get_training_system_status');
    if(statusError)setError(statusError.message);else setStatus((data||{}) as SystemStatus);
    setLoadingStatus(false);
  }

  async function runChecks(){
    setLoadingChecks(true);setError('');setResults({});
    const {data:auth}=await supabase.auth.getUser();
    if(!auth.user){setError('Administrator sign-in is required.');setLoadingChecks(false);return;}
    const {data:profile,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',auth.user.id).maybeSingle();
    if(profileError||profile?.role!=='admin'||!profile.active){setError(profileError?.message||'Administrator access is required.');setLoadingChecks(false);return;}
    const next:Record<string,string>={authentication:'Passed'};
    for(const [table] of checks){
      const {error}=await supabase.from(table).select('*',{count:'exact',head:true});
      next[table]=error?'Failed: '+error.message:'Passed';
    }
    setResults(next);setLoadingChecks(false);
  }

  const passed=Object.values(results).filter(value=>value==='Passed').length;

  if(loadingStatus)return <main className="shell"><section className="card"><h1>System Status</h1><p>Checking Administrator access and protected system state…</p></section></main>;
  if(error&&!status)return <main className="shell"><section className="card"><h1>System Status</h1><p className="error">{error}</p><a href="/">Return to dashboard</a></section></main>;

  return <main className="shell system-status-page">
    <header className="legacy-page-header">
      <div><h1>System Status</h1><p>Read-only release, communications, queue-protection and connectivity visibility.</p></div>
      <button disabled={loadingStatus} onClick={()=>void initialize()}>{loadingStatus?'Refreshing…':'Refresh Status'}</button>
    </header>

    <section className="system-status-banner">
      <div><strong>Protected production mode</strong><span>This page cannot enable releases, email delivery, webhooks or tracking.</span></div>
      <span className="system-state system-state-ok">READ ONLY</span>
    </section>

    <section className="system-status-grid">
      <article className="system-status-card"><span>Training Administration</span><strong>v{status?.app?.version||'—'}</strong><small>{status?.app?.release_date?'Current release · '+new Date(status.app.release_date+'T12:00:00').toLocaleDateString():'Current release'}</small></article>
      <article className="system-status-card"><span>Architecture</span><strong className="system-card-text">GitHub + Vercel + Supabase</strong><small>No AppDeploy</small></article>
      <article className="system-status-card"><span>Release Writes</span><strong>OFF</strong><small>Protected operating policy</small></article>
      <article className="system-status-card"><span>Attendance</span><strong className="system-card-text">READY</strong><small><a href="https://backtrace-training-attendance.vercel.app" target="_blank" rel="noreferrer">Open protected Attendance alias</a></small></article>
    </section>

    <section className="protected-backlog-warning resolved">
      <div>
        <span>Email Queue</span>
        <strong>{status?.queue?.total??0} queued record{(status?.queue?.total??0)===1?'':'s'} · {status?.queue?.pending??0} pending</strong>
        <p>{(status?.queue?.total??0)===0?'Demo email records were intentionally removed. The queue is currently empty.':'Queued records are retained for review while automatic email delivery remains disabled.'}</p>
      </div>
      <span className="system-state system-state-ok">{(status?.queue?.total??0)===0?'EMPTY':'REVIEW'}</span>
    </section>

    <section className="legacy-panel">
      <div className="panel-heading"><div><h2>Communications Safety</h2><span>Live database state</span></div></div>
      <div className="system-safety-grid">
        <div><span>Email Delivery</span><OnOff value={status?.communications?.email_delivery_enabled}/><small>Must remain OFF</small></div>
        <div><span>Webhooks</span><OnOff value={status?.communications?.webhook_enabled}/><small>Must remain OFF</small></div>
        <div><span>Tracking</span><OnOff value={status?.communications?.tracking_enabled}/><small>Must remain OFF</small></div>
        <div><span>Email Delivery Cron</span><OnOff value={status?.communications?.email_delivery_cron_active}/><small>Must remain OFF</small></div>
        <div><span>Queue Rows</span><strong>{status?.queue?.total??0}</strong><small>{status?.queue?.pending??0} pending</small></div>
        <div><span>Demo Email Cleanup</span><strong>{(status?.queue?.total??0)===0?'Complete':'Review'}</strong><small>Intentional demo records removed</small></div>
      </div>
    </section>

    <section className="legacy-panel">
      <div className="panel-heading"><div><h2>Background Safety Jobs</h2><span>Non-email operational automation</span></div></div>
      <div className="system-jobs-grid">
        <div><span>Auto-Close Expired Classes</span><OnOff value={status?.jobs?.auto_close_active} healthyWhen={true}/></div>
        <div><span>In-App Reminders</span><OnOff value={status?.jobs?.reminders_active} healthyWhen={true}/></div>
        <div><span>Attendance Session Expiration</span><OnOff value={status?.jobs?.session_expiration_active} healthyWhen={true}/></div>
      </div>
    </section>

    <section className="legacy-panel">
      <div className="panel-heading"><div><h2>Connectivity Checks</h2><span>Manual read-only table access verification</span></div><button disabled={loadingChecks} onClick={()=>void runChecks()}>{loadingChecks?'Checking…':'Run Health Checks'}</button></div>
      <p>These checks perform read-only HEAD/count requests. They do not modify records or trigger communications.</p>
      {error&&<p className="error" role="alert">{error}</p>}
      {Object.keys(results).length>0&&<><p>{passed} of {checks.length+1} checks passed.</p><div className="table-wrap"><table className="table"><thead><tr><th>Check</th><th>Result</th></tr></thead><tbody><tr><td>Administrator authentication</td><td><span className="pill">{results.authentication}</span></td></tr>{checks.map(([table,label])=><tr key={table}><td>{label}</td><td><span className="pill">{results[table]}</span></td></tr>)}</tbody></table></div></>}
    </section>
  </main>;
}
