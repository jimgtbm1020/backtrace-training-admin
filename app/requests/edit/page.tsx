'use client';

import {useEffect,useState} from 'react';
import {createClient,User} from '@supabase/supabase-js';

type Role='admin'|'coordinator'|'trainer'|'viewer';
type Request={
 id:string;request_number:string|null;agency_id:string|null;agency_name:string|null;agency_address:string|null;city_state_zip:string|null;
 contact_person:string|null;contact_phone:string|null;contact_email:string|null;trainer_contact_name:string|null;trainer_contact_email:string|null;trainer_contact_phone:string|null;
 requested_by:string|null;preferred_date:string|null;alternate_date:string|null;preferred_start_time:string|null;preferred_end_time:string|null;time_zone:string|null;
 confirmed_date:string|null;confirmed_start_time:string|null;training_location:string|null;training_format:string|null;teams_meeting_url:string|null;estimated_attendees:number|null;
 training_resources:string[]|null;basic_training:boolean|null;train_the_trainer:boolean|null;refresher_course:boolean|null;advanced_training:boolean|null;
 topics:string|null;experience_level:string|null;outcomes:string|null;additional_requirements:string|null;internal_notes:string|null;submission_source:string|null;
 total_minutes:number|null;status:string|null;class_status:string|null;created_by:string|null;assigned_trainer_id:string|null;
};
type Profile={role:Role|null;active:boolean|null;};
type Trainer={id:string;email:string|null;full_name:string|null;};
type Module={id:number;category:string|null;module_name:string|null;duration_minutes:number|null;sort_order:number|null;};
type EditForm={
 agency_name:string;agency_address:string;city_state_zip:string;contact_person:string;contact_phone:string;contact_email:string;
 trainer_contact_name:string;trainer_contact_email:string;trainer_contact_phone:string;requested_by:string;
 preferred_date:string;alternate_date:string;preferred_start_time:string;preferred_end_time:string;time_zone:string;
 confirmed_date:string;confirmed_start_time:string;training_location:string;training_format:string;teams_meeting_url:string;estimated_attendees:string;
 training_resources:string[];basic_training:boolean;train_the_trainer:boolean;refresher_course:boolean;advanced_training:boolean;
 topics:string;experience_level:string;outcomes:string;additional_requirements:string;internal_notes:string;assigned_trainer_id:string;
};

const supabase=createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const lockedStatuses=new Set(['completed','closed','archived','cancelled','finalized']);
const resources=['Projector (No Cables)','Projector (With Cables)','TV (HDMI Cable Needed)','TV (HDMI Cable Available)','Wi-Fi','Computer with Wi-Fi','No Wi-Fi'];
const emptyForm:EditForm={agency_name:'',agency_address:'',city_state_zip:'',contact_person:'',contact_phone:'',contact_email:'',trainer_contact_name:'',trainer_contact_email:'',trainer_contact_phone:'',requested_by:'',preferred_date:'',alternate_date:'',preferred_start_time:'',preferred_end_time:'',time_zone:'Eastern',confirmed_date:'',confirmed_start_time:'',training_location:'',training_format:'In Person',teams_meeting_url:'',estimated_attendees:'',training_resources:[],basic_training:false,train_the_trainer:false,refresher_course:false,advanced_training:false,topics:'',experience_level:'',outcomes:'',additional_requirements:'',internal_notes:'',assigned_trainer_id:''};

function toForm(request:Request):EditForm{return {
 agency_name:request.agency_name||'',agency_address:request.agency_address||'',city_state_zip:request.city_state_zip||'',
 contact_person:request.contact_person||'',contact_phone:request.contact_phone||'',contact_email:request.contact_email||'',
 trainer_contact_name:request.trainer_contact_name||'',trainer_contact_email:request.trainer_contact_email||'',trainer_contact_phone:request.trainer_contact_phone||'',
 requested_by:request.requested_by||'',preferred_date:request.preferred_date||'',alternate_date:request.alternate_date||'',
 preferred_start_time:(request.preferred_start_time||'').slice(0,5),preferred_end_time:(request.preferred_end_time||'').slice(0,5),time_zone:request.time_zone||'Eastern',
 confirmed_date:request.confirmed_date||'',confirmed_start_time:(request.confirmed_start_time||'').slice(0,5),training_location:request.training_location||'',
 training_format:request.training_format||'In Person',teams_meeting_url:request.teams_meeting_url||'',estimated_attendees:request.estimated_attendees==null?'':String(request.estimated_attendees),
 training_resources:request.training_resources||[],basic_training:Boolean(request.basic_training),train_the_trainer:Boolean(request.train_the_trainer),
 refresher_course:Boolean(request.refresher_course),advanced_training:Boolean(request.advanced_training),topics:request.topics||'',experience_level:request.experience_level||'',
 outcomes:request.outcomes||'',additional_requirements:request.additional_requirements||'',internal_notes:request.internal_notes||'',assigned_trainer_id:request.assigned_trainer_id||''
};}

