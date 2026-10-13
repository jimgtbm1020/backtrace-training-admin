'use client';

import {useEffect,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';
import styles from './account.module.css';
import PasswordForm from '../components/password-form';

type Profile={role:string|null;active:boolean|null};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
export default function AccountPage(){
 const [user,setUser]=useState<User|null>(null),[profile,setProfile]=useState<Profile|null>(null),[loading,setLoading]=useState(true);
 const [error,setError]=useState('');
 useEffect(()=>{
  let mounted=true;
  async function load(){
   try{
    const {data,error:authError}=await supabase.auth.getUser();if(!mounted)return;
    if(authError)throw authError;setUser(data.user);
    if(data.user){const {data:row,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',data.user.id).maybeSingle();if(!mounted)return;if(profileError)throw profileError;setProfile(row);}
   }catch(e){if(mounted)setError(e instanceof Error?e.message:'Unable to load your account.');}
   finally{if(mounted)setLoading(false);}
  }
  void load();
  const {data:listener}=supabase.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'&&mounted){setUser(null);setProfile(null);}});
  return()=>{mounted=false;listener.subscription.unsubscribe();};
 },[]);
 const allowed=!!user&&!!profile?.active&&['admin','coordinator','trainer','viewer'].includes(profile.role||'');
 async function signOut(){setError('');const {error:signOutError}=await supabase.auth.signOut();if(signOutError){setError(signOutError.message);return;}setUser(null);setProfile(null);window.location.assign('/');}
 if(loading)return <main className="shell"><section className="card"><h1>My Account</h1><p>Loading account…</p></section></main>;
 if(!user)return <main className="shell"><section className="card"><h1>My Account</h1><p>{error||'Sign in to manage your account and password.'}</p><a href="/">Return to sign in</a></section></main>;
 return <main className={'shell '+styles.page}><header className="header"><div><h1>My Account</h1><p>Manage your sign-in password.</p></div><a className="dashboard-return-button" href="/">Back to dashboard</a></header>
  <section className="card"><h2>Account details</h2><p><strong>Email:</strong> {user.email||'—'}</p><p><strong>Role:</strong> {profile?.role||'Unassigned'}</p><p><strong>Status:</strong> {profile?.active?'Active':'Inactive or unavailable'}</p><button onClick={()=>void signOut()}>Sign out</button></section>
  {error&&<p className="error" role="alert">{error}</p>}
  {allowed?<PasswordForm client={supabase}/>:<section className="card"><p>An active staff account is required to manage your password. Contact your administrator.</p></section>}
 </main>;
}
