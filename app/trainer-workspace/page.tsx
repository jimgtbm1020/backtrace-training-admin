'use client';

import {useEffect,useMemo,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';

type Role='admin'|'coordinator'|'trainer'|'viewer';
type Profile={role:Role;active:boolean;};
type Request={id:string;confirmed_date:string|null;confirmed_start_time:string|null;trainer_response:'Pending'|'Accepted'|'Declined';trainer_decline_reason:string|null;teams_meeting_url:string|null;request_number:string|null;agency_name:string|null;requested_by:string|null;preferred_date:string|null;training_format:string|null;status:string|null;class_status:string|null;assigned_trainer_id:string|null;created_by:string|null;};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function TrainerWorkspace(){
  const [user,setUser]=useState<User|null>(null);
  const [role,setRole]=useState<Role|null>(null);
  const [rows,setRows]=useState<Request[]>([]);
  const [loading,setLoading]=useState(true);
  const [error,setError]=useState('');
  const [search,setSearch]=useState('');
  const [status,setStatus]=useState('All statuses');
  const [busy,setBusy]=useState<string|null>(null);
  const [message,setMessage]=useState('');
  const [teamsLinks,setTeamsLinks]=useState<Record<string,string>>({});
  const [declineReasons,setDeclineReasons]=useState<Record<string,string>>({});

  useEffect(()=>{load();},[]);
  async function load(){
    setLoading(true);setError('');
    const {data:auth}=await supabase.auth.getUser();
    if(!auth.user){setError('Sign in is required.');setLoading(false);return;}
    setUser(auth.user);
    const {data:profile,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',auth.user.id).maybeSingle();
    if(profileError||!profile?.active){setError(profileError?.message||'An active account is required.');setLoading(false);return;}
    setRole(profile.role as Role);
    let query=supabase.from('training_requests').select('id,request_number,agency_name,requested_by,preferred_date,confirmed_date,confirmed_start_time,training_format,status,class_status,assigned_trainer_id,created_by,trainer_response,trainer_decline_reason,teams_meeting_url').order('created_at',{ascending:false});
    if(profile.role==='trainer')query=query.or('assigned_trainer_id.eq.'+auth.user.id+',created_by.eq.'+auth.user.id);
    const {data,error:requestError}=await query;
    if(requestError)setError(requestError.message);else{setRows(data??[]);setTeamsLinks(Object.fromEntries((data??[]).map(row=>[row.id,row.teams_meeting_url||''])));}
    setLoading(false);
  }
  function isLocked(row:Request){return ['In Progress','Closed','Completed','Archived'].includes(row.class_status||'')||row.status==='Completed';}
  async function respond(row:Request,response:'Accepted'|'Declined'){
    if(response==='Declined'&&!declineReasons[row.id]?.trim()){setError('Enter a reason before declining.');return;}
    if(!window.confirm((response==='Accepted'?'Accept':'Decline')+' training request '+row.request_number+'?'))return;
    setBusy(row.id);setError('');setMessage('');
    try{
      const {error:responseError}=await supabase.rpc('respond_to_training_assignment',{p_request_id:row.id,p_response:response,p_reason:response==='Declined'?declineReasons[row.id].trim():null});
      if(responseError){setError(responseError.message);return;}
      await load();setMessage('Training request '+response.toLowerCase()+'.');
    }catch(e){setError(e instanceof Error?e.message:'Unable to save your response.');}finally{setBusy(null);}
  }
  async function saveTeams(row:Request){
    setBusy(row.id);setError('');setMessage('');
    try{
      const {error:teamsError}=await supabase.rpc('set_training_request_teams_link',{p_request_id:row.id,p_url:teamsLinks[row.id]||''});
      if(teamsError){setError(teamsError.message);return;}
      await load();setMessage('Microsoft Teams meeting link saved.');
    }catch(e){setError(e instanceof Error?e.message:'Unable to save the Teams link.');}finally{setBusy(null);}
  }
  function downloadCsv(){const header=['Request','Agency','Requester','Preferred date','Format','Status'];const lines=filtered.map(row=>[row.request_number,row.agency_name,row.requested_by,row.preferred_date,row.training_format,row.status||row.class_status].map(value=>'\"'+String(value??'').replaceAll('\"','\"\"')+'\"').join(','));const blob=new Blob([[header.join(','),...lines].join('\\n')],{type:'text/csv;charset=utf-8'});const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download='trainer-workspace.csv';link.click();URL.revokeObjectURL(url);}
  const statuses=useMemo(()=>['All statuses',...Array.from(new Set(rows.flatMap(row=>[row.status,row.class_status]).filter((value):value is string=>Boolean(value)))).sort()],[rows]);
  const filtered=useMemo(()=>{const term=search.trim().toLowerCase();return rows.filter(row=>{const text=[row.request_number,row.agency_name,row.requested_by,row.preferred_date,row.training_format,row.status,row.class_status].filter(Boolean).join(' ').toLowerCase();return (status==='All statuses'||row.status===status||row.class_status===status)&&(!term||text.includes(term));});},[rows,search,status]);
  if(loading)return <main className="shell"><section className="card"><h1>Trainer Workspace</h1><p>Loading assigned requests…</p></section></main>;
  if(error&&!user)return <main className="shell"><section className="card"><h1>Trainer Workspace</h1><p>{error}</p><a href="/">Return to dashboard</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Trainer Workspace</div><div className="subtitle">{role==='admin'||role==='coordinator'?'Administration overview':'Requests assigned to your account'}</div></div><a href="/">Back to dashboard</a></header><section className="grid"><div className="metric">Visible requests<strong>{rows.length}</strong></div><div className="metric">Open requests<strong>{rows.filter(row=>!['completed','closed','archived','cancelled','finalized'].includes((row.status||'').toLowerCase())).length}</strong></div></section><section className="card" style={{marginTop:20}}><h2>{role==='admin'||role==='coordinator'?'All training requests':'My training requests'}</h2>{error&&<p className="error" role="alert">{error}</p>}{message&&<p role="status">{message}</p>}<div className="controls"><input aria-label="Search workspace requests" placeholder="Search request, agency, requester, format, or status" value={search} onChange={event=>setSearch(event.target.value)}/><select aria-label="Filter workspace requests by status" value={status} onChange={event=>setStatus(event.target.value)}>{statuses.map(value=><option key={value}>{value}</option>)}</select></div><button onClick={load}>Refresh requests</button><button disabled={!filtered.length} onClick={downloadCsv}>Download CSV</button>{filtered.length===0?<p>No requests match the current view.</p>:<table className="table"><thead><tr><th>Request</th><th>Agency</th><th>Requester</th><th>Training date</th><th>Format</th><th>Status</th><th>Trainer Response</th><th>Actions / Teams Meeting</th></tr></thead><tbody>{filtered.map((row,index)=><tr key={row.id||index}><td>{row.request_number||'—'}</td><td>{row.agency_name||'—'}</td><td>{row.requested_by||'—'}</td><td>{row.confirmed_date||row.preferred_date||'—'}{row.confirmed_start_time?' · '+row.confirmed_start_time.slice(0,5):''}</td><td>{row.training_format||'—'}</td><td><span className="pill">{row.status||row.class_status||'—'}</span></td><td><span className="pill">{row.assigned_trainer_id?row.trainer_response:'Unassigned'}</span>{row.trainer_decline_reason&&<p>{row.trainer_decline_reason}</p>}</td><td>{role==='trainer'&&row.assigned_trainer_id===user?.id&&!isLocked(row)&&row.trainer_response==='Pending'&&<div className="controls"><button disabled={busy!==null} onClick={()=>void respond(row,'Accepted')}>Accept</button>{row.class_status!=='Registration Open'&&<><label>Decline reason<input aria-label={'Decline reason for '+row.request_number} maxLength={1000} value={declineReasons[row.id]||''} onChange={event=>setDeclineReasons(current=>({...current,[row.id]:event.target.value}))}/></label><button disabled={busy!==null} onClick={()=>void respond(row,'Declined')}>Decline</button></>}</div>}{role==='trainer'&&row.assigned_trainer_id===user?.id&&!isLocked(row)&&row.trainer_response==='Accepted'&&['Virtual','Hybrid'].includes(row.training_format||'')&&<div className="controls"><label>Microsoft Teams Meeting Link<input type="url" aria-label={'Microsoft Teams Meeting Link for '+row.request_number} placeholder="https://teams.microsoft.com/..." value={teamsLinks[row.id]||''} onChange={event=>setTeamsLinks(current=>({...current,[row.id]:event.target.value}))}/></label><button disabled={busy!==null} onClick={()=>void saveTeams(row)}>Save Teams Link</button></div>}{row.teams_meeting_url&&<a href={row.teams_meeting_url} target="_blank" rel="noreferrer">Open Teams Meeting</a>}{(role==='admin'||role==='coordinator')&&<a href={'/requests/edit?request='+row.id}>Manage Request</a>}</td></tr>)}</tbody></table>}</section></main>;
}
