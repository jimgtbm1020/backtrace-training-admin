'use client';

import {FormEvent,useEffect,useRef,useState} from 'react';
import {createClient} from '@supabase/supabase-js';
import {Agency,Item,Assignment,agencyAddress,agencyLocation} from './types';
import styles from './rules.module.css';
import {ImportRow,parseAgencyCsv,previewAgencies} from './import-csv';

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const tabs=[['agencies','Agencies'],['items','Item catalog'],['assign','Agency Item Assignment'],['report','Agency Business Rules Report']] as const;
type Tab=typeof tabs[number][0];
const descriptions:Record<Tab,string>={agencies:'Create or import agencies for internal business rules. Save each agency once to assign multiple tools. This registry is separate from training requests and the training Agency Directory.',items:'Create or update a tool, dashboard, smart tool, or miscellaneous item, including its description and expected outcome.',assign:'Choose an agency and assign a tool, then record that agency’s data source and retention period. Existing assignments appear below.',report:'Review an agency’s assigned tools, data sources, retention periods, and expected outcomes, then export its business rules to PDF.'};
const blankAgency={agency_name:'',agency_address:'',agency_city:'',agency_state:'',agency_zip:'',city_state_zip:''};
const blankItem={name:'',item_type:'Tool',description:'',expected_outcome:''};

async function allRows<T>(fetchPage:(from:number,to:number)=>PromiseLike<{data:T[]|null;error:{message:string}|null}>){
 const rows:T[]=[];
 for(let offset=0;;offset+=1000){const result=await fetchPage(offset,offset+999);if(result.error)throw new Error(result.error.message);rows.push(...result.data||[]);if((result.data||[]).length<1000)return rows;}
}

