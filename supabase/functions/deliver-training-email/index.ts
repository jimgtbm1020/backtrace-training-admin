import {createClient} from 'https://esm.sh/@supabase/supabase-js@2.57.4';
Deno.serve(async(req)=>{
 const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
 if(req.method!=='POST'||req.headers.get('Authorization')!=='Bearer '+key)return new Response('Unauthorized',{status:401});
 const admin=createClient(Deno.env.get('SUPABASE_URL')!,key,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data:s}=await admin.from('training_email_provider_settings').select('api_key,enabled,from_email,from_name').eq('id',1).single();
 if(!s?.enabled||!s.api_key)return Response.json({enabled:false});
 const {data:rows,error}=await admin.rpc('claim_training_email_batch');if(error)return Response.json({error:'Unable to claim queue'},{status:500});
 let sent=0;for(const q of rows||[]){let status=503,messageId:string|null=null;
 try{const r=await fetch('https://api.resend.com/emails',{method:'POST',headers:{Authorization:'Bearer '+s.api_key,'Content-Type':'application/json','Idempotency-Key':'backtrace-queue-'+q.id},body:JSON.stringify({from:`${s.from_name} <${s.from_email}>`,to:[q.recipient_email],subject:q.subject,...(q.text_body?{text:q.text_body}:{}),...(q.html_body?{html:q.html_body}:{})}),signal:AbortSignal.timeout(10000)});status=r.status;const result=await r.json();messageId=result.id||null;}catch{}
 const success=status>=200&&status<300;const retry=!success&&(status===429||status>=500)&&q.attempts<3;
 await admin.from('training_email_queue').update({status:success?'sent':retry?'pending':'failed',provider_message_id:messageId,last_error:success?null:'Provider HTTP '+status,sent_at:success?new Date().toISOString():null,next_attempt_at:retry?new Date(Date.now()+60000*q.attempts).toISOString():null,updated_at:new Date().toISOString()}).eq('id',q.id).eq('status','processing');
 await new Promise(resolve=>setTimeout(resolve,600));
 if(success){sent++;await admin.from('training_email_delivery_events').insert({queue_id:q.id,event_type:'sent',recipient_email:q.recipient_email});}
 }
 return Response.json({processed:rows?.length||0,sent});
});
