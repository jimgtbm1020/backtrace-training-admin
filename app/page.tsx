'use client';

import {useEffect,useMemo,useState} from 'react';
import {createClient,Session} from '@supabase/supabase-js';

type Attendee={full_name:string|null;email:string|null;agency_name:string|null;title_position:string|null;certificate_number:string|null;};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function Home(){
  const [session,setSession]=useState<Session|null>(null);
  const [email,setEmail]=useState('');
  const [password,setPassword]=useState('');
  const [attendees,setAttendees]=useState<Attendee[]>([]);
  const [search,setSearch]=useState('');
  const [agency,setAgency]=useState('All agencies');
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(false);

  useEffect(()=>{supabase.auth.getSession().then(({data})=>setSession(data.session));const {data}=supabase.auth.onAuthStateChange((_event,next)=>setSession(next));return()=>data.subscription.unsubscribe()},[]);

  async function signIn(){setLoading(true);setError('');const {data,error}=await supabase.auth.signInWithPassword({email,password});if(error)setError(error.message);else setSession(data.session);setLoading(false);}
  async function loadAttendees(){setLoading(true);setError('');const {data,error}=await supabase.from('training_attendees').select('full_name,email,agency_name,title_position,certificate_number').order('full_name');if(error)setError(error.message);else setAttendees(data??[]);setLoading(false);}

  const agencies=useMemo(()=>['All agencies',...Array.from(new Set(attendees.map(a=>a.agency_name).filter((value):value is string=>Boolean(value))).sort())],[attendees]);
  const filteredAttendees=useMemo(()=>{
    const term=search.trim().toLowerCase();
    return attendees.filter(a=>{
      const matchesAgency=agency==='All agencies'||a.agency_name===agency;
      const searchable=[a.full_name,a.email,a.agency_name,a.title_position,a.certificate_number].filter(Boolean).join(' ').toLowerCase();
      return matchesAgency&&(!term||searchable.includes(term));
    });
  },[agency,attendees,search]);

  if(!session)return <main className="shell"><section className="card"><h1>Backtrace Training Administration</h1><p className="subtitle">New rebuild environment — production remains unchanged.</p><h2>Administrator sign-in</h2><input placeholder="Email" value={email} onChange={e=>setEmail(e.target.value)}/><input type="password" placeholder="Password" value={password} onChange={e=>setPassword(e.target.value)}/><button disabled={loading||!email||!password} onClick={signIn}>Sign in</button>{error&&<p>{error}</p>}</section></main>;

  return <main className="shell"><header className="header"><div><div className="brand">Backtrace Training Administration</div><div className="subtitle">Rebuild preview · read-only attendee directory</div></div><button onClick={()=>supabase.auth.signOut()}>Sign out</button></header><section className="grid"><div className="metric">Attendees<strong>{attendees.length}</strong></div><div className="metric">Showing<strong>{filteredAttendees.length}</strong></div></section><section className="card" style={{marginTop:20}}><div className="controls"><input aria-label="Search attendees" placeholder="Search name, email, agency, title, or certificate" value={search} onChange={e=>setSearch(e.target.value)}/><select aria-label="Filter by agency" value={agency} onChange={e=>setAgency(e.target.value)}>{agencies.map(value=><option key={value}>{value}</option>)}</select></div><button disabled={loading} onClick={loadAttendees}>Load attendee directory</button>{error&&<p>{error}</p>}{filteredAttendees.length>0&&<table className="table"><thead><tr><th>Name</th><th>Email</th><th>Agency</th><th>Title</th><th>Certificate</th></tr></thead><tbody>{filteredAttendees.map((a,i)=><tr key={a.certificate_number||a.email||i}><td>{a.full_name}</td><td>{a.email}</td><td>{a.agency_name}</td><td>{a.title_position}</td><td><span className="pill">{a.certificate_number||'None'}</span></td></tr>)}</tbody></table>}{attendees.length>0&&filteredAttendees.length===0&&<p>No attendees match the current search and agency filter.</p>}</section></main>;
}