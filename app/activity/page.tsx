'use client';

import {useEffect,useMemo,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';

type Role='admin'|'trainer'|'viewer';
type Profile={id:string;email:string|null;role:Role;active:boolean;};
type Activity={id:number;actor_id:string;target_user_id:string|null;action:string;details:Record<string,unknown>|null;created_at:string;};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function ActivityLog(){
  const [user,setUser]=useState<User|null>(null);
  const [rows,setRows]=useState<Activity[]>([]);
  const [profiles,setProfiles]=useState<Record<string,Profile>>({});
  const [loading,setLoading]=useState(true);
  const [error,setError]=useState('');
  const [search,setSearch]=useState('');

  useEffect(()=>{load();},[]);
  async function load(){
    setLoading(true);setError('');
    const {data:auth}=await supabase.auth.getUser();
    if(!auth.user){setError('Administrator sign-in is required.');setLoading(false);return;}
    setUser(auth.user);
    const {data:me,error:meError}=await supabase.from('profiles').select('role,active').eq('id',auth.user.id).maybeSingle();
    if(meError||me?.role!=='admin'||!me.active){setError(meError?.message||'Administrator access is required.');setLoading(false);return;}
    const [{data:activity,error:activityError},{data:allProfiles,error:profileError}]=await Promise.all([
      supabase.from('user_management_activity').select('id,actor_id,target_user_id,action,details,created_at').order('created_at',{ascending:false}),
      supabase.from('profiles').select('id,email,role,active')
    ]);
    if(activityError||profileError){setError(activityError?.message||profileError?.message||'Could not load activity.');setLoading(false);return;}
    setRows(activity??[]);
    setProfiles(Object.fromEntries((allProfiles??[]).map(profile=>[profile.id,profile as Profile])));
    setLoading(false);
  }
  const filtered=useMemo(()=>{const term=search.trim().toLowerCase();return rows.filter(row=>{const actor=profiles[row.actor_id]?.email||'';const target=profiles[row.target_user_id||'']?.email||'';return !term||[row.action,actor,target,JSON.stringify(row.details||{})].join(' ').toLowerCase().includes(term);});},[profiles,rows,search]);
  if(loading)return <main className="shell"><section className="card"><h1>Activity Log</h1><p>Checking administrator permissions…</p></section></main>;
  if(error)return <main className="shell"><section className="card"><h1>Activity Log</h1><p>{error}</p><a href="/">Return to dashboard</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Activity Log</div><div className="subtitle">Administrator-only audit history</div></div><a href="/">Back to dashboard</a></header><section className="card"><p>Role-management activity is visible only to Administrators.</p><div className="controls"><input aria-label="Search activity" placeholder="Search action or user" value={search} onChange={event=>setSearch(event.target.value)}/><button onClick={load}>Refresh</button></div>{filtered.length===0?<p>No activity records found.</p>:<table className="table"><thead><tr><th>Time</th><th>Actor</th><th>Target</th><th>Action</th><th>Details</th></tr></thead><tbody>{filtered.map(row=><tr key={row.id}><td>{new Date(row.created_at).toLocaleString()}</td><td>{profiles[row.actor_id]?.email||row.actor_id}</td><td>{profiles[row.target_user_id||'']?.email||'—'}</td><td><span className="pill">{row.action}</span></td><td>{row.details?JSON.stringify(row.details):'—'}</td></tr>)}</tbody></table>}</section></main>;
}
