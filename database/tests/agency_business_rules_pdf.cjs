// Run from the repository root: node database/tests/agency_business_rules_pdf.cjs
const fs=require('fs'),path=require('path'),assert=require('node:assert/strict'),ts=require('typescript');
const {jsPDF}=require('jspdf');
const rendered=new WeakMap(),links=new WeakMap();
jsPDF.API.events.push(['initialized',function(){
 const doc=this,original=doc.text,originalLink=doc.link;rendered.set(doc,[]);links.set(doc,[]);
 doc.link=function(x,y,w,h,options){links.get(doc).push({x,y,w,h,page:doc.internal.getCurrentPageInfo().pageNumber,options});return originalLink.apply(doc,arguments);};
 doc.text=function(text,x,y,options={}){
  const lines=Array.isArray(text)?text:[text];
  rendered.get(doc).push({text:lines.join('\n'),x,y,font:doc.getFont().fontStyle,family:doc.getFont().fontName,size:doc.getFontSize(),page:doc.internal.getCurrentPageInfo().pageNumber});
  for(const [i,line] of lines.entries()){
   const width=doc.getTextWidth(line),left=options.align==='right'?x-width:x;
   assert(left>=25&&left+width<=587,'Text exceeds horizontal page bounds: '+line.slice(0,90));
   const baseline=y+i*doc.getFontSize()*(options.lineHeightFactor||1.15);
   assert(baseline>=20&&baseline<=775,'Text exceeds vertical page bounds: '+line.slice(0,90));
  }
  return original.apply(doc,arguments);
 };
}]);
const cache={};function load(file){if(cache[file])return cache[file].exports;const module={exports:{}};cache[file]=module;const code=ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;new Function('require','module','exports',code)(name=>name.startsWith('.')?load(path.resolve(path.dirname(file),name)+'.ts'):require(name),module,module.exports);return module.exports;}
const {buildAgencyRulesPdf}=load(path.resolve('app/business-rules/export-pdf.ts'));
const text=doc=>rendered.get(doc).map(x=>x.text).join('\n');
function verifyContents(doc,expected,cover=false){
 const calls=rendered.get(doc),annotations=links.get(doc),normalize=value=>value.replace(/\s+/g,' ').trim();
 assert(calls.some(call=>call.text==='Table of contents'&&call.page===(cover?2:1)),'Contents must follow the optional cover');
 for(const item of expected){
  const entries=calls.filter(call=>call.size===10.5&&normalize(call.text)===normalize(item.name)&&annotations.some(link=>link.page===call.page&&link.y+17===call.y));
  assert.equal(entries.length,1,'Each assigned item must appear once in contents: '+item.name);
  const entry=entries[0],link=annotations.find(link=>link.page===entry.page&&link.y+17===entry.y);
  const heading=calls.find(call=>call.size===14&&normalize(call.text)===normalize(item.name));
  assert(heading,'Item heading missing');assert.equal(link.options.pageNumber,heading.page,'Link must target the first item page');
  assert.equal(link.options.top,heading.y-24,'Link must target the item heading');
 }
 for(const link of annotations){
  assert(link.options.pageNumber>link.page&&link.options.pageNumber<=doc.getNumberOfPages(),'Contents link must target a report page');
  assert(calls.some(call=>call.page===link.page&&call.y===link.y+17&&call.x===558&&call.text===String(link.options.pageNumber-(cover?1:0))),'Printed contents page must match its destination and cover offset');
  assert(link.y+link.h<=738,'Contents row must stay above the footer');
 }
}
const agency={id:'one',agency_name:'County Agency',agency_address:'100 Main Street',city_state_zip:'County City, NJ 00000'};
const items=[{id:'tool',name:'Arrest Tool',item_type:'Tool',description:'Find arrest records.',expected_outcome:'Connect related cases.'},{id:'dashboard',name:'Agency Dashboard',item_type:'Dashboard',description:'Review activity.',expected_outcome:'Monitor changes.'}];
const assignments=[{agency_id:'one',item_id:'tool',data_source:'County Records Feed',retention_value:90,retention_unit:'Days'},{agency_id:'one',item_id:'dashboard',data_source:'County Activity Feed',retention_value:5,retention_unit:'Years'},{agency_id:'two',item_id:'tool',data_source:'OTHER AGENCY PRIVATE FEED',retention_value:999,retention_unit:'Months'}];
const compact=buildAgencyRulesPdf(agency,items,assignments);assert.equal(compact.getNumberOfPages(),2);assert(text(compact).includes('Agency Business Rules'));assert(text(compact).includes('County Records Feed'));assert(!text(compact).includes('OTHER AGENCY PRIVATE FEED'));assert(text(compact).includes('Page 1 of 2'));assert(compact.output().includes('/FontFile2'),'Font must be embedded');assert(compact.output().includes('/ToUnicode'),'Text must remain extractable');verifyContents(compact,items);
const longItems=[{...items[0],description:'Long description preserved. '.repeat(140),expected_outcome:'Outcome preserved. '.repeat(100)}];
const long=buildAgencyRulesPdf(agency,longItems,assignments.filter(a=>a.item_id==='tool'));assert(long.getNumberOfPages()>1);assert(text(long).includes('continued'));assert.equal((rendered.get(long).filter(x=>x.size===10.5).map(x=>x.text).join('').replace(/\s/g,'').match(/Longdescriptionpreserved\./g)||[]).length,140);assert.equal((rendered.get(long).filter(x=>x.size===10.5).map(x=>x.text).join('').replace(/\s/g,'').match(/Outcomepreserved\./g)||[]).length,100);
const none=buildAgencyRulesPdf(agency,items,[]);assert.equal(none.getNumberOfPages(),1);assert(text(none).includes('No items assigned to this agency.'));assert(!text(none).includes('Table of contents'));assert.equal(links.get(none).length,0);
const overviewAgency={...agency,overview_heading:'Core Features',overview_introduction:'Agency-specific introduction.',overview_features:'- **Person Reports** with source links.\n- **Data Integration** across records.\n\nIndependent agency wording.'};
const overview=buildAgencyRulesPdf(overviewAgency,items,assignments);assert(text(overview).includes('Core Features'));assert(!text(compact).includes('Core Features'));
const lengthy=buildAgencyRulesPdf({...overviewAgency,overview_features:overviewAgency.overview_features.repeat(60)},items,assignments);assert(lengthy.getNumberOfPages()>2);
const logo='data:image/png;base64,'+Buffer.from(require('fast-png').encode({width:1,height:1,data:new Uint8Array([30,70,120,255]),channels:4})).toString('base64');
const logoPdf=buildAgencyRulesPdf(agency,items,assignments,logo);assert(logoPdf.output().includes('/Subtype /Image'));
const cinematic=buildAgencyRulesPdf(agency,items,assignments,undefined,'data:image/png;base64,'+fs.readFileSync('public/report-covers/philadelphia-1776.png').toString('base64'));
assert.equal(cinematic.getNumberOfPages(),compact.getNumberOfPages()+1);assert(text(cinematic).includes('Date printed:'));assert(text(cinematic).includes('Page 1 of 2'));verifyContents(cinematic,items,true);
const formattingItem={...items[0],description:'The **Arrest Tool** preserves supplied wording.\n\n- Identify Individuals: Locate potential matches.\n- Document Findings: Export results to Excel.',expected_outcome:'__Review results__ before making a determination.\n\n**Unclosed marker stays intact.'};
const before=JSON.stringify(formattingItem),formatting=buildAgencyRulesPdf(agency,[formattingItem],[assignments[0]]),calls=rendered.get(formatting);
assert.equal(JSON.stringify(formattingItem),before);assert(calls.some(x=>x.text==='Arrest Tool'&&x.font==='bold'));assert(calls.some(x=>x.text==='Identify Individuals:'&&x.font==='bold'));assert(!text(formatting).includes('**Arrest Tool**'));assert(text(formatting).includes('**Unclosed marker stays intact.'));
const wide=buildAgencyRulesPdf(agency,[{...items[0],name:'Long name '.repeat(15),description:'X'.repeat(4000),expected_outcome:'Value '.repeat(120)}],[{...assignments[0],data_source:'Source '.repeat(100)}]);assert(wide.getNumberOfPages()>1);
verifyContents(wide,[{...items[0],name:'Long name '.repeat(15)}]);verifyContents(long,longItems);verifyContents(lengthy,items);
const manyItems=Array.from({length:57},(_,i)=>({...items[0],id:'item-'+i,name:'Catalog item '+String(i+1).padStart(2,'0'),item_type:i<50?'Tool':i<54?'Dashboard':i<56?'Smart Tool':'Misc.'}));
const manyAssignments=manyItems.map(item=>({...assignments[0],item_id:item.id}));
const many=buildAgencyRulesPdf(agency,[...manyItems,{...items[0],id:'private',name:'UNASSIGNED PRIVATE ITEM'}],[...manyAssignments,{...assignments[0],agency_id:'two',item_id:'private'}]);
verifyContents(many,manyItems);assert(rendered.get(many).filter(call=>call.text.startsWith('Table of contents')).length>1);assert(!text(many).includes('UNASSIGNED PRIVATE ITEM'));
const changed=buildAgencyRulesPdf(agency,[{...items[0],description:'Long description preserved. '.repeat(140)},items[1]],assignments);verifyContents(changed,items);
assert(links.get(changed).find(link=>link.options.pageNumber>2),'Longer content must update later page destinations');
assert.throws(()=>buildAgencyRulesPdf(agency,[],[assignments[0]]),/unavailable/);
if(process.env.REGISTRY_QA_PDF_DIR){fs.mkdirSync(process.env.REGISTRY_QA_PDF_DIR,{recursive:true});for(const [name,pdf] of Object.entries({compact,long,none,overview,'overview-long':lengthy,cover:cinematic,formatting,wide,'many-items':many,'changed-content':changed}))fs.writeFileSync(path.join(process.env.REGISTRY_QA_PDF_DIR,name+'.pdf'),Buffer.from(pdf.output('arraybuffer')));}
console.log('PDF checks passed: automatic contents, exact page links/cover offsets, updated destinations, many items, wrapped names, compact/empty reports, isolation, complete long content, continuations, overview, cover/logo, embedded font, bold/list labels, unchanged source and page bounds.');
