'use client';

import {useEffect,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
export default function AccountPage(){const [user,setUser]=useState<User|null>(null);const [loading,setLoading]=useState(true);useEffect(()=>{supabase.auth.getUser().then(({data})=>{setUser(data.user);setLoading(false);});},[]);if(loading)return <main className="shell"><section className="card"><h1>Administrator Account</h1><p>Loading account…</p></section></main>;if(!user)return <main className="shell"><section className="card"><h1>Administrator Account</h1><p>Administrator sign-in is required.</p><a href="/">Return to sign in</a></section></main>;return <main className="shell"><header className="header"><div><div className="brand">Administrator Account</div><div className="subtitle">Current signed-in account</div></div><a href="/">Back to dashboard</a></header><section className="card"><h2>Account details</h2><p><strong>Email:</strong> {user.email||'—'}</p><p><strong>User ID:</strong> {user.id}</p><p><strong>Last sign-in:</strong> {user.last_sign_in_at||'—'}</p><p className="subtitle">Role and permission management will be added only after the access policy and audit requirements are finalized.</p><button onClick={()=>supabase.auth.signOut()}>Sign out</button></section></main>;
}
