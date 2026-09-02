'use client';

import {useState} from 'react';
import {createClient} from '@supabase/supabase-js';

type Version={id:number;version:string|null;release_date:string|null;title:string|null;summary:string|null;is_current:boolean|null;};
type Change={id:number;version_id:number;component:string|null;change_summary:string|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function VersionHistoryPage(){
  const [auth,setAuth]=useState(false);const [versions,setVersions]=useState<Version[]>([]);const [changes,setChanges]=useState<Change[]>([]);const [error,setError]=useState('');const [loading,setLoading]=useState(false);
  async function load(){const {data:session}=await supabase.auth.getSession();if(!session.session){setError('Administrator sign-in is required.');return;}setAuth(true);setLoading(true);setError('');const [v,c]=await Promise.all([supabase.from('training_app_versions').select('id,version,release_date,title,summary,is_current').order('release_date',{ascending:false}),supabase.from('training_app_version_changes').select('id,version_id,component,change_summary').order('sort_order')]);if(v.error||c.error)setError(v.error?.message||c.error?.message||'Unable to load version history');else{setVersions(v.data??[]);setChanges(c.data??[]);}setLoading(false);}
  if(!auth)return <main className="shell"><section className="card"><h1>Version History</h1><button onClick={load}>Load version history</button>{error&&<p>{error}</p>}<a href="/">Return to dashboard</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Version History</div><div className="subtitle">Read-only application release history</div></div><a href="/">Back to dashboard</a></header><section className="card"><button disabled={loading} onClick={load}>Refresh history</button>{error&&<p>{error}</p>}{versions.map(version=><article key={version.id}><h2>{version.version||'—'} {version.is_current&&<span className="pill">Current</span>}</h2><p>{version.title||'—'} · {version.release_date||'—'}</p><p>{version.summary||'—'}</p>{changes.filter(change=>change.version_id===version.id).map(change=><p key={change.id}>• {change.component||'Change'}: {change.change_summary||'—'}</p>)}</article>)}</section></main>;
}