export default function TrainingRequestEditPage(){
 const [requests,setRequests]=useState<Request[]>([]);const [trainers,setTrainers]=useState<Trainer[]>([]);const [modules,setModules]=useState<Module[]>([]);
 const [requestModules,setRequestModules]=useState<Record<string,number[]>>({});const [selectedModuleIds,setSelectedModuleIds]=useState<number[]>([]);
 const [selected,setSelected]=useState<Request|null>(null);const [form,setForm]=useState<EditForm>(emptyForm);
 const [user,setUser]=useState<User|null>(null);const [profile,setProfile]=useState<Profile|null>(null);const [loading,setLoading]=useState(false);
 const [saving,setSaving]=useState(false);const [message,setMessage]=useState('');const [error,setError]=useState('');const [ready,setReady]=useState(false);

 useEffect(()=>{void initialize()},[]);

 async function initialize(){
  const {data}=await supabase.auth.getUser();
  if(!data.user){setError('Administrator sign-in is required.');setReady(true);return;}
  setUser(data.user);
  const {data:row,error:profileError}=await supabase.from('profiles').select('role,active').eq('id',data.user.id).maybeSingle();
  if(profileError||!row?.active){setError('Your active profile could not be verified.');setReady(true);return;}
  setProfile(row as Profile);
  const [{data:trainerRows},{data:moduleRows}]=await Promise.all([
   supabase.from('profiles').select('id,email,full_name').eq('role','trainer').eq('active',true).order('email'),
   supabase.from('training_modules').select('id,category,module_name,duration_minutes,sort_order').eq('active',true).order('category').order('sort_order')
  ]);
  setTrainers((trainerRows??[]) as Trainer[]);setModules((moduleRows??[]) as Module[]);
  const loaded=await loadRequests();
  const requestId=new URLSearchParams(window.location.search).get('request');
  if(requestId){
   const request=loaded.find(item=>item.id===requestId);
   if(!request)setError('The requested training record could not be found.');
   else if(canEditWith(request,row as Profile,data.user)){selectRequest(request);const {data:moduleLinks}=await supabase.from('request_modules').select('module_id').eq('request_id',request.id);setSelectedModuleIds((moduleLinks??[]).map(item=>Number(item.module_id)));}
   else setError('This request is locked or is not assigned to your account.');
  }
  setReady(true);
 }

 async function loadRequests(){
  setLoading(true);setError('');
  const [requestResult,moduleResult]=await Promise.all([
   supabase.from('training_requests').select('id,request_number,agency_id,agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,trainer_contact_name,trainer_contact_email,trainer_contact_phone,requested_by,preferred_date,alternate_date,preferred_start_time,preferred_end_time,time_zone,confirmed_date,confirmed_start_time,training_location,training_format,teams_meeting_url,estimated_attendees,training_resources,basic_training,train_the_trainer,refresher_course,advanced_training,topics,experience_level,outcomes,additional_requirements,internal_notes,submission_source,total_minutes,status,class_status,created_by,assigned_trainer_id').order('created_at',{ascending:false}),
   supabase.from('request_modules').select('request_id,module_id')
  ]);
  const loaded=(requestResult.data??[]) as Request[];
  if(requestResult.error||moduleResult.error)setError(requestResult.error?.message||moduleResult.error?.message||'Unable to load training requests.');
  else{
   setRequests(loaded);
   const map:Record<string,number[]>={};
   for(const row of moduleResult.data??[]){if(!map[row.request_id])map[row.request_id]=[];map[row.request_id].push(Number(row.module_id));}
   setRequestModules(map);
  }
  setLoading(false);return requestResult.error?[]:loaded;
 }

 function canEditWith(request:Request,p:Profile|null,u:User|null){
  const status=(request.class_status||request.status||'').trim().toLowerCase();if(lockedStatuses.has(status))return false;
  return p?.role==='admin'||p?.role==='coordinator'||(p?.role==='trainer'&&(request.created_by===u?.id||request.assigned_trainer_id===u?.id));
 }
 function canEdit(request:Request){return canEditWith(request,profile,user);}
 function selectRequest(request:Request){setSelected(request);setForm(toForm(request));setSelectedModuleIds(requestModules[request.id]||[]);setError('');setMessage('');}
 function choose(request:Request){if(!canEdit(request)){setError('This request is locked or is not assigned to your account.');return;}selectRequest(request);}
 function update<K extends keyof EditForm>(key:K,value:EditForm[K]){setForm(current=>({...current,[key]:value}));}
 function chooseType(key:'basic_training'|'train_the_trainer'|'refresher_course'|'advanced_training'){setForm(current=>({...current,basic_training:false,train_the_trainer:false,refresher_course:false,advanced_training:false,[key]:true}));if(key==='basic_training'||key==='train_the_trainer')setSelectedModuleIds([]);}
 function toggleResource(value:string){setForm(current=>({...current,training_resources:current.training_resources.includes(value)?current.training_resources.filter(item=>item!==value):[...current.training_resources,value]}));}
 function toggleModule(id:number){setSelectedModuleIds(ids=>ids.includes(id)?ids.filter(value=>value!==id):[...ids,id]);}

 async function save(){
  if(!selected?.id){setError('This request cannot be edited because it has no record ID.');return;}
  if(!window.confirm('Save these changes to this training request?'))return;
  setSaving(true);setError('');setMessage('');
  const {data}=await supabase.auth.getUser();if(!data.user){setError('Your session has expired.');setSaving(false);return;}
  if(profile?.role==='admin'){
   const typeCount=[form.basic_training,form.train_the_trainer,form.refresher_course,form.advanced_training].filter(Boolean).length;
   if(typeCount!==1){setError('Select exactly one Training Type Requested.');setSaving(false);return;}
   const payload={
    agency_id:selected.agency_id||'',agency_name:form.agency_name,agency_address:form.agency_address,city_state_zip:form.city_state_zip,
    contact_person:form.contact_person,contact_phone:form.contact_phone,contact_email:form.contact_email,
    trainer_contact_name:form.trainer_contact_name,trainer_contact_email:form.trainer_contact_email,trainer_contact_phone:form.trainer_contact_phone,
    preferred_date:form.preferred_date,alternate_date:form.alternate_date,preferred_start_time:form.preferred_start_time,preferred_end_time:form.preferred_end_time,time_zone:form.time_zone,
    training_format:form.training_format,estimated_attendees:form.estimated_attendees,training_location:form.training_location,training_resources:form.training_resources,
    objectives:'',topics:form.topics,experience_level:form.experience_level,outcomes:form.outcomes,additional_requirements:form.additional_requirements,requested_by:form.requested_by,
    submission_source:selected.submission_source||'internal',status:selected.status||'Received',assigned_trainer_id:selected.assigned_trainer_id||'',
    confirmed_date:selected.confirmed_date||'',confirmed_start_time:(selected.confirmed_start_time||'').slice(0,5),
    basic_training:form.basic_training,train_the_trainer:form.train_the_trainer,refresher_course:form.refresher_course,advanced_training:form.advanced_training,internal_notes:form.internal_notes
   };
   const {error:adminError}=await supabase.rpc('admin_save_training_request',{p_id:selected.id,p_data:payload,p_module_ids:selectedModuleIds});
   if(adminError){setError(adminError.message);setSaving(false);return;}
  }else{
   const manager=profile?.role==='coordinator';
   const changes=manager?{agency_name:form.agency_name,requested_by:form.requested_by,preferred_date:form.preferred_date,training_location:form.training_location,training_format:form.training_format,updated_by:data.user.id}:{agency_name:form.agency_name,requested_by:form.requested_by,preferred_date:form.preferred_date,training_format:form.training_format,updated_by:data.user.id};
   const {error:updateError}=await supabase.from('training_requests').update(changes).eq('id',selected.id);
   if(updateError){setError(updateError.message);setSaving(false);return;}
   const {error:activityError}=await supabase.from('training_request_activity').insert({request_id:selected.id,actor_id:data.user.id,action:'request_updated',details:{agency_name:form.agency_name,requested_by:form.requested_by,preferred_date:form.preferred_date,training_location:form.training_location,training_format:form.training_format}});
   if(activityError){setError('Request updated, but the activity log could not be written: '+activityError.message);setSaving(false);return;}
  }
  if(profile?.role==='admin'||profile?.role==='coordinator'){
   const {error:teamsError}=await supabase.rpc('set_training_request_teams_link',{p_request_id:selected.id,p_url:form.teams_meeting_url});
   if(teamsError){setError('Request details were saved, but the Teams meeting link was not updated: '+teamsError.message);setSaving(false);return;}
  }
  const loaded=await loadRequests();const updated=loaded.find(item=>item.id===selected.id);if(updated){setSelected(updated);setForm(toForm(updated));}
  setMessage('Training request updated.');setSaving(false);
 }

 async function schedule(){
  if(!selected?.id)return;const manager=profile?.role==='admin'||profile?.role==='coordinator';
  if(!manager){setError('Only an Administrator or Coordinator can confirm a training schedule.');return;}
  if(!form.confirmed_date||!form.confirmed_start_time||!form.assigned_trainer_id){setError('Confirmed date, start time, and assigned trainer are required.');return;}
  setSaving(true);setError('');setMessage('');
  const {data:conflicts,error:conflictError}=await supabase.rpc('training_schedule_conflicts',{p_request_id:selected.id,p_confirmed_date:form.confirmed_date,p_confirmed_start_time:form.confirmed_start_time,p_duration_minutes:selected.total_minutes||1,p_assigned_trainer_id:form.assigned_trainer_id});
  if(conflictError){setError(conflictError.message);setSaving(false);return;}
  if(conflicts?.length){const conflict=conflicts[0];setError('Schedule conflict: '+(conflict.request_number||'another class')+' · '+(conflict.agency_name||'agency')+' on '+conflict.confirmed_date+' at '+String(conflict.confirmed_start_time||'').slice(0,5)+'.');setSaving(false);return;}
  if(!window.confirm('Confirm this training schedule?')){setSaving(false);return;}
  const {error:scheduleError}=await supabase.rpc('set_training_schedule',{p_request_id:selected.id,p_confirmed_date:form.confirmed_date,p_confirmed_start_time:form.confirmed_start_time,p_assigned_trainer_id:form.assigned_trainer_id});
  if(scheduleError){setError(scheduleError.message);setSaving(false);return;}
  const {data:auth}=await supabase.auth.getUser();if(auth.user)await supabase.from('training_request_activity').insert({request_id:selected.id,actor_id:auth.user.id,action:'training_scheduled',details:{confirmed_date:form.confirmed_date,confirmed_start_time:form.confirmed_start_time,assigned_trainer_id:form.assigned_trainer_id}});
  const loaded=await loadRequests();const updated=loaded.find(item=>item.id===selected.id);if(updated){setSelected(updated);setForm(toForm(updated));}
  setMessage('Training schedule confirmed. This class is now available in Classes and Attendance.');setSaving(false);
 }

 const advanced=form.refresher_course||form.advanced_training;
 const groupedModules=[['advanced','Advanced Training Tools'],['dashboard','Dashboard Training Tools'],['smart','Smart Tools Training']] as const;

 if(!ready)return <main className="shell"><section className="card"><h1>Edit Training Requests</h1><p>Checking administrator permissions…</p></section></main>;
 if(error&&!requests.length)return <main className="shell"><section className="card"><h1>Edit Training Requests</h1><p>{error}</p><a href="/">Return to dashboard</a></section></main>;

 return <main className="shell request-edit-page"><header className="header"><div><div className="brand">Edit Training Requests</div><div className="subtitle">Role: {profile?.role||'Unassigned'} · completed records remain locked</div></div><a href="/">Back to dashboard</a></header>
 <section className="card"><div className="header"><h2>Training requests</h2><button disabled={loading} onClick={()=>void loadRequests()}>Refresh</button></div><p className="subtitle">Administrators can edit all submitted request fields. Administrators and Coordinators can confirm schedules. Trainers can edit only requests they created or were assigned.</p>{error&&<p className="error">{error}</p>}{message&&<p className="upload-success">{message}</p>}{loading&&<p>Loading requests…</p>}{requests.length>0&&<table className="table"><thead><tr><th>Request</th><th>Agency</th><th>Requester</th><th>Preferred</th><th>Confirmed</th><th>Status</th><th>Action</th></tr></thead><tbody>{requests.map((request,index)=>{const editable=canEdit(request);return <tr key={request.id||index}><td>{request.request_number||'—'}</td><td>{request.agency_name||'—'}</td><td>{request.requested_by||'—'}</td><td>{request.preferred_date||'—'}</td><td>{request.confirmed_date||'—'}{request.confirmed_start_time?' · '+request.confirmed_start_time.slice(0,5):''}</td><td><span className="pill">{request.status||request.class_status||'Open'}</span></td><td><button disabled={!editable} onClick={()=>choose(request)}>{editable?'Edit':'Locked'}</button></td></tr>)}</tbody></table>}{!loading&&!requests.length&&<p>No training requests found.</p>}</section>

 {selected&&<section className="card request-edit-card"><h2>Edit request {selected.request_number}</h2>
 {profile?.role==='admin'?<div className="admin-request-editor">
  <fieldset><legend>Agency Information</legend><div className="admin-edit-grid"><label>Agency Name<input value={form.agency_name} onChange={e=>update('agency_name',e.target.value)}/></label><label>Agency Address<input value={form.agency_address} onChange={e=>update('agency_address',e.target.value)}/></label><label>City, State, ZIP<input value={form.city_state_zip} onChange={e=>update('city_state_zip',e.target.value)}/></label><label>Contact Person<input value={form.contact_person} onChange={e=>update('contact_person',e.target.value)}/></label><label>Contact Phone<input value={form.contact_phone} onChange={e=>update('contact_phone',e.target.value)}/></label><label>Contact Email<input type="email" value={form.contact_email} onChange={e=>update('contact_email',e.target.value)}/></label></div></fieldset>
  <fieldset><legend>Agency Trainer Contact Information</legend><div className="admin-edit-grid"><label>Trainer Name<input value={form.trainer_contact_name} onChange={e=>update('trainer_contact_name',e.target.value)}/></label><label>Trainer Email<input type="email" value={form.trainer_contact_email} onChange={e=>update('trainer_contact_email',e.target.value)}/></label><label>Trainer Phone<input value={form.trainer_contact_phone} onChange={e=>update('trainer_contact_phone',e.target.value)}/></label><label>Requested By<input value={form.requested_by} onChange={e=>update('requested_by',e.target.value)}/></label></div></fieldset>
  <fieldset><legend>Requested Scheduling Information</legend><div className="admin-edit-grid"><label>Preferred Date<input type="date" value={form.preferred_date.slice(0,10)} onChange={e=>update('preferred_date',e.target.value)}/></label><label>Alternate Date<input type="date" value={form.alternate_date.slice(0,10)} onChange={e=>update('alternate_date',e.target.value)}/></label><label>Preferred Start<input type="time" value={form.preferred_start_time} onChange={e=>update('preferred_start_time',e.target.value)}/></label><label>Preferred End<input type="time" value={form.preferred_end_time} onChange={e=>update('preferred_end_time',e.target.value)}/></label><label>Time Zone<select value={form.time_zone} onChange={e=>update('time_zone',e.target.value)}><option>Eastern</option><option>Central</option><option>Mountain</option><option>Pacific</option></select></label><label>Training Format<select value={form.training_format} onChange={e=>update('training_format',e.target.value)}><option>In Person</option><option>Virtual</option><option>Hybrid</option></select></label><label>Estimated Attendees<input type="number" min="1" value={form.estimated_attendees} onChange={e=>update('estimated_attendees',e.target.value)}/></label><label>Training Location<input value={form.training_location} onChange={e=>update('training_location',e.target.value)}/></label></div></fieldset>
  <fieldset><legend>Available Agency Resources</legend><div className="admin-resource-grid">{resources.map(item=><label key={item}><input type="checkbox" checked={form.training_resources.includes(item)} onChange={()=>toggleResource(item)}/><span>{item}</span></label>)}</div></fieldset>
  <fieldset><legend>Training Type Requested</legend><div className="admin-training-types">{[['basic_training','Basic Backtrace Search Techniques'],['train_the_trainer','Train the Trainer Course'],['refresher_course','Refresher Course'],['advanced_training','Advanced Training']].map(([key,label])=><label key={key}><input type="radio" name="admin-training-type" checked={Boolean(form[key as keyof EditForm])} onChange={()=>chooseType(key as 'basic_training'|'train_the_trainer'|'refresher_course'|'advanced_training')}/><span>{label}</span></label>)}</div></fieldset>
  {advanced&&groupedModules.map(([category,title])=>{const available=modules.filter(module=>module.category===category);return <fieldset key={category}><legend>{title}</legend>{available.length?<div className="admin-module-grid">{available.map(module=><label key={module.id}><input type="checkbox" checked={selectedModuleIds.includes(module.id)} onChange={()=>toggleModule(module.id)}/><span>{module.module_name||'Training module'}<small>{module.duration_minutes?module.duration_minutes+' min':''}</small></span></label>)}</div>:<p>No modules available in this category.</p>}</fieldset>})}
  <fieldset><legend>Administrator Notes</legend><label>Internal Notes<textarea rows={4} value={form.internal_notes} onChange={e=>update('internal_notes',e.target.value)}/></label></fieldset>
 </div>:<div className="controls"><label>Agency<input value={form.agency_name} onChange={e=>update('agency_name',e.target.value)}/></label><label>Requester<input value={form.requested_by} onChange={e=>update('requested_by',e.target.value)}/></label><label>Preferred date<input type="date" value={form.preferred_date.slice(0,10)} onChange={e=>update('preferred_date',e.target.value)}/></label><label>Training format<select value={form.training_format} onChange={e=>update('training_format',e.target.value)}><option>In Person</option><option>Virtual</option><option>Hybrid</option></select></label><label>Training location<input disabled={profile?.role==='trainer'} value={form.training_location} onChange={e=>update('training_location',e.target.value)}/></label></div>}
 {(profile?.role==='admin'||profile?.role==='coordinator')&&<label className="teams-field">Microsoft Teams meeting link<input type="url" placeholder="https://teams.microsoft.com/..." value={form.teams_meeting_url} onChange={e=>update('teams_meeting_url',e.target.value)}/><small>Virtual and Hybrid training only. The server validates approved Microsoft Teams domains.</small>{form.teams_meeting_url&&<a href={form.teams_meeting_url} target="_blank" rel="noreferrer">Open Teams Meeting</a>}</label>}
 <div className="schedule-panel"><h3>Confirmed Schedule</h3><p className="subtitle">Confirming the schedule makes the request available in Classes and Attendance. Trainer conflicts are checked before saving.</p><div className="controls"><label>Confirmed date<input type="date" disabled={!['admin','coordinator'].includes(profile?.role||'')} value={form.confirmed_date.slice(0,10)} onChange={e=>update('confirmed_date',e.target.value)}/></label><label>Confirmed start time<input type="time" disabled={!['admin','coordinator'].includes(profile?.role||'')} value={form.confirmed_start_time} onChange={e=>update('confirmed_start_time',e.target.value)}/></label><label>Assigned trainer<select disabled={!['admin','coordinator'].includes(profile?.role||'')} value={form.assigned_trainer_id} onChange={e=>update('assigned_trainer_id',e.target.value)}><option value="">Unassigned</option>{trainers.map(trainer=><option key={trainer.id} value={trainer.id}>{trainer.full_name||trainer.email||trainer.id}</option>)}</select></label></div>{['admin','coordinator'].includes(profile?.role||'')&&<button disabled={saving} onClick={()=>void schedule()}>{saving?'Saving…':'Confirm Schedule'}</button>}</div>
 <div className="request-edit-actions"><button disabled={saving} onClick={()=>void save()}>{saving?'Saving…':'Save Request Details'}</button><button disabled={saving} onClick={()=>setSelected(null)}>Cancel</button></div>
 </section>}
 </main>;
}
