'use client';

import {useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type Agency={id:string;agency_name:string|null;agency_address:string|null;city_state_zip:string|null;contact_person:string|null;contact_phone:string|null;contact_email:string|null;active:boolean|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function AgenciesPage(){
  const [auth,setAuth]=useState(false);
  const [rows,setRows]=useState<Agency[]>([]);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(false);
  async function load(){setLoading(true);setError('');const {data,error}=await supabase.from('agencies').select('id,agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,active').order('agency_name');if(error)setError(error.message);else setRows(data??[]);setLoading(false);}
  async function check(){const {data}=await supabase.auth.getSession();setAuth(Boolean(data.session));}
  useState(()=>{check();});
  if(!auth)return <main className="shell"><section className="card"><h1>Agency Directory</h1><p>Administrator sign-in is required.</p><a href="/">Return to sign in</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Agency Directory</div><div className="subtitle">Read-only agency records</div></div><a href="/">Back to dashboard</a></header><section className="card"><button disabled={loading} onClick={load}>Load agencies</button>{error&&<p>{error}</p>}{rows.length>0&&<table className="table"><thead><tr><th>Agency</th><th>Location</th><th>Contact</th><th>Phone</th><th>Email</th><th>Status</th></tr></thead><tbody>{rows.map(row=><tr key={row.id}><td>{row.agency_name||'—'}</td><td>{[row.agency_address,row.city_state_zip].filter(Boolean).join(', ')||'—'}</td><td>{row.contact_person||'—'}</td><td>{row.contact_phone||'—'}</td><td>{row.contact_email||'—'}</td><td>{row.active?'Active':'Inactive'}</td></tr>)}</tbody></table>}</section></main>;
}