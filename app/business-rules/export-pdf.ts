import {jsPDF} from 'jspdf';
import {reportFontRegular,reportFontBold} from './report-fonts';
import {defaultOverviewHeading,hasOverview} from './overview-text';
import {Agency,Item,Assignment,agencyAddress,formatRetention} from './types';
import {groupAgencyAssignments,itemTypeColor} from './item-groups';
import {cleanReportText,reportBlocks,reportSpans,ReportSpan} from './report-text';

type Color=[number,number,number];
type RichLine=ReportSpan[];
const ink:Color=[24,46,71],muted:Color=[77,96,117],gold:Color=[181,140,49],navy:Color=[21,48,78];
const blueTint:Color=[239,245,251],goldTint:Color=[250,247,235],lineColor:Color=[210,221,232];

export function buildAgencyRulesPdf(agency:Agency,items:Item[],assignments:Assignment[],logoData?:string,coverData?:string){
 const groups=groupAgencyAssignments(agency.id,items,assignments);
 if(groups.some(group=>group.rows.some(row=>!row.item)))throw new Error('An assigned item is unavailable. Refresh before exporting.');
 const doc=new jsPDF({unit:'pt',format:'letter'});
 doc.addFileToVFS('OpenSans-Regular.ttf',reportFontRegular);doc.addFont('OpenSans-Regular.ttf','ReportSans','normal');
 doc.addFileToVFS('OpenSans-Bold.ttf',reportFontBold);doc.addFont('OpenSans-Bold.ttf','ReportSans','bold');
 doc.setProperties({title:'Agency Business Rules - '+agency.agency_name,subject:'Agency item descriptions, data sources, retention and expected outcomes',creator:'Backtrace Training Administration'});
 const margin=40,width=532,bottom=738,bodySize=10.5,leading=14.5;
 type Destination={page:number;y:number};
 const contentsRows:{key:string;page:number;y:number;height:number;group:boolean}[]=[];
 const destinations=new Map<string,Destination>();
 let y=52,activeGroup:{type:string;count:number}|null=null,activeItem:Item|null=null,overviewTitle='';
 const clean=(value:string)=>cleanReportText(value||'Not specified');
 function font(size:number,bold=false,color:Color=ink){doc.setFont('ReportSans',bold?'bold':'normal');doc.setFontSize(size);doc.setTextColor(...color);doc.setCharSpace(0);}
 function wrap(value:string,w:number,size=bodySize,bold=false):string[]{font(size,bold);return doc.splitTextToSize(clean(value),w);}
 function bandHeight(type:string){return Math.max(36,wrap(type,width-120,14,true).length*17+16);}
 function groupBand(continued=false){
  if(!activeGroup)return;
  const label=activeGroup.type+(continued?' (continued)':'');
  const lines=wrap(label,width-120,14,true),height=Math.max(36,lines.length*17+16);
  doc.setFillColor(...itemTypeColor(activeGroup.type));doc.roundedRect(margin,y,width,height,5,5,'F');
  font(14,true,[255,255,255]);doc.text(lines,margin+14,y+23,{lineHeightFactor:17/14});
  font(10,true,[255,255,255]);doc.text(activeGroup.count+' '+(activeGroup.count===1?'item':'items'),margin+width-14,y+23,{align:'right'});y+=height+10;
 }
 function itemHeader(continued=false){
  if(!activeItem)return;
  const title=wrap(activeItem.name+(continued?' (continued)':''),width-115,14,true),height=Math.max(36,title.length*17+17);
  doc.setFillColor(...navy);doc.roundedRect(margin,y,width,height,5,5,'F');
  doc.setFillColor(...gold);doc.rect(margin,y+height-3,width,3,'F');
  font(14,true,[255,255,255]);doc.text(title,margin+14,y+24,{lineHeightFactor:17/14});
  const type=wrap(activeItem.item_type,80,9,true);font(9,true,[230,235,244]);doc.text(type,margin+width-14,y+23,{align:'right',lineHeightFactor:1.2});y+=height+8;
 }
 function nextPage(continued=false){
  doc.addPage();font(8.5,true,muted);doc.text('BACKTRACE  /  AGENCY BUSINESS RULES',margin,28);
  doc.setDrawColor(...lineColor);doc.setLineWidth(.6);doc.line(margin,36,margin+width,36);y=50;
  groupBand(true);
  if(continued&&activeItem)itemHeader(true);
  else if(continued&&overviewTitle){font(12,true);const lines=wrap(overviewTitle+' (continued)',width,12,true);doc.text(lines,margin,y+15);y+=lines.length*15+16;}
 }
 function richLines(spans:ReportSpan[],available:number):RichLine[]{
  const lines:RichLine[]=[];let line:RichLine=[],used=0;
  const flush=()=>{while(line.length&&/^\s*$/.test(line[line.length-1].text))line.pop();if(line.length){line[line.length-1].text=line[line.length-1].text.trimEnd();lines.push(line);}line=[];used=0;};
  const add=(text:string,bold:boolean)=>{font(bodySize,bold);const w=doc.getTextWidth(text);const last=line[line.length-1];if(last?.bold===bold)last.text+=text;else line.push({text,bold});used+=w;};
  for(const span of spans)for(const token of span.text.match(/\s+|\S+/g)||[]){
   if(/^\s+$/.test(token)){if(used>0)add(' ',span.bold);continue;}
   font(bodySize,span.bold);const tokenWidth=doc.getTextWidth(token);
   if(used>0&&used+tokenWidth>available)flush();
   if(tokenWidth<=available)add(token,span.bold);
   else for(const char of token){font(bodySize,span.bold);if(used+doc.getTextWidth(char)>available)flush();add(char,span.bold);}
  }
  flush();return lines.length?lines:[[{text:'Not specified',bold:false}]];
 }
 function drawLines(lines:RichLine[],x:number,baseline:number,color:Color=ink){
  lines.forEach((runs,index)=>{let left=x;for(const run of runs){font(bodySize,run.bold,color);doc.text(run.text,left,baseline+index*leading);left+=doc.getTextWidth(run.text);}});
 }
 function sectionLabel(label:string,continued=false,tint:Color=[255,255,255]){
  doc.setFillColor(...tint);doc.rect(margin,y,width,22,'F');doc.setFillColor(...gold);doc.rect(margin+13,y+5,3,12,'F');
  font(10,true);doc.text(label+(continued?' (continued)':''),margin+24,y+15);y+=22;
 }
 function content(label:string,value:string,tinted=false){
  const tint=tinted?goldTint:[255,255,255] as Color;
  const blocks=reportBlocks(value||'Not specified');
  const prepared=blocks.map(block=>({block,lines:richLines(reportSpans(block.text,!!block.marker||(!block.heading&&/^[^:]{1,75}:\s/.test(block.text))),width-32-(block.marker?15:0))}));
  const firstHeight=(prepared[0]?.lines.length||1)*leading+6;
  if(y+22+Math.min(firstHeight,160)+4>bottom)nextPage(true);
  sectionLabel(label,false,tint);
  let contentOnPage=false;
  for(const {block,lines:original} of prepared){
   const lines=[...original];let firstChunk=true;
   const blockHeight=lines.length*leading+6;
   // Keep short bullets/paragraphs intact; split large blocks without losing text.
   if(blockHeight<=160&&y+blockHeight>bottom&&contentOnPage){nextPage(true);sectionLabel(label,true,tint);contentOnPage=false;}
   while(lines.length){
    let capacity=Math.floor((bottom-y-9)/leading);
    if(capacity<1){nextPage(true);sectionLabel(label,true,tint);capacity=Math.floor((bottom-y-9)/leading);contentOnPage=false;}
    // Avoid leaving a single final line on the next page when space permits.
    if(lines.length===capacity+1&&capacity>2)capacity--;
    const chunk=lines.splice(0,capacity),height=chunk.length*leading+6;
    doc.setFillColor(...tint);doc.rect(margin,y,width,height,'F');
    if(block.marker&&firstChunk){font(10,true,gold);doc.text(block.marker,margin+16,y+11);}
    const drawn=block.heading?chunk.map(line=>line.map(span=>({...span,bold:true}))):chunk;
    drawLines(drawn,margin+16+(block.marker?15:0),y+11);y+=height;contentOnPage=true;firstChunk=false;
   }
  }
  y+=4;
 }
 function metadata(source:string|null,retention:string){
  const left=wrap(source||'Not specified',332,11,true),right=wrap(retention,136,11,true);let continued=false;
  while(left.length||right.length){
   let capacity=Math.floor((bottom-y-26)/15);
   if(capacity<1){nextPage(true);capacity=Math.floor((bottom-y-26)/15);}
   const a=left.splice(0,capacity),b=right.splice(0,capacity),height=26+Math.max(a.length,b.length)*15;
   doc.setFillColor(...blueTint);doc.roundedRect(margin,y,360,height,4,4,'F');
   doc.setFillColor(...goldTint);doc.roundedRect(margin+368,y,width-368,height,4,4,'F');
   font(8.5,true,muted);doc.text('DATA SOURCE'+(continued?' (CONTINUED)':''),margin+13,y+13);doc.text('RETENTION',margin+381,y+13);
   font(11,true);if(a.length)doc.text(a,margin+13,y+27,{lineHeightFactor:15/11});if(b.length)doc.text(b,margin+381,y+27,{lineHeightFactor:15/11});y+=height+8;continued=true;
  }
 }
 if(coverData){
  const image=doc.getImageProperties(coverData),scale=Math.max(612/image.width,792/image.height),w=image.width*scale,h=image.height*scale;
  doc.addImage(coverData,image.fileType,(612-w)/2,(792-h)/2,w,h);
  doc.setFillColor(10,28,49);doc.rect(30,575,552,187,'F');doc.setDrawColor(...gold);doc.setLineWidth(2);doc.line(54,594,558,594);
  font(25,true,[255,255,255]);doc.text('Agency Business Rules',54,629);
  font(16,true,[255,255,255]);const agencyLines=doc.splitTextToSize(clean(agency.agency_name),504);doc.text(agencyLines,54,660);
  font(10,false,[218,227,239]);doc.text('BACKTRACE TRAINING ADMINISTRATION',54,721);doc.text('Date printed: '+new Date().toLocaleDateString('en-US',{year:'numeric',month:'long',day:'numeric',timeZone:'America/New_York'}),54,741);
  doc.addPage();
 }
 // Lay out the contents first, then fill in destinations after the report has paginated.
 // This keeps printed page numbers and PDF links accurate for any description length.
 if(groups.length){
  function contentsPage(continued=false){
   if(continued)doc.addPage();
   font(8.5,true,muted);doc.text('BACKTRACE  /  AGENCY BUSINESS RULES',margin,30);
   font(24,true);doc.text('Table of contents'+(continued?' (continued)':''),margin,60);
   const names=wrap(agency.agency_name,width,12,true);font(12,true);doc.text(names,margin,82,{lineHeightFactor:1.25});
   y=76+names.length*15;
   font(10,false,muted);doc.text('Select a section or item to jump to its page.',margin,y+12);
   font(8.5,true,muted);doc.text('PAGE',margin+width-14,y+12,{align:'right'});
   doc.setDrawColor(...gold);doc.setLineWidth(2);doc.line(margin,y+23,margin+width,y+23);y+=35;
  }
  function contentsRow(key:string,label:string,group=false,color:Color=navy){
   const lines=wrap(label,width-88,group?11:10.5,group),height=Math.max(group?30:22,lines.length*14.5+6);
   doc.setFillColor(...(group?color:blueTint));doc.roundedRect(margin,y,width,height,group?4:0,group?4:0,'F');
   font(group?11:10.5,group,group?[255,255,255]:ink);doc.text(lines,margin+14,y+17,{lineHeightFactor:14.5/(group?11:10.5)});
   contentsRows.push({key,page:doc.getNumberOfPages(),y,height,group});y+=height+1;
  }
  contentsPage();
  contentsRow('overview',hasOverview(agency)?'Agency overview':'Agency summary');y+=6;
  for(const group of groups){
   const heading=group.type+' ('+group.rows.length+' '+(group.rows.length===1?'item':'items')+')';
   const headingHeight=Math.max(30,wrap(heading,width-88,11,true).length*14.5+6)+1;
   const firstHeight=Math.max(22,wrap(group.rows[0].item!.name,width-88).length*14.5+6)+1;
   if(y+headingHeight+firstHeight>bottom)contentsPage(true);
   contentsRow('group:'+group.type,heading,true,itemTypeColor(group.type));
   for(const {item} of group.rows){
    const height=Math.max(22,wrap(item!.name,width-88).length*14.5+6)+1;
    if(y+height>bottom){contentsPage(true);contentsRow('group:'+group.type,group.type+' (continued)',true,itemTypeColor(group.type));}
    contentsRow('item:'+item!.id,item!.name);
   }
   y+=3;
  }
  doc.addPage();
 }
 destinations.set('overview',{page:doc.getNumberOfPages(),y:40});
 font(8.5,true,muted);doc.text('BACKTRACE TRAINING ADMINISTRATION',margin,30);
 font(24,true);doc.text('Agency Business Rules',margin,66);
 const names=wrap(agency.agency_name,logoData?width-88:width,16,true);font(16,true);doc.text(names,margin,93,{lineHeightFactor:1.25});y=99+names.length*20;
 const address=agencyAddress(agency);if(address){const lines=wrap(address,width,10);font(10,false,muted);doc.text(lines,margin,y);y+=lines.length*14;}
 if(logoData){const props=doc.getImageProperties(logoData),scale=Math.min(62/props.width,62/props.height);doc.addImage(logoData,props.fileType,margin+width-62,44,props.width*scale,props.height*scale);}
 doc.setDrawColor(...gold);doc.setLineWidth(2);doc.line(margin,y,margin+width,y);y+=14;
 const totals=[{label:'Assigned items',count:groups.reduce((sum,g)=>sum+g.rows.length,0),color:navy},...groups.map(g=>({label:g.type,count:g.rows.length,color:itemTypeColor(g.type)}))];
 const cols=Math.min(4,totals.length),tileWidth=(width-(cols-1)*8)/cols;
 for(let start=0;start<totals.length;start+=cols){
  if(y+62>bottom)nextPage();
  totals.slice(start,start+cols).forEach((entry,i)=>{const x=margin+i*(tileWidth+8);doc.setFillColor(...blueTint);doc.roundedRect(x,y,tileWidth,46,4,4,'F');doc.setFillColor(...entry.color);doc.rect(x,y,3,46,'F');font(20,true,entry.color);doc.text(String(entry.count),x+12,y+22);font(9,true,muted);doc.text(wrap(entry.label,tileWidth-24,9,true),x+12,y+37);});y+=58;
 }
 if(hasOverview(agency)){
  overviewTitle=agency.overview_heading||defaultOverviewHeading;
  content(overviewTitle,[agency.overview_introduction,agency.overview_features].filter(Boolean).join('\n\n'),true);overviewTitle='';y+=6;
 }
 if(hasOverview(agency)&&groups.length)nextPage();
 function briefFields(item:Item){
  const a=reportBlocks(item.description||'Not specified'),b=reportBlocks(item.expected_outcome||'Not specified');
  if(a.length!==1||b.length!==1||a[0].marker||b[0].marker||a[0].heading||b[0].heading)return null;
  const left=richLines(reportSpans(a[0].text),230),right=richLines(reportSpans(b[0].text),230);
  return left.length<=2&&right.length<=2?{left,right,height:34+Math.max(left.length,right.length)*leading}:null;
 }
 function drawBriefFields(fields:NonNullable<ReturnType<typeof briefFields>>){
  if(y+fields.height>bottom)nextPage(true);
  const half=(width-8)/2;doc.setFillColor(...blueTint);doc.roundedRect(margin,y,half,fields.height,4,4,'F');doc.setFillColor(...goldTint);doc.roundedRect(margin+half+8,y,half,fields.height,4,4,'F');
  font(10,true);doc.text('Description',margin+14,y+16);doc.text('Expected outcome',margin+half+22,y+16);
  drawLines(fields.left,margin+16,y+34);drawLines(fields.right,margin+half+24,y+34);y+=fields.height;
 }
 function estimatedItemHeight(item:Item,assignment:Assignment){
  const title=Math.max(36,wrap(item.name,width-115,14,true).length*17+17)+8;
  const meta=26+Math.max(wrap(assignment.data_source||'Not specified',332,11,true).length,wrap(formatRetention(assignment),136,11,true).length)*15+8;
  const body=[item.description,item.expected_outcome].reduce((sum,text)=>sum+26+reportBlocks(text||'Not specified').reduce((n,b)=>n+richLines(reportSpans(b.text,!!b.marker),width-32-(b.marker?15:0)).length*leading+6,0),0);
  const brief=briefFields(item);return title+meta+(brief?brief.height:body)+12;
 }
 function itemStartHeight(item:Item,assignment:Assignment){
  const title=Math.max(36,wrap(item.name,width-115,14,true).length*17+17)+8;
  const meta=26+Math.max(wrap(assignment.data_source||'Not specified',332,11,true).length,wrap(formatRetention(assignment),136,11,true).length)*15+8;
  const first=reportBlocks(item.description||'Not specified')[0];
  const firstHeight=richLines(reportSpans(first.text,!!first.marker),width-32-(first.marker?15:0)).length*leading+6;
  return Math.min(estimatedItemHeight(item,assignment),title+Math.min(meta,100)+22+Math.min(firstHeight,160)+4);
 }
 for(const group of groups){
  activeGroup=null;activeItem=null;
  const first=group.rows[0],firstHeight=estimatedItemHeight(first.item!,first.assignment);
  const required=bandHeight(group.type)+10+(firstHeight<270?firstHeight:itemStartHeight(first.item!,first.assignment));
  if(y+required>bottom)nextPage();
  activeGroup={type:group.type,count:group.rows.length};destinations.set('group:'+group.type,{page:doc.getNumberOfPages(),y});groupBand();
  group.rows.forEach(({item,assignment},index)=>{
   if(!item)return;
   activeItem=null;
   const estimated=estimatedItemHeight(item,assignment);
   const minStart=itemStartHeight(item,assignment);
   if(index>0&&y+Math.min(estimated,estimated<270?estimated:minStart)>bottom)nextPage();
   activeItem=item;destinations.set('item:'+item.id,{page:doc.getNumberOfPages(),y});itemHeader();metadata(assignment.data_source,formatRetention(assignment));const brief=briefFields(item);if(brief)drawBriefFields(brief);else{content('Description',item.description);content('Expected outcome',item.expected_outcome,true);}y+=12;
  });
  activeItem=null;activeGroup=null;y+=8;
 }
 if(!groups.length)content('Assigned tools','No items assigned to this agency.');
 const count=doc.getNumberOfPages(),offset=coverData?1:0;
 for(const entry of contentsRows){const target=destinations.get(entry.key);if(!target)continue;doc.setPage(entry.page);font(10,true,entry.group?[255,255,255]:ink);doc.text(String(target.page-offset),margin+width-14,entry.y+17,{align:'right'});doc.link(margin,entry.y,width,entry.height,{pageNumber:target.page,top:target.y});}
 for(let p=1+offset;p<=count;p++){
  doc.setPage(p);doc.setDrawColor(...lineColor);doc.setLineWidth(.7);doc.line(margin,752,margin+width,752);
  font(8.5,false,muted);const footer=wrap(agency.agency_name,380,8.5)[0];font(8.5,false,muted);doc.text(footer,margin,768);doc.text('Page '+(p-offset)+' of '+(count-offset),margin+width,768,{align:'right'});
 }
 return doc;
}

export async function downloadAgencyRulesPdf(agency:Agency,items:Item[],assignments:Assignment[],logo?:Blob,cover?:Blob){
 const logoData=logo?await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result as string);reader.onerror=()=>reject(new Error('Unable to read agency logo.'));reader.readAsDataURL(logo);}):undefined;
 const coverData=cover?await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result as string);reader.onerror=()=>reject(new Error('Unable to read report cover.'));reader.readAsDataURL(cover);}):undefined;
 const name=agency.agency_name.replace(/[^a-z0-9]+/gi,'-').replace(/^-|-$/g,'')||'Agency';
 buildAgencyRulesPdf(agency,items,assignments,logoData,coverData).save('Agency-Business-Rules-'+name+'.pdf');
}
