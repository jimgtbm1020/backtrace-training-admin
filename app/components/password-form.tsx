'use client';
import {FormEvent,useState} from 'react';
import {SupabaseClient} from '@supabase/supabase-js';
import styles from '../account/account.module.css';
export default function PasswordForm({client,required=false,recovery=false,onSaved}:{client:SupabaseClient;required?:boolean;recovery?:boolean;onSaved?:()=>void}){
 const [current,setCurrent]=useState(''),[password,setPassword]=useState(''),[confirmation,setConfirmation]=useState(''),[show,setShow]=useState(false),[saving,setSaving]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 async function save(event:FormEvent){
  event.preventDefault();if(saving)return;setError('');setMessage('');
  if(password.length<8||password.length>128){setError('Use between 8 and 128 characters for your new password.');return;}
  if(password!==confirmation){setError('The passwords do not match.');return;}
  if(!recovery&&!current){setError('Enter your current or temporary password.');return;}
  if(!recovery&&password===current){setError('Choose a password different from your current or temporary password.');return;}
  setSaving(true);
  try{
   const {data:identity,error:identityError}=await client.auth.getUser();
   if(identityError||!identity.user)throw new Error('Sign in again or open a fresh password reset link.');
   const {data,error:saveError}=await client.functions.invoke('manage-training-users',{body:{action:'change_own_password',current_password:current,new_password:password,recovery}});
   if(saveError){let detail='Unable to save your password. Please try again.';try{const body=await saveError.context?.json();if(body?.error)detail=body.error;}catch{}throw new Error(detail);}
   if(data?.error)throw new Error(data.error);if(!data?.success)throw new Error('Unable to confirm the password update.');
   setCurrent('');setPassword('');setConfirmation('');setShow(false);
   const {error:refreshError}=await client.auth.refreshSession();
   if(refreshError){setMessage('Password saved. Sign in again with your new password.');return;}
   setMessage('Your password has been saved. Use it the next time you sign in.');
   onSaved?.();
  }catch(e){setError(e instanceof Error?e.message:'Unable to save your password.');}finally{setSaving(false);}
 }
 return <section className={'card '+styles.page}><h2>{recovery?'Reset your password':required?'Replace your temporary password':'Create or change your password'}</h2><p>{recovery?'Your email link has verified your account. Enter and confirm a new password.':required?'Enter the temporary password provided by your administrator, then choose your own password before continuing.':'Enter your current password, then choose and confirm your new password.'} Use at least 8 characters.</p>
 {error&&<p role="alert" className="error">{error}</p>}{message&&<p className={styles.success} role="status">{message}</p>}
 <form className={styles.form} onSubmit={save}><fieldset disabled={saving}>
 {!recovery&&<><label htmlFor="current-password">{required?'Temporary password':'Current password'}</label><input id="current-password" name="current-password" type={show?'text':'password'} autoComplete="current-password" required value={current} onChange={e=>setCurrent(e.target.value)}/></>}
 <label htmlFor="new-password">New password</label><input id="new-password" name="new-password" type={show?'text':'password'} autoComplete="new-password" minLength={8} maxLength={128} required value={password} onChange={e=>setPassword(e.target.value)}/>
 <label htmlFor="confirm-password">Confirm new password</label><input id="confirm-password" name="confirm-password" type={show?'text':'password'} autoComplete="new-password" minLength={8} maxLength={128} required value={confirmation} onChange={e=>setConfirmation(e.target.value)}/>
 <label className={styles.show}><input type="checkbox" checked={show} onChange={e=>setShow(e.target.checked)}/>Show passwords</label>
 <button type="submit" className={styles.save} disabled={saving||!password||!confirmation||(!recovery&&!current)}>{saving?'Saving…':'Save password'}</button>
 </fieldset></form></section>;
}
