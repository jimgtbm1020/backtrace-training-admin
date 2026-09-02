'use client';

import {useMemo,useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type Request={request_number:string|null;agency_name:string|null;requested_by:string|null;preferred_date:string|null;training_format:string|null;status:string|null;class_status:string|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function TrainingRequestsPage(){
  const [rows,setRows]=useState<Request[]>([]);
  const [search,setSearch]=useState('');
  const [status,setStatus]=useState('All statuses');
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState('');
  async function load(){
    setLoading(true);setError('');
    const {data:session}=await supabase.auth.getSession();
    if(!session.session){setError('Administrator sign-in is required.');setLoading(false);return;}
    const {data,error}=await supabase.from('training_requests').select('request_number,agency_name,requested_by,preferred_date,training_format,status,class_status').order('created_at',{ascending:false});
    if(error)setError(error.message);else setRows(data??[]);
    setLoading(false);
  }
  const statuses=useMemo(()=>['All statuses',...Array.from(new Set(rows.flatMap(row=>[row.status,row.class_status]).filter((value):value is string=>Boolean(value)))).sort()],[rows]);
  const filtered=useMemo(()=>{const term=search.trim().toLowerCase();return rows.filter(row=>{const statusMatch=status==='All statuses'||row.status===status||row.class_status===status;const text=[row.request_number,row.agency_name,row.requested_by,row.preferred_date,row.training_format,row.status,row.class_status].filter(Boolean).join(' ').toLowerCase();return statusMatch&&(!term||text.includes(term));});},[rows,search,status]);
  return <main className="shell"><header className="header"><div><div className="brand">Training Requests</div><div className="subtitle">Review requests and open the guarded editor for eligible records</div></div><a href="/">Back to dashboard</a></header><section className="card"><div className="controls"><input aria-label="Search training requests" placeholder="Search request, agency, requester, date, or format" value={search} onChange={event=>setSearch(event.target.value)}/><select aria-label="Filter requests by status" value={status} onChange={event=>setStatus(event.target.value)}>{statuses.map(value=><option key={value}>{value}</option>)}</select><button disabled={loading} onClick={load}>{loading?'Loading…':'Load requests'}</button></div>{error&&<p>{error}</p>}{rows.length>0&&<p>Showing {filtered.length} of {rows.length} requests.</p>}{filtered.length>0&&<table className="table"><thead><tr><th>Request</th><th>Agency</th><th>Requester</th><th>Preferred date</th><th>Format</th><th>Status</th><th>Action</th></tr></thead><tbody>{filtered.map((row,index)=><tr key={row.request_number||index}><td>{row.request_number||'—'}</td><td>{row.agency_name||'—'}</td><td>{row.requested_by||'—'}</td><td>{row.preferred_date||'—'}</td><td>{row.training_format||'—'}</td><td><span className="pill">{row.status||row.class_status||'Open'}</span></td><td><a href="/requests/edit">Open editor</a></td></tr>)}</tbody></table>}{rows.length>0&&!filtered.length&&<p>No requests match the current filters.</p>}{!rows.length&&!loading&&!error&&<p>Load requests to begin.</p>}</section></main>;
}
