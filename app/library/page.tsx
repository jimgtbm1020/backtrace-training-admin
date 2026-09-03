'use client';

import {useEffect,useMemo,useState} from 'react';
import {createClient,Session} from '@supabase/supabase-js';

type Role='admin'|'coordinator'|'trainer'|'viewer';
type Product={id:string;name:string;active:boolean|null};
type ProductModule={id:string;product_id:string;code:string|null;name:string;active:boolean|null;sort_order:number|null};
type Material={id:string;product_id:string;module_id:string|null;title:string;description:string|null;material_type:string;audience:string;active:boolean|null};
type Version={id:string;material_id:string;version_label:string;effective_date:string|null;status:string;is_current:boolean;storage_path:string;original_filename:string;mime_type:string;file_size:number;media_kind:string;download_allowed:boolean;notes:string|null;created_at:string};
type Jurisdiction={id:string;code:string;name:string};
type MaterialJurisdiction={material_id:string;jurisdiction_id:string};
type TrainingClass={id:string;request_number:string|null;agency_name:string|null;confirmed_date:string|null;status:string|null;class_status:string|null;assigned_trainer_id:string|null;created_by:string|null};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const TYPE_OPTIONS=[
  ['curriculum','Curriculum'],
  ['manual','Training Manual'],
  ['quick_reference','Quick Reference'],
  ['presentation','Presentation'],
  ['video','Video'],
  ['student_handout','Student Handout'],
  ['instructor_guide','Instructor Guide'],
  ['image','Images / Media'],
  ['bundle','Bundle'],
  ['other','Other']
] as const;
const typeLabel=(value:string|null|undefined)=>TYPE_OPTIONS.find(([code])=>code===value)?.[1]||String(value||'Other').replaceAll('_',' ').replace(/\b\w/g,m=>m.toUpperCase());
const audienceLabel=(value:string|null|undefined)=>value==='internal'?'Trainer Only':'Student + Trainer';
const fmtBytes=(value:number)=>value>=1024*1024?(value/(1024*1024)).toFixed(value>=10*1024*1024?0:1)+' MB':Math.max(1,Math.ceil(value/1024))+' KB';

