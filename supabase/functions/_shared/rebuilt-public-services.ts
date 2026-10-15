import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.57.4';
const cors={'Access-Control-Allow-Origin':'https://backtrace-training-admin.vercel.app','Access-Control-Allow-Headers':'authorization,apikey,content-type,x-client-info','Access-Control-Allow-Methods':'GET,POST,OPTIONS'};
const esc=(v:unknown)=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]!));
const json=(v:unknown,status=200)=>new Response(JSON.stringify(v),{status,headers:{...cors,'Content-Type':'application/json','Cache-Control':'no-store'}});
const page=(title:string,body:string,status=200)=>new Response(`<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${esc(title)}</title><style>body{font:18px system-ui;background:#eef2f7;color:#14253e;margin:0;padding:30px}main{max-width:720px;margin:auto;background:white;padding:32px;border-radius:12px}label{display:block;margin:20px 0}input{display:block;width:95%;font:inherit;padding:10px}button,a{font:inherit}button{background:#153a64;color:white;padding:12px 24px;border:0;border-radius:6px}</style><main><small>BACKTRACE TRAINING</small><h1>${esc(title)}</h1>${body}</main></html>`,{status,headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'no-store','Referrer-Policy':'no-referrer','Content-Security-Policy':"default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'"}});
export function serve(mode:string){Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response(null,{headers:cors});
 if(!['GET','POST'].includes(req.method))return json({error:'Method not allowed'},405);
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
 const url=new URL(req.url);
 try{
 if(mode==='request-password-reset'){
  if(req.method!=='POST')return json({error:'Method not allowed'},405);
  const generic={success:true};const body=await req.json();const email=String(body.email||'').trim().toLowerCase();
  if(email.length>254||!email.includes('@'))return json(generic);
  const ip=req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()||'unknown';
  const {data:allowed,error:limitError}=await admin.rpc('claim_password_reset',{p_email:email,p_ip:ip});
  if(limitError||!allowed)return json(generic);
  const {data:profile}=await admin.from('profiles').select('id').eq('email',email).eq('active',true).maybeSingle();
  if(!profile)return json(generic);
  const {data:settings}=await admin.from('training_email_provider_settings').select('api_key,enabled,from_email,from_name').eq('id',1).single();
  if(!settings?.enabled||!settings.api_key)return json(generic);
  const {data:link,error}=await admin.auth.admin.generateLink({type:'recovery',email});
  if(error||!link?.properties?.hashed_token)return json(generic);
  const target='https://backtrace-training-admin.vercel.app/#backtrace_recovery='+encodeURIComponent(link.properties.hashed_token);
  const result=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+settings.api_key,'Content-Type':'application/json','Idempotency-Key':'password-reset-'+crypto.randomUUID()},body:JSON.stringify({from:`${settings.from_name} <${settings.from_email}>`,to:[email],subject:'Reset your Backtrace password',text:`Open this link to choose a new password:\n\n${target}\n\nThis link can be used once. If you did not request it, you can ignore this email.`,html:`<h1>Reset your Backtrace password</h1><p><a href="${esc(target)}">Choose a new password</a></p><p>This link can be used once. If you did not request it, you can ignore this email.</p>`}),signal:AbortSignal.timeout(10000)});
  if(!result.ok)console.error('password_reset_delivery_failed',{status:result.status});
  return json(generic);
 }
 if(mode==='agency-training-portal'){
  if(req.method!=='POST')return json({error:'Method not allowed'},405);
  const b=await req.json();const {data,error}=await admin.rpc('agency_portal_action',{p_token:String(b.token||''),p_action:String(b.action||''),p_data:b.data||{},p_module_ids:Array.isArray(b.module_ids)?b.module_ids:[]});
  if(error)return json({error:error.message},400);return json(data);
 }
 if(mode==='training-attendance'){
  const token=url.searchParams.get('token')||'';let input:Record<string,unknown>|null=null;
  if(req.method==='POST'){const form=await req.formData();input=Object.fromEntries(form.entries());}
  const {data,error}=await admin.rpc('public_attendance_action',{p_token:token,p_data:input});
  if(error)return page('Attendance unavailable',`<p>${esc(error.message)}</p>`,400);
  if(input)return page('Attendance',`<p>${esc(data.message)}</p>`);
  return page('Training registration & check-in',`<p>${esc(data.agency_name)} · ${esc(data.request_number)}</p><p>${esc(data.confirmed_date)} · ${esc(data.class_status)}</p><form method="post"><label>Full name<input name="full_name" required minlength="2" maxlength="160"></label><label>Email<input name="email" type="email" required maxlength="254"></label><label>Badge / ID<input name="badge_id" required maxlength="100"></label><label>Title / position<input name="title_position" maxlength="160"></label><button type="submit">${data.registration_open?'Register':'Check in'}</button></form>`);
 }
 if(mode==='public-training-certificate'){
  const id=url.searchParams.get('certificate')||'';if(!/^[0-9a-f-]{36}$/i.test(id))return page('Certificate unavailable','<p>Invalid certificate link.</p>',404);
  const {data:a}=await admin.from('training_attendees').select('certificate_number,certificate_attendee_name_snapshot,certificate_agency_name_snapshot,certificate_training_type_snapshot,certificate_training_date_snapshot,certificate_trainer_name_snapshot').eq('certificate_public_id',id).maybeSingle();
  if(!a)return page('Certificate unavailable','<p>Certificate not found.</p>',404);
  return page('Certificate of Completion',`<p>This certifies that</p><h2>${esc(a.certificate_attendee_name_snapshot)}</h2><p>${esc(a.certificate_training_type_snapshot)}</p><p>${esc(a.certificate_agency_name_snapshot)}</p><p>${esc(a.certificate_training_date_snapshot)} · ${esc(a.certificate_trainer_name_snapshot)}</p><strong>${esc(a.certificate_number)}</strong><p>Use your browser’s Print command to save or print this certificate.</p>`);
 }
 if(mode==='training-materials-share'){
  const token=url.searchParams.get('token')||'';if(!/^[a-f0-9]{48}$/.test(token))return page('Materials unavailable','<p>Invalid share link.</p>',404);
  const digest=Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(token)))).map(x=>x.toString(16).padStart(2,'0')).join('');
  const {data:share}=await admin.from('training_material_share_links').select('id,active,expires_at').eq('token_hash',digest).maybeSingle();
  if(!share?.active||!share.expires_at||Date.parse(share.expires_at)<=Date.now())return page('Materials unavailable','<p>This link has expired or been revoked.</p>',404);
  const {data:items}=await admin.from('training_material_share_items').select('material_version_id').eq('share_id',share.id);
  const {data:versions}=await admin.from('training_material_versions').select('id,material_id,original_filename,storage_path,status,download_allowed').in('id',(items||[]).map(x=>x.material_version_id));
  let links='';for(const v of versions||[]){if(v.status!=='published')continue;const {data:m}=await admin.from('training_materials').select('title').eq('id',v.material_id).eq('audience','student').eq('active',true).maybeSingle();if(!m)continue;const {data:signed}=await admin.storage.from('training-materials').createSignedUrl(v.storage_path,300,{download:v.download_allowed?v.original_filename:false});if(signed?.signedUrl)links+=`<li><a rel="noreferrer" href="${esc(signed.signedUrl)}">${esc(m.title)}</a></li>`;}
  return page('Training materials',links?`<ul>${links}</ul><p>Download links expire after five minutes. Refresh this page for new links.</p>`:'<p>No published materials are currently available.</p>');
 }
 return json({error:'Not found'},404);
 }catch(error){console.error('public_service_failed',{mode,message:error instanceof Error?error.name:'error'});return mode==='request-password-reset'?json({success:true}):json({error:'Unable to complete this request. Please retry.'},500);}
});}
