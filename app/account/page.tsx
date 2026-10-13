'use client';

import {FormEvent,useEffect,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';
import styles from './account.module.css';

type Profile={role:string|null;active:boolean|null};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
export default function AccountPage(){
 const [user,setUser]=useState<User|null>(null),[profile,setProfile]=useState<Profile|null>(null),[loading,setLoading]=useState(true);
 const [password,setPassword]=useState(''),[confirmation,setConfirmation]=useState(''),[show,setShow]=useState(false),[saving,setSaving]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
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
  const {data:listener}=supabase.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'&&mounted){setUser(null);setProfile(null);setPassword('');setConfirmation('');setMessage('');}});
  return()=>{mounted=false;listener.subscription.unsubscribe();};
 },[]);
 const allowed=!!user&&!!profile?.active&&['admin','coordinator','trainer','viewer'].includes(profile.role||'');
 async function savePassword(event:FormEvent){
  event.preventDefault();if(!allowed||saving)return;setError('');setMessage('');
  if(password.length<8){setError('Use at least 8 characters for your new password.');return;}
  if(password!==confirmation){setError('The passwords do not match.');return;}
  setSaving(true);
  try{
   const {data:current,error:authError}=await supabase.auth.getUser();if(authError)throw authError;
   if(!current.user||current.user.id!==user?.id)throw new Error('Your session changed. Sign in again before saving a password.');
   const {data:currentProfile,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',current.user.id).maybeSingle();
   if(profileError)throw profileError;
   if(!currentProfile?.active||!['admin','coordinator','trainer','viewer'].includes(currentProfile.role))throw new Error('An active staff account is required.');
   const {data,error:saveError}=await supabase.auth.updateUser({password});
   if(saveError)throw saveError;if(!data.user||data.user.id!==current.user.id)throw new Error('Unable to confirm the password update.');
   setPassword('');setConfirmation('');setShow(false);setMessage('Your password has been saved. Use it the next time you sign in.');
  }catch(e){setError(e instanceof Error?e.message:'Unable to save your password. Please try again.');}
  finally{setSaving(false);}
 }
 async function signOut(){if(saving)return;setError('');const {error:signOutError}=await supabase.auth.signOut();if(signOutError){setError(signOutError.message);return;}setUser(null);setProfile(null);setPassword('');setConfirmation('');window.location.assign('/');}
 if(loading)return <main className="shell"><section className="card"><h1>My Account</h1><p>Loading account…</p></section></main>;
 if(!user)return <main className="shell"><section className="card"><h1>My Account</h1><p>{error||'Sign in to manage your account and password.'}</p><a href="/">Return to sign in</a></section></main>;
 return <main className={'shell '+styles.page}><header className="header"><div><h1>My Account</h1><p>Manage your sign-in password.</p></div><a className="dashboard-return-button" href="/">Back to dashboard</a></header>
  <section className="card"><h2>Account details</h2><p><strong>Email:</strong> {user.email||'—'}</p><p><strong>Role:</strong> {profile?.role||'Unassigned'}</p><p><strong>Status:</strong> {profile?.active?'Active':'Inactive or unavailable'}</p><button disabled={saving} onClick={()=>void signOut()}>Sign out</button></section>
  {error&&<p className="error" role="alert">{error}</p>}{message&&<p className={styles.success} role="status" aria-live="polite">{message}</p>}
  {allowed?<section className="card"><h2>Create or change your password</h2><p>Choose a password for your existing Backtrace account. Use at least 8 characters.</p><form className={styles.form} onSubmit={savePassword}><fieldset disabled={saving}>
   <label htmlFor="new-password">New password</label><input id="new-password" name="new-password" type={show?'text':'password'} autoComplete="new-password" minLength={8} required value={password} onChange={e=>{setPassword(e.target.value);setMessage('');}}/>
   <label htmlFor="confirm-password">Confirm new password</label><input id="confirm-password" name="confirm-password" type={show?'text':'password'} autoComplete="new-password" minLength={8} required value={confirmation} onChange={e=>{setConfirmation(e.target.value);setMessage('');}}/>
   <label className={styles.show}><input type="checkbox" checked={show} onChange={e=>setShow(e.target.checked)}/>Show passwords</label>
   <button className={styles.save} type="submit" disabled={saving||!password||!confirmation}>{saving?'Saving…':'Save password'}</button>
  </fieldset></form></section>:<section className="card"><p>An active staff account is required to manage your password. Contact your administrator.</p></section>}
 </main>;
}
