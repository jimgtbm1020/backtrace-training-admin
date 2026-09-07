'use client';

import {useEffect,useState} from 'react';
import {createClient} from '@supabase/supabase-js';
import HelpTip from '../components/help-tip';

type EmailDashboard={
  queue?:{pending?:number;delivered?:number;failed?:number;provider_failed?:number};
  webhook?:{enabled?:boolean;configured?:boolean};
  templates?:Array<{alias?:string;display_name?:string;active?:boolean;status?:string}>;
  recent_events?:Array<{queue_id?:string;event_type?:string;recipient_email?:string;event_at?:string}>;
};

type SystemStatus={
  communications?:{
    email_delivery_enabled?:boolean;
    webhook_enabled?:boolean;
    tracking_enabled?:boolean;
    email_delivery_cron_active?:boolean;
  };
};

const sb=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function EmailSettings(){
  const [data,setData]=useState<EmailDashboard|null>(null);
  const [system,setSystem]=useState<SystemStatus|null>(null);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(true);

  useEffect(()=>{
    void (async()=>{
      const {data:auth}=await sb.auth.getUser();
      if(!auth.user){setError('Administrator sign-in is required.');setLoading(false);return;}

      const [dashboardResult,statusResult]=await Promise.all([
        sb.rpc('get_training_email_delivery_dashboard'),
        sb.rpc('get_training_system_status'),
      ]);

      if(dashboardResult.error||statusResult.error){
        setError(dashboardResult.error?.message||statusResult.error?.message||'Unable to load communications configuration.');
      }else{
        setData(dashboardResult.data as EmailDashboard);
        setSystem(statusResult.data as SystemStatus);
      }
      setLoading(false);
    })();
  },[]);

  if(loading)return <main className="shell"><section className="card"><h1>Email Settings</h1><p>Loading communications configuration…</p></section></main>;

  const deliveryEnabled=Boolean(system?.communications?.email_delivery_enabled);
  const cronActive=Boolean(system?.communications?.email_delivery_cron_active);

  return <main className="shell legacy-admin-page">
    <header className="legacy-page-header">
      <div><h1 className="help-heading">Email Settings<HelpTip text="This read-only page shows the live delivery, queue, webhook, tracking, and template state. Verify recipients and the pending queue before sending."/></h1><p>Review communications configuration and delivery safeguards.</p></div>
      <a href="/">Back to dashboard</a>
    </header>

    {error?<section className="card"><p className="error" role="alert">{error}</p></section>:<>
      <section className="settings-status-grid">
        <div><span>DELIVERY</span><strong>{deliveryEnabled?'ON':'OFF'}</strong><small>Authorized live state</small></div>
        <div><span>QUEUE PENDING</span><strong>{data?.queue?.pending||0}</strong><small>{deliveryEnabled?'Automatic delivery active':'Held while delivery is off'}</small></div>
        <div><span>DELIVERED</span><strong>{data?.queue?.delivered||0}</strong><small>Provider events</small></div>
        <div><span>FAILED</span><strong>{(data?.queue?.failed||0)+(data?.queue?.provider_failed||0)}</strong><small>Requires review</small></div>
      </section>

      <section className="legacy-panel">
        <h2 className="help-heading">Provider Settings<HelpTip text="Email delivery and the delivery cron work together. Webhook processing and tracking are separate and remain disabled unless explicitly authorized."/></h2>
        <div className="settings-grid">
          <div><label>Provider</label><strong>Resend</strong></div>
          <div><label>Sender</label><strong>Backtrace Training</strong></div>
          <div><label>From Address</label><strong>no-reply@training.gtbm.com</strong></div>
          <div><label>Automatic Delivery</label><strong>{deliveryEnabled?'Enabled':'Disabled'}</strong></div>
          <div><label>Delivery Cron</label><strong>{cronActive?'Active':'Inactive'}</strong></div>
          <div><label>Webhook Processing</label><strong>{system?.communications?.webhook_enabled?'Enabled':'Disabled'}</strong></div>
          <div><label>Tracking</label><strong>{system?.communications?.tracking_enabled?'Enabled':'Disabled'}</strong></div>
          <div><label>Webhook Signature</label><strong>{data?.webhook?.configured?'Configured':'Not configured'}</strong></div>
        </div>
      </section>

      <section className="legacy-panel">
        <div className="panel-heading"><h2>Email Templates</h2><span>{data?.templates?.length||0} templates</span></div>
        <div className="simple-list">{(data?.templates||[]).map(row=><div key={row.alias||row.display_name}><strong>{row.display_name||row.alias}</strong><span>{row.active===false?'Inactive':row.status||'Configured'}</span></div>)}</div>
      </section>

      <section className="legacy-panel">
        <div className="panel-heading"><h2>Recent Delivery Events</h2><span>{data?.recent_events?.length||0} events</span></div>
        {data?.recent_events?.length?<div className="simple-list">{data.recent_events.slice(0,10).map((row,index)=><div key={row.queue_id||index}><strong>{row.event_type||'Event'}</strong><span>{row.recipient_email||'No recipient'} · {row.event_at?new Date(row.event_at).toLocaleString():''}</span></div>)}</div>:<p className="muted">No delivery events recorded.</p>}
      </section>
    </>}
  </main>;
}