export default function AgencyBusinessRulesPage(){
 const [access,setAccess]=useState<'checking'|'allowed'|'denied'>('checking');
 const [role,setRole]=useState('');const [userId,setUserId]=useState('');
 const [agencies,setAgencies]=useState<Agency[]>([]),[items,setItems]=useState<Item[]>([]),[assignments,setAssignments]=useState<Assignment[]>([]);
 const [tab,setTab]=useState<Tab>('agencies'),[loading,setLoading]=useState(true),[busy,setBusy]=useState(false),[error,setError]=useState(''),[message,setMessage]=useState('');
 const [agencyForm,setAgencyForm]=useState(blankAgency),[editingAgency,setEditingAgency]=useState<Agency|null>(null);
 const [itemForm,setItemForm]=useState(blankItem),[editingItem,setEditingItem]=useState<Item|null>(null);
 const [agencyId,setAgencyId]=useState(''),[itemId,setItemId]=useState(''),[reportAgencyId,setReportAgencyId]=useState('');
 const [source,setSource]=useState(''),[retention,setRetention]=useState('90'),[unit,setUnit]=useState('Days');
 const importInput=useRef<HTMLInputElement>(null);const [importRows,setImportRows]=useState<ImportRow[]>([]);const [importFile,setImportFile]=useState('');
 const importPreview=previewAgencies(importRows,agencies);
 const canManage=role==='admin'||role==='coordinator';
 const agency=agencies.find(a=>a.id===agencyId),reportAgency=agencies.find(a=>a.id===reportAgencyId);
 const selectedAssignment=assignments.find(a=>a.agency_id===agencyId&&a.item_id===itemId);
 const agencyAssignments=assignments.filter(a=>a.agency_id===agencyId);
 const reportAssignments=assignments.filter(a=>a.agency_id===reportAgencyId).sort((a,b)=>(items.find(i=>i.id===a.item_id)?.name||'').localeCompare(items.find(i=>i.id===b.item_id)?.name||''));

 async function load(){
  setLoading(true);setError('');
  try{
   const [a,i,s]=await Promise.all([
    allRows<Agency>((from,to)=>supabase.from('business_rules_agencies').select('id,agency_name,agency_address,city_state_zip,agency_city,agency_state,agency_zip,active,updated_at').order('agency_name').order('id').range(from,to)),
    allRows<Item>((from,to)=>supabase.from('resource_items').select('id,name,item_type,description,expected_outcome,updated_at').order('name').order('id').range(from,to)),
    allRows<Assignment>((from,to)=>supabase.from('agency_item_assignments').select('id,agency_id,item_id,data_source,retention_value,retention_unit,updated_at').order('id').range(from,to))
   ]);
   setAgencies(a);setItems(i);setAssignments(s);setAgencyId(value=>a.some(x=>x.id===value)?value:a.find(x=>x.active)?.id||a[0]?.id||'');setItemId(value=>i.some(x=>x.id===value)?value:i[0]?.id||'');setReportAgencyId(value=>a.some(x=>x.id===value)?value:a[0]?.id||'');
   return true;
  }catch(e){setError(e instanceof Error?e.message:'Unable to load business rules.');return false;}finally{setLoading(false);}
 }
 useEffect(()=>{
  let mounted=true;
  async function initialize(){
   try{
    const {data,error:authError}=await supabase.auth.getUser();if(!mounted)return;
    if(authError||!data.user){setAccess('denied');setError('Sign in through Training Administration to use Agency Business Rules.');setLoading(false);return;}
    const {data:profile,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',data.user.id).single();if(!mounted)return;
    if(profileError||!profile?.active||!['admin','coordinator','trainer','viewer'].includes(profile.role)){setAccess('denied');setError('An active Backtrace account is required.');setLoading(false);return;}
    setRole(profile.role);setUserId(data.user.id);setAccess('allowed');await load();
   }catch(e){if(mounted){setError(e instanceof Error?e.message:'Unable to check access.');setAccess('denied');setLoading(false);}}
  }
  const requestedTab=new URLSearchParams(window.location.search).get('tab');if(tabs.some(([id])=>id===requestedTab))setTab(requestedTab as Tab);
  void initialize();
  const {data:listener}=supabase.auth.onAuthStateChange((event)=>{if(event==='SIGNED_OUT'){setAccess('denied');setRole('');setAgencies([]);setItems([]);setAssignments([]);}});
  return()=>{mounted=false;listener.subscription.unsubscribe();};
 },[]);
 useEffect(()=>{setSource(selectedAssignment?.data_source||'');setRetention(String(selectedAssignment?.retention_value||90));setUnit(selectedAssignment?.retention_unit||'Days');},[selectedAssignment,agencyId,itemId]);

 function editAgency(row:Agency){setEditingAgency(row);setAgencyForm({agency_name:row.agency_name,agency_address:row.agency_address||'',agency_city:row.agency_city||'',agency_state:row.agency_state||'',agency_zip:row.agency_zip||'',city_state_zip:row.city_state_zip||''});setTab('agencies');setMessage('');}
 function editItem(row:Item){setEditingItem(row);setItemForm({name:row.name,item_type:row.item_type,description:row.description,expected_outcome:row.expected_outcome});setTab('items');setMessage('');}
 function downloadTemplate(){
  const url=URL.createObjectURL(new Blob(['Agency Name,Street Address,City,State,ZIP\r\n'],{type:'text/csv;charset=utf-8'}));
  const a=document.createElement('a');a.href=url;a.download='agency-import-template.csv';a.click();URL.revokeObjectURL(url);
 }
 async function previewImport(file:File){
  setError('');setMessage('');setImportRows([]);setImportFile('');
  try{if(file.size>1024*1024)throw new Error('Choose a CSV smaller than 1 MB.');const rows=parseAgencyCsv(await file.text());setImportRows(rows);setImportFile(file.name);}catch(e){setError(e instanceof Error?e.message:'Unable to read CSV.');}
 }
 async function importAgencies(){
  if(!canManage||busy||loading||!importRows.length)return;setBusy(true);setError('');setMessage('');
  try{const {data,error:importError}=await supabase.rpc('import_business_rules_agencies',{p_rows:importRows});if(importError)throw new Error(importError.message);setImportRows([]);setImportFile('');if(await load())setMessage(`${data.imported} agencies imported; ${data.skipped} duplicates skipped.`);}catch(e){setError(e instanceof Error?e.message:'Unable to import agencies. No rows were saved.');}finally{setBusy(false);}
 }
 async function saveAgency(event:FormEvent){
  event.preventDefault();if(!canManage||busy||loading)return;setBusy(true);setError('');setMessage('');
  try{
   const name=agencyForm.agency_name.trim().replace(/\s+/g,' ');if(!name)throw new Error('Agency name is required.');
   if(agencies.some(a=>a.id!==editingAgency?.id&&a.agency_name.trim().replace(/\s+/g,' ').toLowerCase()===name.toLowerCase()))throw new Error('This agency already exists. Edit it in the list below.');
   const location=[agencyForm.agency_city,agencyForm.agency_state,agencyForm.agency_zip].map(x=>x.trim()).filter(Boolean).join(', ')||agencyForm.city_state_zip.trim();
   const payload={agency_name:name,agency_address:agencyForm.agency_address.trim(),agency_city:agencyForm.agency_city.trim()||null,agency_state:agencyForm.agency_state.trim()||null,agency_zip:agencyForm.agency_zip.trim()||null,city_state_zip:location,updated_by:userId};
   const result=editingAgency?await supabase.from('business_rules_agencies').update(payload).eq('id',editingAgency.id).eq('updated_at',editingAgency.updated_at).select('id').maybeSingle():await supabase.from('business_rules_agencies').insert({...payload,created_by:userId}).select('id').single();
   if(result.error)throw new Error(result.error.code==='23505'?'This agency already exists. Edit it in the list below.':result.error.message);
   if(!result.data)throw new Error('This agency changed or is unavailable. Refresh and review it before saving.');
   setEditingAgency(null);setAgencyForm(blankAgency);if(await load()){setAgencyId(result.data.id);setReportAgencyId(result.data.id);setMessage('Agency saved.');}
  }catch(e){setError(e instanceof Error?e.message:'Unable to save agency.');}finally{setBusy(false);}
 }
 async function saveItem(event:FormEvent){
  event.preventDefault();if(!canManage||busy||loading)return;setBusy(true);setError('');setMessage('');
  try{
   const payload={...itemForm,name:itemForm.name.trim().replace(/\s+/g,' '),description:itemForm.description.trim(),expected_outcome:itemForm.expected_outcome.trim(),updated_by:userId};
   if(!payload.name||!payload.description)throw new Error('Item name and description are required.');
   const result=editingItem?await supabase.from('resource_items').update(payload).eq('id',editingItem.id).eq('updated_at',editingItem.updated_at).select('id').maybeSingle():await supabase.from('resource_items').insert({...payload,created_by:userId}).select('id').single();
   if(result.error)throw new Error(result.error.code==='23505'?'This item name and type already exist. Edit the saved item below.':result.error.message);
   if(!result.data)throw new Error('This item changed or is unavailable. Refresh and review it before saving.');
   setEditingItem(null);setItemForm(blankItem);if(await load()){setItemId(result.data.id);setMessage('Item saved.');}
  }catch(e){setError(e instanceof Error?e.message:'Unable to save item.');}finally{setBusy(false);}
 }
 async function saveAssignment(event:FormEvent){
  event.preventDefault();if(!canManage||busy||loading)return;setBusy(true);setError('');setMessage('');
  try{
   const value=Number(retention);if(!agency?.active||!items.some(i=>i.id===itemId))throw new Error('Choose an active agency and a saved item.');
   if(!source.trim()||!Number.isInteger(value)||value<1||value>9999)throw new Error('Enter a data source and a whole retention period from 1 to 9999.');
   const payload={agency_id:agencyId,item_id:itemId,data_source:source.trim(),retention_value:value,retention_unit:unit,updated_by:userId};
   const result=selectedAssignment?await supabase.from('agency_item_assignments').update(payload).eq('id',selectedAssignment.id).eq('updated_at',selectedAssignment.updated_at).select('id').maybeSingle():await supabase.from('agency_item_assignments').insert({...payload,created_by:userId}).select('id').single();
   if(result.error)throw new Error(result.error.code==='23505'?'This assignment was saved by another user. Refresh and review it before saving.':result.error.message);
   if(!result.data)throw new Error('This assignment changed or is unavailable. Refresh and review it before saving.');
   if(await load())setMessage('Agency item assignment saved.');
  }catch(e){setError(e instanceof Error?e.message:'Unable to save assignment.');}finally{setBusy(false);}
 }
 async function exportPdf(){
  if(!reportAgency||loading||busy||error)return;setBusy(true);setMessage('');
  try{const {downloadAgencyRulesPdf}=await import('./export-pdf');downloadAgencyRulesPdf(reportAgency,items,assignments);setMessage('PDF exported for '+reportAgency.agency_name+'.');}catch(e){setError(e instanceof Error?e.message:'Unable to export PDF. Please try again.');}finally{setBusy(false);}
 }
 if(access!=='allowed')return <main className="shell"><section className="card"><h1>Agency Business Rules</h1><p>{access==='checking'?'Checking Backtrace access…':error||'Sign in through Training Administration.'}</p>{access==='denied'&&<a href="/">Return to sign in</a>}</section></main>;
 const disabled=busy||loading;
 return <main className={'shell '+styles.page}>
  <header className={styles.header}><div><span className="library-eyebrow">BUSINESS RULES</span><h1>Agency Business Rules</h1></div><a href="/">Back to dashboard</a></header>
  <nav className={styles.tabs} role="tablist" aria-label="Agency business rules">{tabs.map(([id,label])=><button type="button" key={id} role="tab" id={'rules-tab-'+id} aria-controls={'rules-panel-'+id} aria-selected={tab===id} onClick={()=>{setTab(id);setMessage('');}}>{label}</button>)}</nav>
  {!canManage&&<p className={styles.description}>Read-only access. Administrators and Coordinators maintain these records.</p>}
  {error&&<div className={styles.error} role="alert">{error} <button type="button" disabled={disabled} onClick={()=>void load()}>Refresh records</button></div>}
  {message&&<p role="status" aria-live="polite">{message}</p>}{loading&&<p role="status">Loading saved records…</p>}
  <section id="rules-panel-agencies" role="tabpanel" aria-labelledby="rules-tab-agencies" hidden={tab!=='agencies'}>
   <p className={styles.description}>{descriptions.agencies}</p>
   {canManage&&<form className={styles.panel} onSubmit={saveAgency}><div className={styles.importHeading}><h2>{editingAgency?'Edit agency':'Create agency'}</h2><button type="button" disabled={disabled} onClick={()=>importInput.current?.click()}>Import Data</button></div><input ref={importInput} type="file" accept=".csv,text/csv" hidden aria-label="Agency import CSV" onChange={e=>{const file=e.target.files?.[0];e.target.value='';if(file)void previewImport(file);}}/><p className={styles.description}>Import agencies from CSV. <button type="button" disabled={disabled} onClick={downloadTemplate}>Download template</button> · Name and address only. Existing agencies are skipped.</p><fieldset className={styles.fields} disabled={disabled}>
    <label className={styles.full}>Agency name<input required maxLength={160} value={agencyForm.agency_name} onChange={e=>setAgencyForm({...agencyForm,agency_name:e.target.value})}/></label>
    <label className={styles.full}>Street address<input maxLength={250} value={agencyForm.agency_address} onChange={e=>setAgencyForm({...agencyForm,agency_address:e.target.value})}/></label>
    <label>City<input maxLength={120} value={agencyForm.agency_city} onChange={e=>setAgencyForm({...agencyForm,agency_city:e.target.value})}/></label>
    <label>State<input maxLength={60} value={agencyForm.agency_state} onChange={e=>setAgencyForm({...agencyForm,agency_state:e.target.value})}/></label>
    <label>ZIP<input maxLength={20} value={agencyForm.agency_zip} onChange={e=>setAgencyForm({...agencyForm,agency_zip:e.target.value})}/></label>
    {editingAgency&&!editingAgency.agency_city&&!editingAgency.agency_state&&!editingAgency.agency_zip&&agencyForm.city_state_zip&&<p className={styles.description}>Existing location: {agencyForm.city_state_zip}. Enter City, State, and ZIP to update it.</p>}
    <div className={styles.actions}><button type="submit" className={styles.primary}>{busy?'Saving…':'Save agency'}</button><button type="button" onClick={()=>{setEditingAgency(null);setAgencyForm(blankAgency);}}>New agency</button></div>
   </fieldset></form>}
   {canManage&&importRows.length>0&&<section className={styles.panel} aria-label="Agency import preview"><h2>Review import</h2><p>{importFile} · {importPreview.filter(r=>!r.duplicate).length} new · {importPreview.filter(r=>r.duplicate).length} duplicates to skip</p><p className={styles.description}>Review spelling and abbreviations against existing agencies below. Different names need review before importing. Existing records and business rules will not be changed.</p><div className={styles.importTable}><table><thead><tr><th>Agency</th><th>Address</th><th>Action</th></tr></thead><tbody>{importPreview.map((r,i)=><tr key={i}><td>{r.agency_name}</td><td>{[r.agency_address,r.agency_city,r.agency_state,r.agency_zip].filter(Boolean).join(', ')}</td><td>{r.duplicate?'Skip duplicate':<button disabled={disabled} type="button" onClick={()=>setImportRows(rows=>rows.filter((_,j)=>j!==i))}>Exclude row</button>}</td></tr>)}</tbody></table></div><div className={styles.actions}><button className={styles.primary} disabled={disabled||importPreview.every(r=>r.duplicate)} onClick={()=>void importAgencies()}>{busy?'Importing…':'Import new agencies'}</button><button disabled={disabled} onClick={()=>{setImportRows([]);setImportFile('');}}>Cancel import</button></div></section>}
   <div className={styles.panel}><h2>Existing agencies</h2>{agencies.map(row=><div className={styles.row} key={row.id}><div><h3>{row.agency_name}{!row.active?' (Inactive)':''}</h3><p>{agencyAddress(row)||'No address saved.'}</p></div>{canManage&&<div className={styles.rowActions}><button disabled={disabled} onClick={()=>editAgency(row)}>Edit</button><button disabled={disabled||!row.active} onClick={()=>{setAgencyId(row.id);setTab('assign');}}>Attach item</button></div>}</div>)}{!loading&&!agencies.length&&<p>No agencies saved yet.</p>}</div>
  </section>
  <section id="rules-panel-items" role="tabpanel" aria-labelledby="rules-tab-items" hidden={tab!=='items'}>
   <p className={styles.description}>{descriptions.items}</p>
   {canManage&&<form className={styles.panel} onSubmit={saveItem}><h2>{editingItem?'Edit item':'Create item'}</h2><fieldset className={styles.fields} disabled={disabled}>
    <label>Item type<select value={itemForm.item_type} onChange={e=>setItemForm({...itemForm,item_type:e.target.value})}>{['Tool','Dashboard','Smart Tool','Misc.'].map(t=><option key={t}>{t}</option>)}</select></label>
    <label>Item name<input required maxLength={160} value={itemForm.name} onChange={e=>setItemForm({...itemForm,name:e.target.value})}/></label>
    <label className={styles.full}>Description<textarea required maxLength={4000} rows={3} value={itemForm.description} onChange={e=>setItemForm({...itemForm,description:e.target.value})}/></label>
    <label className={styles.full}>Expected outcome from using this item<textarea maxLength={2000} rows={3} placeholder="Describe the result users should achieve." value={itemForm.expected_outcome} onChange={e=>setItemForm({...itemForm,expected_outcome:e.target.value})}/></label>
    <div className={styles.actions}><button type="submit" className={styles.primary}>{busy?'Saving…':'Save item'}</button><button type="button" onClick={()=>{setEditingItem(null);setItemForm(blankItem);}}>New item</button></div>
   </fieldset></form>}
   <div className={styles.panel}><h2>Saved items</h2>{items.map(row=><div className={styles.row} key={row.id}><div><span className={styles.badge}>{row.item_type}</span><h3>{row.name}</h3><p>{row.description}</p>{row.expected_outcome&&<p><strong>Expected outcome:</strong> {row.expected_outcome}</p>}</div>{canManage&&<button disabled={disabled} onClick={()=>editItem(row)}>Edit</button>}</div>)}{!loading&&!items.length&&<p>No items saved yet.</p>}</div>
  </section>
  <section id="rules-panel-assign" role="tabpanel" aria-labelledby="rules-tab-assign" hidden={tab!=='assign'}>
   <p className={styles.description}>{descriptions.assign}</p>
   <form className={styles.panel} onSubmit={saveAssignment}><h2>Attach an agency to an item</h2>
    <fieldset className={styles.group} disabled={disabled}><legend>Agency Information</legend><label>Agency<select required value={agencyId} onChange={e=>setAgencyId(e.target.value)}><option value="">Choose agency</option>{agencies.map(a=><option key={a.id} value={a.id}>{a.agency_name}{!a.active?' (Inactive)':''}</option>)}</select></label>{canManage&&<button type="button" onClick={()=>{setEditingAgency(null);setAgencyForm(blankAgency);setTab('agencies');}}>Create agency</button>}{agency&&<p>{agencyAddress(agency)||'No address saved.'}</p>}</fieldset>
    <fieldset className={styles.group} disabled={disabled||!canManage}><legend>Tool Assignment</legend><div className={styles.fields}>
     <label className={styles.full}>Assigned Tool<select required value={itemId} onChange={e=>setItemId(e.target.value)}><option value="">Choose item</option>{items.map(i=><option key={i.id} value={i.id}>{i.name} · {i.item_type}</option>)}</select></label>
     <label className={styles.full}>Agency data source<input required maxLength={250} value={source} onChange={e=>setSource(e.target.value)}/></label>
     <label>Data retention period<input type="number" required min={1} max={9999} step={1} value={retention} onChange={e=>setRetention(e.target.value)}/></label>
     <label>Period unit<select value={unit} onChange={e=>setUnit(e.target.value)}>{['Days','Months','Years'].map(t=><option key={t}>{t}</option>)}</select></label>
    </div></fieldset>{canManage&&<button className={styles.primary} disabled={disabled||!agency?.active||!itemId} type="submit">{busy?'Saving…':selectedAssignment?'Update assignment':'Save assignment'}</button>}
   </form>
   <div className={styles.panel}><h2>Assignments for {agency?.agency_name||'selected agency'}</h2>{agencyAssignments.map(a=>{const item=items.find(i=>i.id===a.item_id);return <div className={styles.row} key={a.id}><div><h3>{item?.name||'Unavailable item'}</h3><p>{item?.item_type} · {a.data_source} · {a.retention_value} {a.retention_unit.toLowerCase()}</p></div>{canManage&&<button disabled={disabled} onClick={()=>{setItemId(a.item_id);setSource(a.data_source);setRetention(String(a.retention_value));setUnit(a.retention_unit);}}>Edit</button>}</div>;})}{!loading&&!agencyAssignments.length&&<p>No items assigned to this agency.</p>}</div>
  </section>
  <section id="rules-panel-report" role="tabpanel" aria-labelledby="rules-tab-report" hidden={tab!=='report'}>
   <p className={styles.description}>{descriptions.report}</p>
   <div className={styles.toolbar}><label>Report for agency<select value={reportAgencyId} disabled={disabled} onChange={e=>setReportAgencyId(e.target.value)}><option value="">Choose agency</option>{agencies.map(a=><option value={a.id} key={a.id}>{a.agency_name}{!a.active?' (Inactive)':''}</option>)}</select></label><button className={styles.primary} disabled={disabled||!reportAgency||!!error} onClick={()=>void exportPdf()}>{busy?'Exporting…':'Export PDF'}</button></div>
   {reportAgency&&<div className={styles.report}><h2>Agency Business Rules</h2><header><h3>{reportAgency.agency_name}</h3><p>{reportAgency.agency_address}</p><p>{agencyLocation(reportAgency)}</p></header>{reportAssignments.map(a=>{const item=items.find(i=>i.id===a.item_id);return <article className={styles.reportItem} key={a.id}><div className={styles.reportTitle}><h3>{item?.name||'Unavailable item'}</h3><span className={styles.badge}>{item?.item_type}</span></div><dl><div><dt>Data source</dt><dd>{a.data_source}</dd></div><div><dt>Retention</dt><dd>{a.retention_value} {a.retention_unit.toLowerCase()}</dd></div><div className={styles.full}><dt>Description</dt><dd>{item?.description}</dd></div><div className={styles.full}><dt>Expected outcome</dt><dd>{item?.expected_outcome||'Not specified'}</dd></div></dl></article>;})}{!reportAssignments.length&&<p>No items assigned to this agency.</p>}</div>}
  </section>
 </main>;
}
