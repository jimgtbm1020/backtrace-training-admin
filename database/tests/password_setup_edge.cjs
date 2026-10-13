const fs=require('fs'),path=require('path'),assert=require('node:assert/strict'),ts=require('typescript');
let handler,role='admin',active=true,flag=false,amr=[],updates=[],creates=[],validCurrent=true;
const actor=()=>({id:'self',email:'self@example.test',app_metadata:{provider:'email',password_change_required:flag}});
class Query{select(){return this}eq(){return this}update(){return this}insert(){return Promise.resolve({error:null})}single(){return Promise.resolve({data:{id:'self',role,active},error:null})}maybeSingle(){return Promise.resolve({data:{id:'new'},error:null})}then(r){return Promise.resolve({error:null}).then(r)}}
const admin={from:()=>new Query(),auth:{getUser:async()=>({data:{user:actor()},error:null}),getClaims:async()=>({data:{claims:{amr}},error:null}),admin:{updateUserById:async(id,attrs)=>{updates.push({id,attrs});return {error:null}},createUser:async(attrs)=>{creates.push(attrs);return {data:{user:{id:'new'}},error:null}},deleteUser:async()=>({error:null})}}};
const verification={auth:{signInWithPassword:async()=>validCurrent?{data:{user:{id:'self'}},error:null}:{data:{user:null},error:new Error('invalid')},signOut:async()=>({error:null})}};
let source=fs.readFileSync('supabase/functions/manage-training-users/index.ts','utf8').replace(/^import .*;\n/gm,'');const code=ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
new Function('Deno','createClient',code)({env:{get:n=>n==='SUPABASE_SERVICE_ROLE_KEY'?'service':'anon'},serve:fn=>handler=fn},(url,key)=>key==='service'?admin:verification);
async function invoke(body,auth=true){const res=await handler(new Request('https://example.test',{method:'POST',headers:{'content-type':'application/json',...(auth?{authorization:'Bearer test'}:{})},body:JSON.stringify(body)}));return {status:res.status,body:await res.json()}}
(async()=>{
let r=await invoke({action:'create',email:'new@example.test',full_name:'QA',role:'trainer',temporary_password:'test-temporary-123'});assert.equal(r.status,200);assert.equal(creates[0].app_metadata.password_change_required,true);
r=await invoke({action:'reset_password',target_user_id:'other'});assert.equal(r.status,200);assert.equal(updates.at(-1).attrs.app_metadata.password_change_required,true);
role='trainer';flag=true;validCurrent=false;let n=updates.length;r=await invoke({action:'change_own_password',current_password:'wrong',new_password:'test-new-password'});assert.equal(r.status,400);assert.equal(updates.length,n);
validCurrent=true;r=await invoke({action:'change_own_password',current_password:'test-temp',new_password:'test-new-password',target_user_id:'other'});assert.equal(r.status,200);assert.equal(updates.at(-1).id,'self');assert.equal(updates.at(-1).attrs.app_metadata.password_change_required,false);assert.equal(updates.at(-1).attrs.app_metadata.provider,'email');
n=updates.length;r=await invoke({action:'change_own_password',recovery:true,new_password:'test-new-password'});assert.equal(r.status,403);assert.equal(updates.length,n);
amr=[{method:'recovery',timestamp:Math.floor(Date.now()/1000)}];r=await invoke({action:'change_own_password',recovery:true,new_password:'test-new-password'});assert.equal(r.status,200);
amr=[{method:'recovery',timestamp:1}];r=await invoke({action:'change_own_password',recovery:true,new_password:'test-new-password'});assert.equal(r.status,403);
active=false;r=await invoke({action:'change_own_password',current_password:'test-temp',new_password:'test-new-password'});assert.equal(r.status,403);
r=await invoke({action:'change_own_password'},false);assert.equal(r.status,401);
console.log('Edge tests passed: create/reset flags, current password verification, self-only update, server-verified recent recovery, inactive/anonymous denial.');
})().catch(e=>{console.error(e);process.exitCode=1});
