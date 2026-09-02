'use client';

import {useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type Notification={id:number;notification_type:string|null;title:string|null;message:string|null;severity:string|null;read_at:string|null;created_at:string|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function NotificationsPage(){
  const [rows,setRows]=useState<Notification[]>([]);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(false);
  async function load(){setLoading(true);setError('');const {data,error}=await supabase.from('training_notifications').select('id,notification_type,title,message,severity,read_at,created_at').order('created_at',{ascending:false});if(error)setError(error.message);else setRows(data??[]);setLoading(false);}
  return <main className="shell"><header className="header"><div><div className="brand">Notifications</div><div className="subtitle">Read-only notification history</div></div><a href="/">Back to dashboard</a></header><section className="card"><button disabled={loading} onClick={load}>Load notifications</button>{error&&<p>{error}</p>}{rows.length===0&&!loading&&<p>No notifications loaded.</p>}{rows.length>0&&<table className="table"><thead><tr><th>Title</th><th>Type</th><th>Severity</th><th>Message</th><th>Created</th><th>Status</th></tr></thead><tbody>{rows.map(row=><tr key={row.id}><td>{row.title||'—'}</td><td>{row.notification_type||'—'}</td><td>{row.severity||'—'}</td><td>{row.message||'—'}</td><td>{row.created_at||'—'}</td><td>{row.read_at?'Read':'Unread'}</td></tr>)}</tbody></table>}</section></main>;
}