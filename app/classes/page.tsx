'use client';

import {useEffect,useState} from 'react';
import {createClient,Session} from '@supabase/supabase-js';

type SessionRow={id:string;request_id:string|null;active:boolean|null;registration_open:boolean|null;checkin_open_at:string|null;checkin_close_at:string|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function ClassesPage(){
  const [auth,setAuth]=useState<Session|null>(null);
  const [rows,setRows]=useState<SessionRow[]>([]);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(false);
  useEffect(()=>{supabase.auth.getSession().then(({data})=>setAuth(data.session));},[]);
  async function load(){setLoading(true);setError('');const {data,error}=await supabase.from('training_attendance_sessions').select('id,request_id,active,registration_open,checkin_open_at,checkin_close_at').order('created_at',{ascending:false});if(error)setError(error.message);else setRows(data??[]);setLoading(false);}
  if(!auth)return <main className="shell"><section className="card"><h1>Classes and Attendance</h1><p>Administrator sign-in is required.</p><a href="/">Return to sign in</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Classes and Attendance</div><div className="subtitle">Read-only session overview</div></div><a href="/">Back to dashboard</a></header><section className="card"><button disabled={loading} onClick={load}>Load classes and attendance</button>{error&&<p>{error}</p>}{rows.length>0&&<table className="table"><thead><tr><th>Session</th><th>Request</th><th>State</th><th>Registration</th><th>Check-in window</th></tr></thead><tbody>{rows.map(row=><tr key={row.id}><td>{row.id.slice(0,8)}</td><td>{row.request_id||'—'}</td><td>{row.active?'Active':'Closed'}</td><td>{row.registration_open?'Open':'Closed'}</td><td>{row.checkin_open_at||'—'} → {row.checkin_close_at||'—'}</td></tr>)}</tbody></table>}</section></main>;
}