'use client';

import {useEffect,useState} from 'react';
import {createClient,Session} from '@supabase/supabase-js';

type Attendee={full_name:string|null;email:string|null;agency_name:string|null;title_position:string|null;certificate_number:string|null;};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function Home(){
  const [session,setSession]=useState<Session|null>(null);
  const [email,setEmail]=useState('');
  const [password,setPassword]=useState('');
  const [attendees,setAttendees]=useState<Attendee[]>([]);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(false);

  useEffect(()=>{supabase.auth.getSession().then(({data})=>setSession(data.session));const {data}=supabase.auth.onAuthStateChange((_event,next)=>setSession(next));return()=>data.subscription.unsubscribe()},[]);

  async function signIn(){setLoading(true);setError('');const {data,error}=await supabase.auth.signInWithPassword({email,password});if(error)setError(error.message);else setSession(data.session);setLoading(false);}
  async function loadAttendees(){setLoading(true);setError('');const {data,error}=await supabase.from('training_attendees').select('full_name,email,agency_name,title_position,certificate_number').order('full_name');if(error)setError(error.message);else setAttendees(data??[]);setLoading(false);}

  if(!session)return <main className="shell"><section className="card"><h1>Backtrace Training Administration</h1><p className="subtitle">New rebuild environment — production remains unchanged.</p><h2>Administrator sign-in</h2><input placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={loading||!email||!password} onClick={signIn}>Sign in</button>{error&&<p>{error}</p>}</section></main>;

  return <main className="shell"><header className="header"><div><div className="brand">Backtrace Training Administration</div><div className="subtitle">Rebuild preview · read-only attendee directory</div></div><button onClick={()=>supabase.auth.signOut()}>Sign out</button></header><section className="grid"><div className="metric">Attendees<strong>{attendees.length}</strong></div><div className="metric">Environment<strong>Preview</strong></div></section><section className="card" style={{marginTop:20}}><button disabled={loading} onClick={loadAttendees}>Load attendee directory</button>{error&&<p>{error}</p>}{attendees.length>0&&<table className="table"><thead><tr><th>Name</th><th>Email</th><th>Agency</th><th>Title</th><th>Certificate</th></tr></thead><tbody>{attendees.map((a,i)=><tr key={i}><td>{a.full_name}</td><td>{a.email}</td><td>{a.agency_name}</td><td>{a.title_position}</td><td><span className="pill">{a.certificate_number||'None'}</span></td></tr>)}</tbody></table>}</section></main>;
}