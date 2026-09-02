'use client';

import {useEffect,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';

type Profile={role:string|null;active:boolean|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
export default function AccountPage(){const [user,setUser]=useState<User|null>(null);const [profile,setProfile]=useState<Profile|null>(null);const [loading,setLoading]=useState(true);useEffect(()=>{supabase.auth.getUser().then(async({data})=>{setUser(data.user);if(data.user){const {data:row}=await supabase.from('profiles').select('role,active').eq('id',data.user.id).maybeSingle();setProfile(row);}setLoading(false);});},[]);if(loading)return <main className="shell"><section className="card"><h1>Administrator Account</h1><p>Loading account…</p></section></main>;if(!user)return <main className="shell"><section className="card"><h1>Administrator Account</h1><p>Administrator sign-in is required.</p><a href="/">Return to sign in</a></section></main>;return <main className="shell"><header className="header"><div><div className="brand">Administrator Account</div><div className="subtitle">Current signed-in account</div></div><a href="/">Back to dashboard</a></header><section className="card"><h2>Account details</h2><p><strong>Email:</strong> {user.email||'—'}</p><p><strong>Role:</strong> {profile?.role||'Unassigned'}</p><p><strong>Status:</strong> {profile?.active?'Active':'Inactive or unavailable'}</p><p><strong>User ID:</strong> {user.id}</p><p><strong>Last sign-in:</strong> {user.last_sign_in_at||'—'}</p><button onClick={()=>supabase.auth.signOut()}>Sign out</button></section></main>;
}
