'use client';
import {useEffect,useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import styles from './notification-attention.module.css';

type Item={id:number;title:string;message:string;severity:string;read_at:string|null;created_at:string;action_pending:boolean;overdue:boolean;action_url:string|null;};
type Summary={attention_count:number;unread_count:number;open_action_count:number;overdue_count:number;items:Item[];};
export function notificationActionHref(value:string|null,origin:string):string|null{
  if(!value)return null;
  try{
    const url=new URL(value,origin);
    if(url.origin!==origin&&!['backtrace-training-admin.vercel.app','backtrace-training-tracker.vercel.app'].includes(url.hostname))return null;
    if(!['https:','http:'].includes(url.protocol))return null;
    const request=url.searchParams.get('request');
    if(url.pathname==='/completion'||url.pathname.startsWith('/completion/'))return '/completions'+(request?'?request='+encodeURIComponent(request):'');
    if(url.pathname==='/requests'&&request)return '/requests/edit?request='+encodeURIComponent(request);
    if(!['/requests','/requests/edit','/calendar','/completions','/trainer-workspace','/notifications','/classes','/today'].includes(url.pathname))return null;
    return url.pathname+url.search+url.hash;
  }catch{return null;}
}
export default function NotificationAttention({client,userId}:{client:SupabaseClient;userId:string}){
  const [summary,setSummary]=useState<Summary|null>(null);
  const [busy,setBusy]=useState(true);
  const [error,setError]=useState('');
  useEffect(()=>{
    let active=true,inFlight=false;
    setSummary(null);setError('');setBusy(true);
    async function refresh(){
      if(inFlight)return;
      inFlight=true;if(active)setBusy(true);
      try{
        const {data,error:loadError}=await client.rpc('get_dashboard_notification_attention');
        if(!active)return;
        if(loadError)throw new Error(loadError.message);
        setSummary(data as Summary);setError('');
      }catch(e){if(active){setSummary(null);setError(e instanceof Error?e.message:'Unable to load notifications.');}}
      finally{inFlight=false;if(active)setBusy(false);}
    }
    const visible=()=>{if(document.visibilityState==='visible')void refresh();};
    const changed=()=>void refresh();
    void refresh();
    const timer=window.setInterval(visible,30000);
    window.addEventListener('focus',changed);
    window.addEventListener('backtrace-notifications-changed',changed);
    document.addEventListener('visibilitychange',visible);
    return()=>{active=false;window.clearInterval(timer);window.removeEventListener('focus',changed);window.removeEventListener('backtrace-notifications-changed',changed);document.removeEventListener('visibilitychange',visible);};
  },[client,userId]);
  const refresh=()=>window.dispatchEvent(new Event('backtrace-notifications-changed'));
  return <section className={styles.card} aria-labelledby="dashboard-notification-heading">
    <div className={styles.header}><div><span className={styles.kicker}>YOUR NOTIFICATIONS</span><h2 id="dashboard-notification-heading">Notifications Needing Attention</h2></div><div className={styles.controls}><button disabled={busy} onClick={refresh}>{busy?'Checking…':'Refresh notifications'}</button><a href="/notifications?view=all">View all notifications</a></div></div>
    <div role="status" aria-live="polite" aria-atomic="true" className={styles.summary}>{error?'Notifications are temporarily unavailable.':summary?(summary.attention_count?('You have '+summary.attention_count+' notification'+(summary.attention_count===1?'':'s')+' needing attention.'):'You’re all caught up. No notifications need attention.'):'Checking your notifications…'}</div>
    {error&&<p role="alert" className={styles.error}>{error} Use Refresh notifications to retry.</p>}
    {summary&&<><div className={styles.counts}><span><strong>{summary.unread_count}</strong> unread</span><span><strong>{summary.open_action_count}</strong> open actions</span><span className={summary.overdue_count?styles.overdue:''}><strong>{summary.overdue_count}</strong> overdue actions</span></div>
    {summary.items.length>0&&<ul className={styles.list}>{summary.items.map(item=>{
      const href=notificationActionHref(item.action_url,window.location.origin);
      const warning=['warning','critical'].includes(item.severity.toLowerCase());
      return <li key={item.id} className={[styles.item,!item.read_at?styles.unread:'',item.overdue||warning?styles.warning:''].join(' ')}><div className={styles.details}><div className={styles.labels}>{!item.read_at&&<span>Unread</span>}{item.action_pending&&<span>Action pending</span>}{item.overdue&&<span className={styles.overdue}>Overdue</span>}{warning&&<span>{item.severity==='critical'?'Critical':'Warning'}</span>}</div><h3>{item.title}</h3><p>{item.message}</p><time dateTime={item.created_at}>{new Date(item.created_at).toLocaleString()}</time></div><div className={styles.links}><a href="/notifications?view=all">View notification</a>{href&&<a className={styles.primary} href={href}>{item.action_pending?'Take action':'Open details'}</a>}</div></li>;
    })}</ul>}
    <p className={styles.hint}>Reading a notice does not complete its action. Pending assignments, scheduling needs and conflicts clear when the underlying request is resolved. Updates every 30 seconds while this page is visible.</p></>}
  </section>;
}
