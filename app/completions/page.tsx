'use client';

import {useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type Completion={request_id:string;completion_number:string|null;record_status:string|null;actual_training_date:string|null;actual_minutes:number|null;actual_attendees:number|null;basic_training_completed:boolean|null;follow_up_required:boolean|null;finalized_at:string|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function CompletionPage(){
  const [auth,setAuth]=useState(false);const [rows,setRows]=useState<Completion[]>([]);const [error,setError]=useState('');const [loading,setLoading]=useState(false);
  async function load(){const {data}=await supabase.auth.getSession();if(!data.session){setError('Administrator sign-in is required.');return;}setAuth(true);setLoading(true);setError('');const {data:records,error}=await supabase.from('training_completion_records').select('request_id,completion_number,record_status,actual_training_date,actual_minutes,actual_attendees,basic_training_completed,follow_up_required,finalized_at').order('actual_training_date',{ascending:false});if(error)setError(error.message);else setRows(records??[]);setLoading(false);}
  if(!auth)return <main className="shell"><section className="card"><h1>Completion and Certificates</h1><p>Click below to authenticate and load the read-only records.</p><button onClick={load}>Load completion records</button>{error&&<p>{error}</p>}<a href="/">Return to dashboard</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Completion and Certificates</div><div className="subtitle">Read-only finalized training records</div></div><a href="/">Back to dashboard</a></header><section className="card"><button disabled={loading} onClick={load}>Refresh records</button>{error&&<p>{error}</p>}{rows.length>0&&<table className="table"><thead><tr><th>Completion</th><th>Date</th><th>Attendees</th><th>Minutes</th><th>Status</th><th>Finalized</th></tr></thead><tbody>{rows.map((row,i)=><tr key={row.completion_number||row.request_id||i}><td>{row.completion_number||'—'}</td><td>{row.actual_training_date||'—'}</td><td>{row.actual_attendees??'—'}</td><td>{row.actual_minutes??'—'}</td><td>{row.record_status||'—'}</td><td>{row.finalized_at?'Yes':'No'}</td></tr>)}</tbody></table>}</section></main>;
}