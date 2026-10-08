const fs=require('fs'),path=require('path'),ts=require('typescript'),assert=require('node:assert/strict');
const source=fs.readFileSync('app/library/business-rules/page.tsx','utf8');const mod={exports:{}};
new Function('require','module','exports',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,jsx:ts.JsxEmit.ReactJSX}}).outputText)(name=>name==='next/navigation'?{redirect:location=>{throw {location};}}:require(name),mod,mod.exports);
async function target(search){try{await mod.exports.default({searchParams:Promise.resolve(search)});assert.fail('Expected redirect');}catch(e){if(!e.location)throw e;return e.location;}}
(async()=>{
 assert.equal(await target({}),'/business-rules');
 assert.equal(await target({tab:'report'}),'/business-rules?tab=report');
 const url=new URL(await target({tab:'assign',agency:'Name & City',filter:['one','two'],next:'https://example.invalid'}),'https://app.example');
 assert.equal(url.pathname,'/business-rules');assert.equal(url.searchParams.get('tab'),'assign');assert.equal(url.searchParams.get('agency'),'Name & City');assert.deepEqual(url.searchParams.getAll('filter'),['one','two']);assert.equal(url.origin,'https://app.example');
 for(const name of ['page.tsx','types.ts','import-csv.ts','export-pdf.ts','rules.module.css'])assert(fs.existsSync(path.join('app/business-rules',name)));
 console.log('Business Rules navigation checks passed: legacy redirect, selected tabs, repeated/encoded parameters, fixed internal destination, and standalone module files.');
})().catch(e=>{console.error(e);process.exitCode=1;});
