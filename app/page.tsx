'use client';
import {useEffect,useMemo,useState} from 'react';
import {createClient,Session} from '@supabase/supabase-js';

type Role='admin'|'coordinator'|'trainer'|'viewer';
type Request={id:string;agency_name:string|null;preferred_date:string|null;confirmed_date:string|null;status:string|null;class_status:string|null;assigned_trainer_id:string|null;};
type AdminSystemStatus={app?:{version?:string|null;release_date?:string|null};communications?:{email_delivery_enabled?:boolean;webhook_enabled?:boolean;tracking_enabled?:boolean;email_delivery_cron_active?:boolean};queue?:{protected_expected?:number;protected_present?:number;delete_guard_installed?:boolean};};
type VersionRow={id:number;version:string|null;release_date:string|null;title:string|null;is_current:boolean|null;};
type BugSummary={id:string;source:string;component:string;summary:string;status:string;created_at:string;};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const closed=new Set(['completed','closed','archived','cancelled','finalized']);

export default function Home(){
 const [session,setSession]=useState<Session|null>(null);const [role,setRole]=useState<Role|null>(null);const [requests,setRequests]=useState<Request[]>([]);const [activeAgencyCount,setActiveAgencyCount]=useState(0);
 const [email,setEmail]=useState('');const [password,setPassword]=useState('');const [error,setError]=useState('');const [loading,setLoading]=useState(false);
 const [systemStatus,setSystemStatus]=useState<AdminSystemStatus|null>(null);const [versions,setVersions]=useState<VersionRow[]>([]);const [bugs,setBugs]=useState<BugSummary[]>([]);const [bugActionCount,setBugActionCount]=useState(0);const [adminOverviewError,setAdminOverviewError]=useState('');const [adminLoading,setAdminLoading]=useState(false);

 useEffect(()=>{supabase.auth.getSession().then(({data})=>{setSession(data.session);if(data.session?.user)void loadProfile(data.session.user.id)});const {data}=supabase.auth.onAuthStateChange((_e,next)=>{setSession(next);if(next?.user)void loadProfile(next.user.id);else setRole(null)});return()=>data.subscription.unsubscribe()},[]);
 async function loadProfile(id:string){const {data,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',id).maybeSingle();if(profileError||!data?.active){setRole(null);setError(profileError?.message||'Your Backtrace account is not active.');return;}setRole((data.role as Role)||null)}
 useEffect(()=>{if(session)void loadDashboard()},[session]);
 useEffect(()=>{if(session&&role==='admin')void loadAdminOverview()},[session,role]);

 async function loadDashboard(){const [requestResult,agencyResult]=await Promise.all([supabase.from('training_requests').select('id,agency_name,preferred_date,confirmed_date,status,class_status,assigned_trainer_id').is('archived_at',null).order('confirmed_date',{ascending:true,nullsFirst:false}),supabase.from('agencies').select('id',{count:'exact',head:true}).eq('active',true)]);if(requestResult.error||agencyResult.error)setError(requestResult.error?.message||agencyResult.error?.message||'Unable to load dashboard.');else{setRequests(requestResult.data??[]);setActiveAgencyCount(agencyResult.count??0);}}
 async function loadAdminOverview(){setAdminLoading(true);setAdminOverviewError('');const [statusResult,versionResult,bugResult,bugCountResult]=await Promise.all([supabase.rpc('get_training_system_status'),supabase.from('training_app_versions').select('id,version,release_date,title,is_current').order('release_date',{ascending:false}).limit(3),supabase.from('training_bug_reports').select('id,source,component,summary,status,created_at').order('created_at',{ascending:false}).limit(5),supabase.from('training_bug_reports').select('id',{count:'exact',head:true}).in('status',['Open','In Review'])]);const message=statusResult.error?.message||versionResult.error?.message||bugResult.error?.message||bugCountResult.error?.message||'';if(message)setAdminOverviewError(message);else{setSystemStatus((statusResult.data||{}) as AdminSystemStatus);setVersions((versionResult.data||[]) as VersionRow[]);setBugs((bugResult.data||[]) as BugSummary[]);setBugActionCount(bugCountResult.count??0);}setAdminLoading(false);}
 async function signIn(){setLoading(true);setError('');const {data,error}=await supabase.auth.signInWithPassword({email,password});if(error)setError(error.message);else{setSession(data.session);if(data.user)void loadProfile(data.user.id)}setLoading(false)}

 const open=useMemo(()=>requests.filter(r=>!closed.has((r.status||r.class_status||'').toLowerCase())),[requests]);
 const upcoming=useMemo(()=>{const now=new Date(),end=new Date(now);end.setDate(end.getDate()+30);return open.filter(r=>r.confirmed_date&&new Date(r.confirmed_date+'T12:00:00')>=now&&new Date(r.confirmed_date+'T12:00:00')<=end)},[open]);
 const currentVersion=versions.find(v=>v.is_current)||versions[0];
 const previousVersion=versions.find(v=>v.id!==currentVersion?.id);
 const protectedExpected=Number(systemStatus?.queue?.protected_expected||26),protectedPresent=Number(systemStatus?.queue?.protected_present||0);
 const communicationsSafe=systemStatus?[
   systemStatus.communications?.email_delivery_enabled,
   systemStatus.communications?.webhook_enabled,
   systemStatus.communications?.tracking_enabled,
   systemStatus.communications?.email_delivery_cron_active
 ].every(value=>value===false):false;

 if(!session)return <main className="auth-screen"><section className="auth-card"><div className="eyebrow">BACKTRACE</div><h1>Training Administration</h1><p>Sign in to continue.</p><input placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={loading||!email||!password} onClick={()=>void signIn()}>{loading?'Signing in…':'Sign In'}</button>{error&&<p className="error">{error}</p>}</section></main>;

 return <main className="app-shell"><section className="dashboard"><h1>Training Administration Dashboard</h1><p className="lead">Shared operational view of requests, scheduling, agencies and training activity.</p>
 <div className="metrics"><div><label>OPEN REQUESTS</label><strong>{open.length}</strong></div><div><label>RECEIVED</label><strong>{requests.length}</strong></div><div><label>UPCOMING 30 DAYS</label><strong>{upcoming.length}</strong></div><div><label>UNASSIGNED</label><strong>{open.filter(r=>!r.assigned_trainer_id).length}</strong></div><div><label>ACTIVE AGENCIES</label><strong>{activeAgencyCount}</strong></div></div>
 <div className="dashboard-columns"><section className="dashboard-panel"><h2>Upcoming Training</h2>{upcoming.length?<div className="upcoming-list">{upcoming.map(r=><div className="upcoming-row" key={r.id}><strong>{r.confirmed_date}</strong><span>{r.agency_name||'Agency not specified'}</span></div>)}</div>:<p className="empty-state">No upcoming training in the next 30 days.</p>}</section><section className="dashboard-panel"><h2>Quick Actions</h2><div className="quick-grid">{[['Today','Open Today','/today'],['Requests','Open Requests','/requests'],['Attendance','Open Attendance','/classes'],['Attendees','Open Attendees','/attendees'],['Agency History','Open Agency History','/agency-history'],['Completion','Open Completion','/completions']].map(([a,b,c])=><a href={c} key={a}><strong>{a}</strong><span>{b}</span></a>)}</div></section></div>

 {role==='admin'&&<section className="dashboard-admin-overview"><div className="dashboard-admin-heading"><div><span>ADMINISTRATOR OVERVIEW</span><h2>Operational Status & Release Visibility</h2><p>Read-only production safety, release lineage and submitted issue summary.</p></div><button disabled={adminLoading} onClick={()=>void loadAdminOverview()}>{adminLoading?'Refreshing…':'Refresh Overview'}</button></div>{adminOverviewError&&<p className="error">{adminOverviewError}</p>}
 <div className="dashboard-admin-grid">
   <article className="dashboard-admin-card"><div className="dashboard-admin-card-head"><div><span>SYSTEM STATUS</span><h3>Production safeguards</h3></div><a href="/health">Open</a></div><div className="dashboard-status-facts"><div><span>Current Version</span><strong>v{systemStatus?.app?.version||'—'}</strong></div><div><span>Release Writes</span><strong>OFF</strong></div><div><span>Communications</span><strong className={communicationsSafe?'good':'warn'}>{communicationsSafe?'SAFE / OFF':'REVIEW'}</strong></div><div><span>Queue Guard</span><strong className={systemStatus?.queue?.delete_guard_installed?'good':'warn'}>{systemStatus?.queue?.delete_guard_installed?'ON':'CHECK'}</strong></div></div><div className={protectedPresent===protectedExpected?'dashboard-backlog-ok':'dashboard-backlog-warning'}><strong>Protected Email Backlog: {protectedPresent} / {protectedExpected}</strong><span>{protectedPresent===protectedExpected?'Protected backlog present.':'Recovery required — email delivery must remain OFF.'}</span></div></article>

   <article className="dashboard-admin-card"><div className="dashboard-admin-card-head"><div><span>RELEASE HISTORY</span><h3>Deployment lineage</h3></div><a href="/version-history">Open</a></div><div className="dashboard-release-list">{currentVersion?<div><span>Current Release</span><strong>v{currentVersion.version||'—'} · {currentVersion.title||'Release'}</strong><small>{currentVersion.release_date||'Date unavailable'}</small></div>:<p>No release history loaded.</p>}{previousVersion&&<div><span>Previous Release</span><strong>v{previousVersion.version||'—'} · {previousVersion.title||'Release'}</strong><small>{previousVersion.release_date||'Date unavailable'}</small></div>}<div><span>Environment</span><strong>Production · Vercel</strong><small>GitHub + Vercel + Supabase only</small></div></div></article>

   <article className="dashboard-admin-card dashboard-bug-card"><div className="dashboard-admin-card-head"><div><span>BUG REPORTS</span><h3>{bugActionCount} need action</h3></div><a href="/bug-reports">Open</a></div>{bugs.length?<div className="dashboard-bug-list">{bugs.map(b=><a href="/bug-reports" key={b.id}><strong>{b.summary}</strong><span>{b.component} · {b.source} · {b.status}</span><small>{new Date(b.created_at).toLocaleString()}</small></a>)}</div>:<p className="empty-state">No bug reports loaded.</p>}</article>
 </div></section>}
 </section><a className="report-problem" href="/report-problem">Report a Problem</a></main>;
}
