'use client';

import {useEffect,useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type Request={request_number:string|null;agency_name:string|null;requested_by:string|null;preferred_date:string|null;training_format:string|null;status:string|null;class_status:string|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

const editableStatuses=new Set(['','new','open','pending','requested','submitted']);

export default function TrainingRequestEditPage(){
  const [requests,setRequests]=useState<Request[]>([]);
  const [selected,setSelected]=useState<Request|null>(null);
  const [form,setForm]=useState({agency_name:'',requested_by:'',preferred_date:'',training_format:''});
  const [loading,setLoading]=useState(false);
  const [saving,setSaving]=useState(false);
  const [message,setMessage]=useState('');
  const [error,setError]=useState('');

  useEffect(()=>{loadRequests();},[]);

  async function loadRequests(){
    setLoading(true);setError('');setMessage('');
    const {data:session}=await supabase.auth.getSession();
    if(!session.session){setError('Administrator sign-in is required.');setLoading(false);return;}
    const {data,error}=await supabase.from('training_requests').select('request_number,agency_name,requested_by,preferred_date,training_format,status,class_status').order('created_at',{ascending:false});
    if(error)setError(error.message);else setRequests(data??[]);
    setLoading(false);
  }

  function choose(request:Request){
    const status=(request.status||request.class_status||'').trim().toLowerCase();
    if(!editableStatuses.has(status)){setSelected(null);setError('Only open training requests can be edited. Completed, closed, cancelled, and finalized records are locked.');return;}
    setSelected(request);
    setForm({agency_name:request.agency_name||'',requested_by:request.requested_by||'',preferred_date:request.preferred_date||'',training_format:request.training_format||''});
    setError('');setMessage('');
  }

  async function save(){
    if(!selected?.request_number){setError('This request cannot be edited because it has no request number.');return;}
    if(!window.confirm('Save these changes to this open training request?'))return;
    setSaving(true);setError('');setMessage('');
    const {data:session}=await supabase.auth.getSession();
    if(!session.session){setError('Your administrator session has expired.');setSaving(false);return;}
    const {error}=await supabase.from('training_requests').update(form).eq('request_number',selected.request_number).in('status',['', 'new','open','pending','requested','submitted']);
    if(error){setError(error.message);setSaving(false);return;}
    setMessage('Training request updated.');
    await loadRequests();
    setSelected(null);
    setSaving(false);
  }

  if(error&&!requests.length)return <main className="shell"><section className="card"><h1>Edit Training Requests</h1><p>{error}</p><a href="/">Return to dashboard</a></section></main>;

  return <main className="shell"><header className="header"><div><div className="brand">Edit Training Requests</div><div className="subtitle">Open requests only · finalized records remain locked</div></div><a href="/">Back to dashboard</a></header><section className="card"><div className="header"><h2>Open requests</h2><button disabled={loading} onClick={loadRequests}>Refresh</button></div><p className="subtitle">Select an open request to update its basic details. No status, attendance, certificate, or email fields can be changed here.</p>{error&&<p>{error}</p>}{message&&<p>{message}</p>}{loading&&<p>Loading requests…</p>}{!loading&&requests.length===0&&<p>No training requests found.</p>}{requests.length>0&&<table className="table"><thead><tr><th>Request</th><th>Agency</th><th>Requester</th><th>Date</th><th>Status</th><th>Action</th></tr></thead><tbody>{requests.map((request,index)=>{const status=(request.status||request.class_status||'').trim().toLowerCase();const editable=editableStatuses.has(status);return <tr key={request.request_number||index}><td>{request.request_number||'—'}</td><td>{request.agency_name||'—'}</td><td>{request.requested_by||'—'}</td><td>{request.preferred_date||'—'}</td><td><span className="pill">{request.status||request.class_status||'Open'}</span></td><td><button disabled={!editable} onClick={()=>choose(request)}>{editable?'Edit':'Locked'}</button></td></tr>;})}</tbody></table>}</section>{selected&&<section className="card" style={{marginTop:20}}><h2>Edit request {selected.request_number}</h2><div className="controls"><label>Agency<input value={form.agency_name} onChange={e=>setForm({...form,agency_name:e.target.value})}/></label><label>Requester<input value={form.requested_by} onChange={e=>setForm({...form,requested_by:e.target.value})}/></label><label>Preferred date<input type="date" value={form.preferred_date.slice(0,10)} onChange={e=>setForm({...form,preferred_date:e.target.value})}/></label><label>Training format<input value={form.training_format} onChange={e=>setForm({...form,training_format:e.target.value})}/></label></div><button disabled={saving} onClick={save}>{saving?'Saving…':'Save changes'}</button><button disabled={saving} onClick={()=>setSelected(null)}>Cancel</button></section>}</main>;
}