export default function LibraryPage(){
  const [auth,setAuth]=useState<Session|null>(null);
  const [authChecked,setAuthChecked]=useState(false);
  const [role,setRole]=useState<Role|null>(null);
  const [products,setProducts]=useState<Product[]>([]);
  const [productModules,setProductModules]=useState<ProductModule[]>([]);
  const [jurisdictions,setJurisdictions]=useState<Jurisdiction[]>([]);
  const [materials,setMaterials]=useState<Material[]>([]);
  const [versions,setVersions]=useState<Version[]>([]);
  const [materialJurisdictions,setMaterialJurisdictions]=useState<MaterialJurisdiction[]>([]);
  const [classes,setClasses]=useState<TrainingClass[]>([]);
  const [loading,setLoading]=useState(true);
  const [error,setError]=useState('');
  const [message,setMessage]=useState('');

  const [search,setSearch]=useState('');
  const [type,setType]=useState('');
  const [state,setState]=useState('');
  const [productFilter,setProductFilter]=useState('');
  const [moduleFilter,setModuleFilter]=useState('');
  const [audienceFilter,setAudienceFilter]=useState('');

  const [selectedVersionIds,setSelectedVersionIds]=useState<string[]>([]);
  const [selectedClassId,setSelectedClassId]=useState('');
  const [shareUrl,setShareUrl]=useState('');

  const [showUpload,setShowUpload]=useState(false);
  const [versionMaterialId,setVersionMaterialId]=useState<string|null>(null);
  const [file,setFile]=useState<File|null>(null);
  const [resourceTitle,setResourceTitle]=useState('');
  const [resourceType,setResourceType]=useState('curriculum');
  const [selectedStates,setSelectedStates]=useState<string[]>([]);
  const [notes,setNotes]=useState('');
  const [productId,setProductId]=useState('');
  const [selectedModule,setSelectedModule]=useState('');
  const [versionLabel,setVersionLabel]=useState('1.0');
  const [effectiveDate,setEffectiveDate]=useState(new Date().toISOString().slice(0,10));
  const [audience,setAudience]=useState<'student'|'internal'>('student');
  const [downloadAllowed,setDownloadAllowed]=useState(true);
  const [stateSearch,setStateSearch]=useState('');
  const [showStatePicker,setShowStatePicker]=useState(false);
  const [uploadError,setUploadError]=useState('');
  const [uploading,setUploading]=useState(false);

  const [showVersions,setShowVersions]=useState(false);
  const [versionTitle,setVersionTitle]=useState('');
  const [versionRows,setVersionRows]=useState<Version[]>([]);

  const [showEmail,setShowEmail]=useState(false);
  const [emailMode,setEmailMode]=useState<'attendees'|'custom'>('attendees');
  const [customEmails,setCustomEmails]=useState('');
  const [emailDays,setEmailDays]=useState('30');
  const [emailBusy,setEmailBusy]=useState(false);

  const canManage=role==='admin'||role==='coordinator'||role==='trainer';

  useEffect(()=>{void initialize()},[]);

  async function initialize(){
    const {data}=await supabase.auth.getSession();
    setAuth(data.session);
    setAuthChecked(true);
    if(!data.session){setLoading(false);return;}
    const [{data:profile,error:profileError},{data:states,error:stateError}]=await Promise.all([
      supabase.from('profiles').select('role,active').eq('id',data.session.user.id).maybeSingle(),
      supabase.from('training_jurisdictions').select('id,code,name').eq('active',true).order('sort_order')
    ]);
    if(profileError||!profile?.active||stateError){
      setError(profileError?.message||stateError?.message||'Your Backtrace account is not active.');
      setLoading(false);
      return;
    }
    const currentRole=profile.role as Role;
    setRole(currentRole);
    setJurisdictions((states||[]) as Jurisdiction[]);
    await load(data.session,currentRole);
  }

  async function load(session=auth,currentRole=role){
    if(!session?.user){setLoading(false);return;}
    setLoading(true);setError('');setMessage('');
    const [productResult,moduleResult,materialResult,versionResult,jurisdictionResult,classResult]=await Promise.all([
      supabase.from('training_products').select('id,name,active').eq('active',true).order('name'),
      supabase.from('training_product_modules').select('id,product_id,code,name,active,sort_order').eq('active',true).order('sort_order'),
      supabase.from('training_materials').select('id,product_id,module_id,title,description,material_type,audience,active').eq('active',true).order('title'),
      supabase.from('training_material_versions').select('id,material_id,version_label,effective_date,status,is_current,storage_path,original_filename,mime_type,file_size,media_kind,download_allowed,notes,created_at').order('created_at',{ascending:false}),
      supabase.from('training_material_jurisdictions').select('material_id,jurisdiction_id'),
      supabase.from('training_requests').select('id,request_number,agency_name,confirmed_date,status,class_status,assigned_trainer_id,created_by').neq('class_status','Archived').is('archived_at',null).order('confirmed_date',{ascending:false,nullsFirst:false})
    ]);
    const bad=[productResult,moduleResult,materialResult,versionResult,jurisdictionResult,classResult].find(x=>x.error);
    if(bad?.error){setError(bad.error.message);setLoading(false);return;}
    setProducts((productResult.data||[]) as Product[]);
    setProductModules((moduleResult.data||[]) as ProductModule[]);
    setMaterials((materialResult.data||[]) as Material[]);
    setVersions((versionResult.data||[]) as Version[]);
    setMaterialJurisdictions((jurisdictionResult.data||[]) as MaterialJurisdiction[]);
    let classRows=(classResult.data||[]) as TrainingClass[];
    if(currentRole==='trainer')classRows=classRows.filter(r=>r.assigned_trainer_id===session.user.id||r.created_by===session.user.id);
    if(currentRole==='viewer')classRows=[];
    setClasses(classRows);
    const defaultProduct=(productResult.data||[])[0]?.id||'';
    setProductId(value=>value||defaultProduct);
    setSelectedVersionIds(ids=>ids.filter(id=>(versionResult.data||[]).some(v=>v.id===id&&v.is_current)));
    if(selectedClassId&&!classRows.some(r=>r.id===selectedClassId))setSelectedClassId('');
    setLoading(false);
  }

  const currentVersionMap=useMemo(()=>{
    const map=new Map<string,Version>();
    for(const version of versions)if(version.is_current&&!map.has(version.material_id))map.set(version.material_id,version);
    return map;
  },[versions]);
  const materialByVersion=useMemo(()=>{
    const map=new Map<string,Material>();
    for(const version of versions){const material=materials.find(m=>m.id===version.material_id);if(material)map.set(version.id,material);}
    return map;
  },[versions,materials]);
  const jurisdictionIdsByMaterial=useMemo(()=>{
    const map=new Map<string,string[]>();
    for(const row of materialJurisdictions)map.set(row.material_id,[...(map.get(row.material_id)||[]),row.jurisdiction_id]);
    return map;
  },[materialJurisdictions]);
  const usedJurisdictionIds=useMemo(()=>new Set(materialJurisdictions.filter(r=>materials.some(m=>m.id===r.material_id)).map(r=>r.jurisdiction_id)),[materialJurisdictions,materials]);
  const visibleStates=useMemo(()=>jurisdictions.filter(j=>usedJurisdictionIds.has(j.id)),[jurisdictions,usedJurisdictionIds]);
  const selectedVersions=useMemo(()=>versions.filter(v=>selectedVersionIds.includes(v.id)),[versions,selectedVersionIds]);
  const shareableSelection=selectedVersions.length>0&&selectedVersions.every(v=>materialByVersion.get(v.id)?.audience==='student');

  const filtered=useMemo(()=>materials.filter(item=>{
    const version=currentVersionMap.get(item.id);
    const product=products.find(p=>p.id===item.product_id)?.name||'';
    const module=productModules.find(m=>m.id===item.module_id)?.name||'';
    const haystack=[item.title,item.description,item.material_type,item.audience,version?.original_filename,version?.notes,product,module].join(' ').toLowerCase();
    return(!search||haystack.includes(search.toLowerCase()))
      &&(!type||item.material_type===type)
      &&(!state||(jurisdictionIdsByMaterial.get(item.id)||[]).includes(state))
      &&(!productFilter||item.product_id===productFilter)
      &&(!moduleFilter||item.module_id===moduleFilter)
      &&(!audienceFilter||item.audience===audienceFilter);
  }),[materials,currentVersionMap,products,productModules,search,type,state,productFilter,moduleFilter,audienceFilter,jurisdictionIdsByMaterial]);

  const typeOptions=useMemo(()=>TYPE_OPTIONS.filter(([code])=>materials.some(m=>m.material_type===code)||code===resourceType),[materials,resourceType]);
  const filterModules=useMemo(()=>productModules.filter(m=>!productFilter||m.product_id===productFilter),[productModules,productFilter]);
  const uploadModules=useMemo(()=>productModules.filter(m=>!productId||m.product_id===productId),[productModules,productId]);

  function stateLabel(j:Jurisdiction){return j.code.toUpperCase()==='GENERAL'?'National / General':j.name;}
  function resourceStates(materialId:string){
    const ids=jurisdictionIdsByMaterial.get(materialId)||[];
    return ids.map(id=>jurisdictions.find(j=>j.id===id)).filter((j):j is Jurisdiction=>Boolean(j));
  }

  async function openVersion(version:Version){
    const {data,error}=await supabase.storage.from('training-materials').createSignedUrl(version.storage_path,3600);
    if(error||!data?.signedUrl){setError(error?.message||'Unable to open this resource version.');return;}
    window.open(data.signedUrl,'_blank','noopener,noreferrer');
  }
  async function openResource(resource:Material){
    const version=currentVersionMap.get(resource.id);
    if(!version){setError('No published current version is available for this resource.');return;}
    await openVersion(version);
  }
  function openVersions(resource:Material){
    setVersionTitle(resource.title||'Resource versions');
    setVersionRows(versions.filter(v=>v.material_id===resource.id).sort((a,b)=>String(b.created_at).localeCompare(String(a.created_at))));
    setShowVersions(true);
  }
  async function makeCurrent(version:Version){
    if(!canManage){setError('Trainer, Coordinator, or Administrator permission is required.');return;}
    if(version.is_current)return;
    if(!window.confirm('Make version '+version.version_label+' the current published version?'))return;
    const {error}=await supabase.rpc('publish_training_material_version',{p_version_id:version.id});
    if(error){setError(error.message);return;}
    setShowVersions(false);setMessage('Current resource version updated.');
    if(auth)await load(auth,role);
  }
  async function archiveResource(resource:Material){
    if(!canManage){setError('Trainer, Coordinator, or Administrator permission is required.');return;}
    if(!window.confirm('Archive '+resource.title+'? Historical class links and versions will be preserved.'))return;
    const {error}=await supabase.from('training_materials').update({active:false,updated_at:new Date().toISOString()}).eq('id',resource.id);
    if(error)setError(error.message);else{setSelectedVersionIds(ids=>ids.filter(id=>materialByVersion.get(id)?.id!==resource.id));setMessage('Resource archived.');if(auth)await load(auth,role);}
  }

  function resetUpload(){
    setFile(null);setResourceTitle('');setResourceType('curriculum');setSelectedStates([]);setNotes('');
    setSelectedModule('');setVersionLabel('1.0');setEffectiveDate(new Date().toISOString().slice(0,10));
    setAudience('student');setDownloadAllowed(true);setStateSearch('');setShowStatePicker(false);setUploadError('');
    setVersionMaterialId(null);setProductId(products[0]?.id||'');
  }
  function openNewResource(){resetUpload();setShowUpload(true);}
  function openNewVersion(resource:Material){
    resetUpload();setVersionMaterialId(resource.id);setResourceTitle(resource.title);setProductId(resource.product_id);setSelectedModule(resource.module_id||'');setAudience(resource.audience==='internal'?'internal':'student');
    const current=currentVersionMap.get(resource.id);setVersionLabel(current?.version_label?'': '1.0');setShowUpload(true);
  }

  async function uploadResource(){
    if(!auth?.user||!canManage){setUploadError('Trainer, Coordinator, or Administrator permission is required.');return;}
    if(!file){setUploadError('Choose a file before uploading.');return;}
    if(file.size<=0||file.size>512*1024*1024){setUploadError('Files must be 512 MB or smaller.');return;}
    if(!versionLabel.trim()){setUploadError('Version is required.');return;}
    if(!versionMaterialId&&(!resourceTitle.trim()||!productId)){setUploadError('Resource title and product are required.');return;}
    setUploading(true);setUploadError('');setMessage('');
    let materialId=versionMaterialId;let createdMaterial=false;let storagePath='';let versionId='';
    try{
      if(!materialId){
        const {data:material,error}=await supabase.from('training_materials').insert({
          product_id:productId,module_id:selectedModule||null,title:resourceTitle.trim(),description:notes.trim()||null,
          material_type:resourceType,audience,active:true,created_by:auth.user.id
        }).select('id').single();
        if(error||!material)throw new Error(error?.message||'Unable to create resource record.');
        materialId=material.id;createdMaterial=true;
        const general=jurisdictions.find(j=>j.code.toUpperCase()==='GENERAL');
        const jurisdictionIds=selectedStates.length?selectedStates:(general?[general.id]:[]);
        if(!jurisdictionIds.length)throw new Error('Select at least one applicable state or National / General.');
        const {error:jurisdictionError}=await supabase.from('training_material_jurisdictions').insert(jurisdictionIds.map(jurisdiction_id=>({material_id:materialId!,jurisdiction_id})));
        if(jurisdictionError)throw new Error(jurisdictionError.message);
      }
      const cleanName=file.name.replace(/[^a-zA-Z0-9._-]/g,'-');
      storagePath=auth.user.id+'/'+materialId+'/'+crypto.randomUUID()+'-'+cleanName;
      const {error:storageError}=await supabase.storage.from('training-materials').upload(storagePath,file,{contentType:file.type||'application/octet-stream',upsert:false});
      if(storageError)throw new Error(storageError.message);
      const {data:version,error:versionError}=await supabase.from('training_material_versions').insert({
        material_id:materialId,version_label:versionLabel.trim(),effective_date:effectiveDate||null,status:'draft',is_current:false,
        storage_path:storagePath,original_filename:file.name,mime_type:file.type||'application/octet-stream',file_size:file.size,
        media_kind:file.type.startsWith('video/')?'video':file.type.startsWith('image/')?'image':'document',
        notes:notes.trim()||null,download_allowed:downloadAllowed,created_by:auth.user.id
      }).select('id').single();
      if(versionError||!version)throw new Error(versionError?.message||'Unable to create resource version.');
      versionId=version.id;
      const {error:publishError}=await supabase.rpc('publish_training_material_version',{p_version_id:version.id});
      if(publishError)throw new Error(publishError.message);
      setMessage(versionMaterialId?'New resource version published.':'Resource uploaded and published.');
      setShowUpload(false);resetUpload();
      await load(auth,role);
    }catch(e){
      if(versionId)await supabase.from('training_material_versions').delete().eq('id',versionId);
      if(storagePath)await supabase.storage.from('training-materials').remove([storagePath]);
      if(createdMaterial&&materialId)await supabase.from('training_materials').delete().eq('id',materialId);
      setUploadError(e instanceof Error?e.message:'Unable to upload resource.');
    }finally{setUploading(false);}
  }

  function toggleSelected(resource:Material){
    const version=currentVersionMap.get(resource.id);
    if(!version){setError('This resource has no current published version.');return;}
    setSelectedVersionIds(ids=>ids.includes(version.id)?ids.filter(id=>id!==version.id):[...ids,version.id]);
    setShareUrl('');
  }
  function requireSelection(){
    if(!selectedClassId){setError('Select a training class first.');return false;}
    if(!selectedVersionIds.length){setError('Select at least one resource first.');return false;}
    return true;
  }
  async function attachSelected(){
    if(!canManage||!requireSelection())return;
    setError('');setMessage('');
    const {error}=await supabase.from('training_class_materials').upsert(selectedVersionIds.map(material_version_id=>({request_id:selectedClassId,material_version_id})),{onConflict:'request_id,material_version_id',ignoreDuplicates:true});
    if(error)setError(error.message);else setMessage(selectedVersionIds.length+' resource'+(selectedVersionIds.length===1?'':'s')+' attached to class.');
  }
  async function copySecureLink(){
    if(!canManage||!requireSelection())return;
    if(!shareableSelection){setError('Secure student sharing is limited to Student + Trainer resources.');return;}
    setError('');setMessage('');setShareUrl('');
    const {data,error}=await supabase.rpc('create_training_material_share',{p_request_id:selectedClassId,p_material_version_ids:selectedVersionIds,p_expires_days:30});
    if(error){setError(error.message);return;}
    const url=data?.url||'';setShareUrl(url);
    try{await navigator.clipboard.writeText(url);setMessage('Secure 30-day student link copied.');}
    catch{setMessage('Secure 30-day student link created. Copy it below.');}
  }
  function openEmailDialog(){
    if(!canManage||!requireSelection())return;
    if(!shareableSelection){setError('Email distribution is limited to Student + Trainer resources.');return;}
    setEmailMode('attendees');setCustomEmails('');setEmailDays('30');setShowEmail(true);setError('');
  }
  async function queueEmails(){
    if(!selectedClassId||!selectedVersionIds.length)return;
    let recipients:string[]|null=null;
    if(emailMode==='custom'){
      recipients=customEmails.split(/[;,\n]+/).map(x=>x.trim().toLowerCase()).filter(Boolean);
      if(!recipients.length){setError('Enter at least one custom email address.');return;}
    }
    setEmailBusy(true);setError('');
    const {data,error}=await supabase.rpc('queue_training_material_distribution',{
      p_request_id:selectedClassId,p_material_version_ids:selectedVersionIds,p_recipient_emails:recipients,p_expires_days:Number(emailDays)
    });
    if(error)setError(error.message);
    else{setShowEmail(false);setMessage((data?.queued||0)+' training-material email record'+((data?.queued||0)===1?'':'s')+' queued. Automatic email delivery remains OFF.');}
    setEmailBusy(false);
  }

  function downloadCsv(){
    const header=['Title','Type','Product','Module','Audience','States','Current Version','Effective Date','Filename','Description'];
    const lines=materials.map(row=>{
      const version=currentVersionMap.get(row.id);const states=resourceStates(row.id).map(stateLabel).join('; ');
      return [row.title,typeLabel(row.material_type),products.find(p=>p.id===row.product_id)?.name||'',productModules.find(m=>m.id===row.module_id)?.name||'',audienceLabel(row.audience),states,version?.version_label||'',version?.effective_date||'',version?.original_filename||'',row.description||''];
    }).map(line=>line.map(value=>'"'+String(value??'').replaceAll('"','""')+'"').join(','));
    const blob=new Blob([[header.join(','),...lines].join('\n')],{type:'text/csv;charset=utf-8'});
    const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download='backtrace-training-library.csv';link.click();URL.revokeObjectURL(url);
  }

  if(!authChecked)return <main className="shell"><section className="card"><h1>Resource Library</h1><p>Checking Backtrace access…</p></section></main>;
  if(!auth)return <main className="shell"><section className="card"><h1>Resource Library</h1><p>Sign in through Training Administration to use the Resource Library.</p><a href="/">Return to sign in</a></section></main>;

  return <main className="shell resource-library-page">
    <header className="resource-library-header"><div><div className="library-eyebrow">BACKTRACE</div><h1>Resource Library</h1><p>Upload once, classify resources, assign states, and deliver exact published versions to training classes.</p></div><div className="library-header-actions">{canManage&&<button className="read-only-button" onClick={openNewResource}>Add Resource</button>}<button className="read-only-button" disabled={!materials.length} onClick={downloadCsv}>Export CSV</button></div></header>

    {canManage&&selectedVersionIds.length>0&&<section className="resource-selection-bar"><div><strong>{selectedVersionIds.length} selected</strong><span>Select a class to attach, share, or queue the exact published versions shown.</span></div><div className="resource-selection-actions"><select value={selectedClassId} onChange={e=>{setSelectedClassId(e.target.value);setShareUrl('')}}><option value="">Select training class…</option>{classes.map(row=><option key={row.id} value={row.id}>{row.request_number||'Request'} · {row.agency_name||'Agency'}{row.confirmed_date?' · '+row.confirmed_date:''}</option>)}</select><button onClick={()=>void attachSelected()}>Attach to Class</button><button disabled={!shareableSelection} onClick={()=>void copySecureLink()}>Copy Secure Link</button><button className="primary-button" disabled={!shareableSelection} onClick={openEmailDialog}>Email Attendees</button><button onClick={()=>{setSelectedVersionIds([]);setShareUrl('')}}>Clear Selection</button></div>{shareUrl&&<div className="resource-share-result"><strong>Secure link</strong><input readOnly value={shareUrl}/><button onClick={()=>navigator.clipboard?.writeText(shareUrl)}>Copy</button></div>}</section>}

    <section className="library-browse-grid"><div className="library-panel"><h2>Browse by Resource Type</h2><p>Only resource types currently in the library appear here.</p><div className="type-cards"><button className={type===''?'browse-card selected':'browse-card'} onClick={()=>setType('')}><strong>{materials.length}</strong><b>All Resources</b><span>Everything available to trainers</span></button>{TYPE_OPTIONS.filter(([code])=>materials.some(m=>m.material_type===code)).map(([code,label])=><button key={code} className={type===code?'browse-card selected':'browse-card'} onClick={()=>setType(code)}><strong>{materials.filter(m=>m.material_type===code).length}</strong><b>{label}</b><span>Available training resources</span></button>)}</div></div><div className="library-panel"><h2>Browse by State</h2><p>State assignments come from the resource jurisdiction records.</p><div className="type-cards state-cards"><button className={state===''?'browse-card selected':'browse-card'} onClick={()=>setState('')}><strong>{materials.length}</strong><b>All States</b><span>All active resources</span></button>{visibleStates.map(item=><button key={item.id} className={state===item.id?'browse-card selected':'browse-card'} onClick={()=>setState(item.id)}><strong>{materialJurisdictions.filter(r=>r.jurisdiction_id===item.id&&materials.some(m=>m.id===r.material_id)).length}</strong><b>{item.code.toUpperCase()==='GENERAL'?'National / General':item.code}</b><span>{stateLabel(item)}</span></button>)}</div></div></section>

    <section className="library-content-grid"><aside className="library-filters"><h2>Refine Resources</h2><label>SEARCH<input value={search} onChange={event=>setSearch(event.target.value)} placeholder="Title, notes or file"/></label><label>STATE<select value={state} onChange={event=>setState(event.target.value)}><option value="">All States</option>{visibleStates.map(item=><option key={item.id} value={item.id}>{stateLabel(item)}</option>)}</select></label><label>RESOURCE TYPE<select value={type} onChange={event=>setType(event.target.value)}><option value="">All Resource Types</option>{TYPE_OPTIONS.map(([code,label])=><option key={code} value={code}>{label}</option>)}</select></label><details className="library-more-filters"><summary>More Filters</summary><label>PRODUCT<select value={productFilter} onChange={event=>{setProductFilter(event.target.value);setModuleFilter('')}}><option value="">All Products</option>{products.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>TOOL / MODULE<select value={moduleFilter} onChange={event=>setModuleFilter(event.target.value)}><option value="">All Modules</option>{filterModules.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>AUDIENCE<select value={audienceFilter} onChange={event=>setAudienceFilter(event.target.value)}><option value="">All Audiences</option><option value="student">Student + Trainer</option><option value="internal">Trainer Only</option></select></label></details><button className="clear-filters" onClick={()=>{setSearch('');setType('');setState('');setProductFilter('');setModuleFilter('');setAudienceFilter('')}}>Clear Filters</button><button className="load-library-button" disabled={loading} onClick={()=>void load()}>{loading?'Loading…':'Refresh Library'}</button></aside>

      <div className="resource-results"><div className="results-heading"><h2>{type?typeLabel(type):'All Resources'}</h2><span>{filtered.length} {filtered.length===1?'resource':'resources'}</span></div>{message&&<p className="upload-success" role="status">{message}</p>}{error&&<p className="error" role="alert">{error}</p>}{!loading&&!error&&!filtered.length&&<div className="empty-library"><h3>No resources found</h3><p>Try clearing the filters or refreshing the library.</p></div>}<div className="resource-card-grid">{filtered.map(resource=>{const version=currentVersionMap.get(resource.id);const states=resourceStates(resource.id);const selected=Boolean(version&&selectedVersionIds.includes(version.id));return <article className={selected?'resource-card selected-resource':'resource-card'} key={resource.id}><div className="resource-card-top"><div><span className="resource-type-label">{typeLabel(resource.material_type)}</span><h3>{resource.title}</h3></div>{canManage&&<label className="resource-select-check"><input type="checkbox" disabled={!version} checked={selected} onChange={()=>toggleSelected(resource)}/><span>Select</span></label>}</div><p className="resource-meta">{products.find(p=>p.id===resource.product_id)?.name||'Backtrace'}{resource.module_id?' · '+(productModules.find(m=>m.id===resource.module_id)?.name||'Module'):''} · {audienceLabel(resource.audience)}</p><p className="resource-description">{resource.description||version?.notes||'No description provided.'}</p><div className="resource-state-list">{states.length?states.map(item=><span className="resource-state" key={item.id}>{item.code.toUpperCase()==='GENERAL'?'National / General':item.code}</span>):<span className="resource-state">No state assignment</span>}</div>{version&&<p className="resource-version-meta">Version {version.version_label} · {version.status}{version.effective_date?' · '+version.effective_date:''} · {fmtBytes(version.file_size)}</p>}<div className="resource-actions"><button disabled={!version} onClick={()=>void openResource(resource)}>View</button><button onClick={()=>openVersions(resource)}>Versions</button>{canManage&&<><button onClick={()=>openNewVersion(resource)}>New Version</button><button className="archive-button" onClick={()=>void archiveResource(resource)}>Archive</button></>}</div></article>})}</div></div>
    </section>

    {showVersions&&<div className="upload-modal-backdrop"><section className="upload-modal" role="dialog" aria-modal="true"><header><div><h2>{versionTitle}</h2><p>Version history for this resource.</p></div><button className="modal-close" onClick={()=>setShowVersions(false)}>Close</button></header><div className="upload-body">{versionRows.length?<div className="version-history-list">{versionRows.map(row=><div className="version-history-row" key={row.id}><div><strong>Version {row.version_label}</strong><span>{row.original_filename} · {fmtBytes(row.file_size)} · {row.effective_date||'No effective date'}</span></div><span className="pill">{row.is_current?'Current':row.status}</span><div><button onClick={()=>void openVersion(row)}>View</button>{canManage&&!row.is_current&&<button onClick={()=>void makeCurrent(row)}>Make Current</button>}</div></div>)}</div>:<p>No versions found.</p>}</div><footer><button className="cancel-upload" onClick={()=>setShowVersions(false)}>Close</button></footer></section></div>}

    {showUpload&&canManage&&<div className="upload-modal-backdrop"><section className="upload-modal" role="dialog" aria-modal="true" aria-labelledby="upload-title"><header><div><h2 id="upload-title">{versionMaterialId?'New Resource Version':'Add Resource'}</h2><p>{versionMaterialId?'Upload and publish a new version of '+resourceTitle+'.':'Upload once. Resource type, audience, product, and state assignments define how the library is organized.'}</p></div><button className="modal-close" onClick={()=>{setShowUpload(false);resetUpload()}}>Close</button></header><div className="upload-body"><label className="drop-zone" onDragOver={event=>event.preventDefault()} onDrop={event=>{event.preventDefault();const dropped=event.dataTransfer.files?.[0];if(dropped){setFile(dropped);if(!resourceTitle)setResourceTitle(dropped.name.replace(/\.[^.]+$/,''))}}}><input type="file" onChange={event=>{const chosen=event.target.files?.[0]||null;setFile(chosen);if(chosen&&!resourceTitle)setResourceTitle(chosen.name.replace(/\.[^.]+$/,''))}}/><strong>{file?file.name:'Drop a resource file or video here'}</strong><span>{file?(fmtBytes(file.size)+' selected'):'or click to choose a file · up to 512 MB'}</span></label>{!versionMaterialId&&<><div className="upload-two-column"><label>RESOURCE TITLE<input value={resourceTitle} onChange={event=>setResourceTitle(event.target.value)} placeholder="Auto-filled from the file name"/></label><label>RESOURCE TYPE<select value={resourceType} onChange={event=>setResourceType(event.target.value)}>{TYPE_OPTIONS.map(([code,label])=><option key={code} value={code}>{label}</option>)}</select></label><label>PRODUCT<select value={productId} onChange={event=>{setProductId(event.target.value);setSelectedModule('')}}><option value="">Select product</option>{products.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>TOOL / MODULE<select value={selectedModule} onChange={event=>setSelectedModule(event.target.value)}><option value="">All / General</option>{uploadModules.map(item=><option key={item.id} value={item.id}>{item.name}</option>)}</select></label><label>AUDIENCE<select value={audience} onChange={event=>setAudience(event.target.value as 'student'|'internal')}><option value="student">Student + Trainer</option><option value="internal">Trainer Only</option></select></label></div><div className="upload-field-label state-picker-field"><span className="field-caption">APPLICABLE STATE(S)</span><span>Choose one or multiple states. Leave National / General selected when the resource applies everywhere.</span><div className="selected-state-summary">{selectedStates.length?selectedStates.map(id=>jurisdictions.find(item=>item.id===id)?.code||id).join(', '):'National / General'}</div><button type="button" className="state-picker-trigger" onClick={()=>setShowStatePicker(value=>!value)}><strong>Choose Applicable States</strong><span>⌄</span></button>{showStatePicker&&<div className="state-picker-menu"><label className="national-state-option"><input type="checkbox" checked={selectedStates.length===0} onChange={()=>setSelectedStates([])}/><span><strong>National / General</strong><small>Applies everywhere</small></span></label><input className="state-search-input" value={stateSearch} onChange={event=>setStateSearch(event.target.value)} placeholder="Search states by name or abbreviation..."/><div className="state-options">{jurisdictions.filter(item=>item.code.toUpperCase()!=='GENERAL'&&(item.name+' '+item.code).toLowerCase().includes(stateSearch.toLowerCase())).map(item=><label className="state-option" key={item.id}><input type="checkbox" checked={selectedStates.includes(item.id)} onChange={()=>setSelectedStates(current=>current.includes(item.id)?current.filter(id=>id!==item.id):[...current,item.id])}/><strong>{item.code}</strong><span>{item.name}</span></label>)}</div><button type="button" className="state-picker-done" onClick={()=>{setShowStatePicker(false);setStateSearch('')}}>Done</button></div>}</div></>}<label className="upload-field-label">NOTES<textarea value={notes} onChange={event=>setNotes(event.target.value)} placeholder="Optional notes about this resource, version, or when to use it"/></label><div className="additional-details-grid resource-version-fields"><label>VERSION<input value={versionLabel} onChange={event=>setVersionLabel(event.target.value)} placeholder="1.0"/></label><label>EFFECTIVE DATE<input type="date" value={effectiveDate} onChange={event=>setEffectiveDate(event.target.value)}/></label><label>FILE ACCESS<select value={downloadAllowed?'download':'view'} onChange={event=>setDownloadAllowed(event.target.value==='download')}><option value="download">Allow Download</option><option value="view">View / Stream Only</option></select></label></div>{uploadError&&<p className="error" role="alert">{uploadError}</p>}</div><footer><button className="cancel-upload" onClick={()=>{setShowUpload(false);resetUpload()}}>Cancel</button><button onClick={()=>void uploadResource()} disabled={uploading}>{uploading?'Uploading…':'Upload & Publish'}</button></footer></section></div>}

    {showEmail&&<div className="upload-modal-backdrop"><section className="upload-modal" role="dialog" aria-modal="true"><header><div><h2>Email Resources</h2><p>Queue secure training-material links for this class.</p></div><button className="modal-close" onClick={()=>setShowEmail(false)}>Close</button></header><div className="upload-body"><div className="communications-off-notice"><strong>Automatic email delivery is OFF.</strong><span>This action creates pending queue records only; it does not activate delivery, webhooks, or tracking.</span></div><label className="upload-field-label">RECIPIENTS<select value={emailMode} onChange={e=>setEmailMode(e.target.value as 'attendees'|'custom')}><option value="attendees">All Registered Attendees</option><option value="custom">Custom Email Addresses</option></select></label>{emailMode==='custom'&&<label className="upload-field-label">CUSTOM EMAILS<textarea value={customEmails} onChange={e=>setCustomEmails(e.target.value)} placeholder="name@example.com, second@example.com"/></label>}<label className="upload-field-label">SECURE LINK EXPIRES<select value={emailDays} onChange={e=>setEmailDays(e.target.value)}><option value="7">7 days</option><option value="30">30 days</option><option value="60">60 days</option><option value="90">90 days</option></select></label>{error&&<p className="error">{error}</p>}</div><footer><button className="cancel-upload" onClick={()=>setShowEmail(false)}>Cancel</button><button disabled={emailBusy} onClick={()=>void queueEmails()}>{emailBusy?'Queueing…':'Queue Emails'}</button></footer></section></div>}
  </main>;
}
