const fs=require('node:fs'),assert=require('node:assert/strict'),ts=require('typescript');
let role='admin',active=true,authenticated=true,profileError=false,providerCalls=0;
let providerStatus=200,providerOutput,providerError,providerWait,requestBody;
const output=description=>({status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({description,needs_more_detail:false})}]}]});
const db={auth:{getUser:async()=>({data:{user:authenticated?{id:'test-user'}:null},error:null})},from(table){assert.equal(table,'profiles');return {select(){return this},eq(){return this},async single(){return {data:{role,active},error:profileError?{message:'private database error'}:null}}}}};
const moduleObject={exports:{}};
const code=ts.transpileModule(fs.readFileSync('app/api/business-rules/description/route.ts','utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;
new Function('require','module','exports',code)(name=>name==='@supabase/supabase-js'?{createClient:()=>db}:require(name),moduleObject,moduleObject.exports);
const {POST}=moduleObject.exports;
process.env.NEXT_PUBLIC_SUPABASE_URL='https://example.supabase.co';
process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY='public-test-key';
process.env.OPENAI_API_KEY='private-test-key';
global.fetch=async(url,options)=>{
 providerCalls++;assert.equal(url,'https://api.openai.com/v1/responses');
 assert.equal(options.headers.Authorization,'Bearer private-test-key');
 requestBody=JSON.parse(options.body);
 if(providerWait)await providerWait;
 if(providerError)throw providerError;
 return Response.json(providerOutput||output('Arrest Tool displays supplied arrest history and supports Excel exports.'),{status:providerStatus});
};
const body={name:'Arrest Tool',item_type:'Tool',description:'',expected_outcome:'',notes:'Shows arrest history. Export to Excel.'};
const request=(data=body,authorization='Bearer staff-token')=>new Request('https://example.test/api/business-rules/description',{method:'POST',headers:{authorization,'Content-Type':'application/json'},body:JSON.stringify(data)});
async function expectStatus(expected,req=request()){
 const result=await POST(req);assert.equal(result.status,expected);assert.equal(result.headers.get('cache-control'),'private, no-store');return result.json();
}
(async()=>{
 await expectStatus(401,request(body,''));assert.equal(providerCalls,0);
 authenticated=false;await expectStatus(401);authenticated=true;
 for(const denied of ['trainer','viewer','unknown']){role=denied;await expectStatus(403);}
 role='admin';active=false;await expectStatus(403);active=true;
 profileError=true;await expectStatus(403);profileError=false;
 assert.equal(providerCalls,0);
 for(const invalid of [null,[],{}, {...body,name:''},{...body,name:'x'.repeat(161)},{...body,item_type:'Unsupported'},{...body,notes:'x'.repeat(2001)},{...body,notes:''},{...body,description:[]}]){
  await expectStatus(400,request(invalid));
 }
 await expectStatus(400,new Request('https://example.test/api',{method:'POST',headers:{authorization:'Bearer test'},body:'invalid JSON'}));
 await expectStatus(413,new Request('https://example.test/api',{method:'POST',headers:{authorization:'Bearer test'},body:'x'.repeat(32001)}));
 assert.equal(providerCalls,0);
 delete process.env.OPENAI_API_KEY;await expectStatus(503);process.env.OPENAI_API_KEY='private-test-key';
 for(const allowed of ['admin','coordinator']){
  role=allowed;const result=await expectStatus(200);assert.match(result.description,/Arrest Tool/);
  assert.equal(requestBody.store,false);assert.equal(requestBody.model,'gpt-6.1-terra');
  assert.equal(requestBody.text.format.strict,true);assert.equal(requestBody.max_output_tokens,1600);
  assert.equal(requestBody.input[1].content,JSON.stringify(body));
  assert.match(requestBody.input[0].content,/Do not invent/);
  assert.ok(!JSON.stringify(result).includes('private-test-key'));
 }
 role='admin';
 providerStatus=429;await expectStatus(502);providerStatus=500;await expectStatus(502);providerStatus=200;
 for(const invalid of [
  {status:'incomplete',output:[]},
  {status:'completed',output:[]},
  {status:'completed',output:[{type:'message',content:[{type:'output_text',text:'not json'}]}]},
  output(''),
  output('x'.repeat(4001))
 ]){providerOutput=invalid;await expectStatus(502);}
 providerOutput={status:'completed',output:[{type:'message',content:[{type:'refusal',refusal:'Provider-specific details'}]}]};await expectStatus(422);
 providerOutput={status:'completed',output:[{type:'message',content:[{type:'output_text',text:JSON.stringify({description:'',needs_more_detail:true})}]}]};await expectStatus(422);
 providerOutput=undefined;
 providerError=new DOMException('Timed out','TimeoutError');await expectStatus(502);providerError=undefined;
 let release;providerWait=new Promise(resolve=>{release=resolve});
 const startCount=providerCalls;const first=POST(request());
 while(providerCalls===startCount)await new Promise(resolve=>setImmediate(resolve));
 await expectStatus(429);assert.equal(providerCalls,startCount+1);
 release();assert.equal((await first).status,200);providerWait=undefined;
 await expectStatus(200);
 console.log('PASS: manager-only generation, validation and bounds, structured prompt, preview-only response, provider errors/refusal/timeout, duplicate requests, and retry.');
})().catch(error=>{console.error(error);process.exitCode=1});
