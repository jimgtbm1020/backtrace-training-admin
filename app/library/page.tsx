'use client';

import {useEffect,useState} from 'react';
import {createClient,Session} from '@supabase/supabase-js';

type Module={id:number;category:string|null;module_name:string|null;duration_minutes:number|null;active:boolean|null;};
type Material={id:string;title:string|null;description:string|null;material_type:string|null;audience:string|null;active:boolean|null;};
const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function LibraryPage(){
  const [auth,setAuth]=useState<Session|null>(null);
  const [modules,setModules]=useState<Module[]>([]);
  const [materials,setMaterials]=useState<Material[]>([]);
  const [error,setError]=useState('');
  const [loading,setLoading]=useState(false);
  useEffect(()=>{supabase.auth.getSession().then(({data})=>setAuth(data.session));},[]);
  async function load(){setLoading(true);setError('');const [moduleResult,materialResult]=await Promise.all([supabase.from('training_modules').select('id,category,module_name,duration_minutes,active').eq('active',true).order('sort_order'),supabase.from('training_materials').select('id,title,description,material_type,audience,active').eq('active',true).order('title')]);if(moduleResult.error||materialResult.error)setError(moduleResult.error?.message||materialResult.error?.message||'Unable to load library');else{setModules(moduleResult.data??[]);setMaterials(materialResult.data??[]);}setLoading(false);}
  if(!auth)return <main className="shell"><section className="card"><h1>Training Library</h1><p>Administrator sign-in is required.</p><a href="/">Return to sign in</a></section></main>;
  return <main className="shell"><header className="header"><div><div className="brand">Training Library</div><div className="subtitle">Read-only modules and materials</div></div><a href="/">Back to dashboard</a></header><section className="card"><button disabled={loading} onClick={load}>Load training library</button>{error&&<p>{error}</p>}{modules.length>0&&<><h2>Training Modules</h2><table className="table"><thead><tr><th>Category</th><th>Module</th><th>Duration</th></tr></thead><tbody>{modules.map(module=><tr key={module.id}><td>{module.category||'—'}</td><td>{module.module_name||'—'}</td><td>{module.duration_minutes?module.duration_minutes+' minutes':'—'}</td></tr>)}</tbody></table></>}{materials.length>0&&<><h2>Materials</h2><table className="table"><thead><tr><th>Title</th><th>Type</th><th>Audience</th><th>Description</th></tr></thead><tbody>{materials.map(material=><tr key={material.id}><td>{material.title||'—'}</td><td>{material.material_type||'—'}</td><td>{material.audience||'—'}</td><td>{material.description||'—'}</td></tr>)}</tbody></table></>}</section></main>;
}