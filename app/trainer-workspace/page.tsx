'use client';

import {useEffect,useMemo,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';

type Role='admin'|'trainer'|'viewer';
type Profile={role:Role;active:boolean;};
type Request={request_number:string|null;agency_name:string|null;requested_by:string|null;preferred_date:string|null;training_format:string|null;status:string|null;class_status:string|null;assigned_trainer_id:string|null;created_by:string|null;};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function TrainerWorkspace(){
  const [user,setUser]=useState<User|null>(null);
  const [role,setRole]=useState<Role|null>(null);
  const [rows,setRows]=useState<Request[]>([]);
  const [loading,setLoading]=useState(true);
  const [error,setError]=useState('');
  const [search,setSearch]=useState('');
  const [status,setStatus]=useState('All statuses');

  useEffect(()=>{load();},[]);
  async function load(){
    setLoading(true);setError('');
    const {data:auth}=await supabase.auth.getUser();
    if(!auth.user){setError('Sign in is required.');setLoading(false);return;}
    setUser(auth.user);
    const {data:profile,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',auth.user.id).maybeSingle();
    if(profileError||!profile?.active){setError(profileError?.message||'An active account is required.');setLoading(false);return;}
    setRole(profile.role as Role);
    let query=supabase.from('training_requests').select('request_number,agency_name,requested_by,preferred_date,training_format,status,class_status,assigned_trainer_id,created_by').order('created_at',{ascending:false});
    if(profile.role==='trainer')query=query.or('assigned_trainer_id.eq.'+auth.user.id+',created_by.eq.'+auth.user.id);
    const {data,error:requestError}=await query;
    if(requestError)setError(requestError.message);else setRows(data??[]);
    setLoading(false);
  }
  const statuses=useMemo(()=>['All statuses',...Array.from(new Set(rows.flatMap(row=>[row.status,row.class_status]).filter((value):value is string=>Boolean(value)))).sort()],[rows]);
  const filtered=useMemo(()=>{const term=search.trim().toLowerCase();return rows.filter(row=>{const text=[row.request_number,row.agency_name,row.requested_by,row.preferred_date,row.training_format,row.status,row.class_status].filter(Boolean).join(' ').toLowerCase();return (status==='All statuses'||row.status===status||row.class_status===status)&&(!term||text.includes(term));});},[rows,search,status]);
  if(loading)return <main className="shell"><section className="card"><h1>Trainer Workspace</h1><p>Loading assigned requests…</p></section></main>;
  if(error)return <main className="shell"><section className="card"><h1>Trainer Workspace</h1><p>{error}</p><a href="/">Return to dashboard</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Trainer Workspace</div><div className="subtitle">{role==='admin'?'Administrator overview':'Requests assigned to your account'}</div></div><a href="/">Back to dashboard</a></header><section className="grid"><div className="metric">Visible requests<strong>{rows.length}</strong></div><div className="metric">Open requests<strong>{rows.filter(row=>!['completed','closed','archived','cancelled','finalized'].includes((row.status||'').toLowerCase())).length}</strong></div></section><section className="card" style={{marginTop:20}}><h2>{role==='admin'?'All training requests':'My training requests'}</h2><div className="controls"><input aria-label="Search workspace requests" placeholder="Search request, agency, requester, format, or status" value={search} onChange={event=>setSearch(event.target.value)}/><select aria-label="Filter workspace requests by status" value={status} onChange={event=>setStatus(event.target.value)}>{statuses.map(value=><option key={value}>{value}</option>)}</select></div><button onClick={load}>Refresh requests</button>{filtered.length===0?<p>No requests match the current view.</p>:<table className="table"><thead><tr><th>Request</th><th>Agency</th><th>Requester</th><th>Preferred date</th><th>Format</th><th>Status</th></tr></thead><tbody>{filtered.map((row,index)=><tr key={row.request_number||index}><td>{row.request_number||'—'}</td><td>{row.agency_name||'—'}</td><td>{row.requested_by||'—'}</td><td>{row.preferred_date||'—'}</td><td>{row.training_format||'—'}</td><td><span className="pill">{row.status||row.class_status||'—'}</span></td></tr>)}</tbody></table>}</section></main>;
}
