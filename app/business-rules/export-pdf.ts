import {jsPDF} from 'jspdf';
import {defaultOverviewHeading,hasOverview,overviewBlocks,overviewSpans} from './overview-text';
import {Agency,Item,Assignment,agencyAddress} from './types';

export function buildAgencyRulesPdf(agency:Agency,items:Item[],assignments:Assignment[],logoData?:string,coverData?:string){
 const doc=new jsPDF({unit:'pt',format:'letter'});
 const margin=42,width=528,bottom=738;let y=52,toolName='',shade:[number,number,number]=[255,255,255];
 const clean=(value:string)=>value.replace(/[\u2018\u2019]/g,"'").replace(/[\u201c\u201d]/g,'"').replace(/[\u2013\u2014]/g,'-');
 const wrap=(value:string,w=width-28):string[]=>{doc.setFont('helvetica','normal');doc.setFontSize(10);return doc.splitTextToSize(clean(value||'Not specified'),w);};
 function nextPage(continued=false){
  doc.addPage();doc.setFont('helvetica','normal');doc.setFontSize(9);doc.setTextColor(91,107,127);doc.text('BACKTRACE | Agency Business Rules',margin,30);y=52;
  if(continued){doc.setFontSize(10);doc.setTextColor(26,46,73);const name=doc.splitTextToSize(clean(toolName+' (continued)'),width);doc.text(name,margin,y);y+=name.length*14+10;}
 }
 function fill(height:number){doc.setFillColor(...shade);doc.rect(margin,y,width,height,'F');}
 function paragraph(label:string,value:string){
  const lines=wrap(value);let continued=false;
  while(lines.length){
   let capacity=Math.floor((bottom-y-30)/14);
   if(capacity<1){nextPage(true);capacity=Math.floor((bottom-y-30)/14);}
   const chunk=lines.splice(0,capacity),height=26+chunk.length*14;fill(height);
   doc.setFont('helvetica','bold');doc.setFontSize(9);doc.setTextColor(91,107,127);doc.text(label+(continued?' (continued)':''),margin+14,y+13);
   doc.setFont('helvetica','normal');doc.setFontSize(10);doc.setTextColor(26,46,73);doc.text(chunk,margin+14,y+28);y+=height;continued=true;
  }
 }
 function sourceLines(source:string):string[]{doc.setFont('helvetica','bold');doc.setFontSize(11);return doc.splitTextToSize(clean(source||'Not specified'),340);}
 function metadata(source:string,retention:string){
  const left=sourceLines(source),right=wrap(retention,118);let continued=false;
  while(left.length||right.length){
   let capacity=Math.floor((bottom-y-32)/15);
   if(capacity<1){nextPage(true);capacity=Math.floor((bottom-y-32)/15);}
   const sourceChunk=left.splice(0,capacity),retentionChunk=right.splice(0,capacity),height=32+Math.max(sourceChunk.length,retentionChunk.length)*15;
   doc.setFillColor(237,243,250);doc.rect(margin,y,width,height,'F');
   doc.setFillColor(199,163,75);doc.rect(margin,y,3,height,'F');
   doc.setDrawColor(212,223,237);doc.line(margin+370,y+8,margin+370,y+height-8);
   doc.setFont('helvetica','bold');doc.setFontSize(9);doc.setTextColor(32,51,78);doc.text('Data source'+(continued?' (continued)':''),margin+14,y+15);doc.text('Retention',margin+382,y+15);
   doc.setFontSize(11);if(sourceChunk.length)doc.text(sourceChunk,margin+14,y+31,{lineHeightFactor:15/11});
   doc.setFont('helvetica','normal');doc.setFontSize(10);if(retentionChunk.length)doc.text(retentionChunk,margin+382,y+31,{lineHeightFactor:1.5});
   y+=height;continued=true;
  }
 }
 if(coverData){
  const image=doc.getImageProperties(coverData),scale=Math.max(612/image.width,792/image.height),w=image.width*scale,h=image.height*scale;
  doc.addImage(coverData,image.fileType,(612-w)/2,(792-h)/2,w,h);
  doc.setFillColor(10,28,49);doc.rect(30,575,552,187,'F');doc.setDrawColor(199,163,75);doc.setLineWidth(2);doc.line(54,594,558,594);
  doc.setFont('helvetica','bold');doc.setFontSize(25);doc.setTextColor(255,255,255);doc.text('Agency Business Rules',54,629);
  doc.setFontSize(16);const agencyLines=doc.splitTextToSize(clean(agency.agency_name),504);doc.text(agencyLines,54,660);
  doc.setFont('helvetica','normal');doc.setFontSize(10);doc.setTextColor(218,227,239);doc.text('BACKTRACE TRAINING ADMINISTRATION',54,721);doc.text('Date printed: '+new Date().toLocaleDateString('en-US',{year:'numeric',month:'long',day:'numeric',timeZone:'America/New_York'}),54,741);
  doc.addPage();
 }
 if(logoData){const props=doc.getImageProperties(logoData);const scale=Math.min(64/props.width,64/props.height);doc.addImage(logoData,props.fileType,margin+width-64,42,props.width*scale,props.height*scale);}
 doc.setTextColor(91,107,127);doc.setFontSize(9);doc.text('BACKTRACE TRAINING ADMINISTRATION',margin,30);
 doc.setTextColor(26,46,73);doc.setFontSize(22);doc.text('Agency Business Rules',margin,62);
 doc.setFontSize(14);const names=doc.splitTextToSize(clean(agency.agency_name),logoData?width-86:width);doc.text(names,margin,88);y=88+names.length*17;
 doc.setFontSize(10);const address=doc.splitTextToSize(clean(agencyAddress(agency)),logoData?width-86:width);doc.text(address,margin,y);y+=address.length*14+18;
 doc.setDrawColor(210,220,233);doc.line(margin,y-8,margin+width,y-8);
 if(hasOverview(agency)){
  toolName=agency.overview_heading||defaultOverviewHeading;
  doc.setFont('helvetica','bold');doc.setFontSize(15);
  const heading=doc.splitTextToSize(clean(toolName),width-28);doc.setTextColor(26,46,73);doc.text(heading,margin+14,y+18);y+=heading.length*19+14;
  for(const block of [...overviewBlocks(agency.overview_introduction||''),...overviewBlocks(agency.overview_features||'')]){
   let x=margin+14+(block.bullet?12:0);const startX=x,right=margin+width-14;
   if(y+18>bottom)nextPage(true);
   doc.setFontSize(10);doc.setTextColor(26,46,73);
   if(block.bullet){doc.setFont('helvetica','normal');doc.text('-',margin+14,y);}
   for(const span of overviewSpans(block.text)){
    for(const word of clean(span.text).split(/(\s+)/).filter(Boolean)){
     doc.setFont('helvetica',span.bold?'bold':'normal');doc.setFontSize(10);
     if(word.trim()&&doc.getTextWidth(word)<=right-startX&&x+doc.getTextWidth(word)>right){x=startX;y+=14;if(y+14>bottom){nextPage(true);doc.setFont('helvetica',span.bold?'bold':'normal');doc.setFontSize(10);doc.setTextColor(26,46,73);}}
     // Character wrapping also handles long unbroken identifiers without clipping.
     for(const char of word){const w=doc.getTextWidth(char);if(x+w>right){x=startX;y+=14;if(y+14>bottom){nextPage(true);doc.setFont('helvetica',span.bold?'bold':'normal');doc.setFontSize(10);doc.setTextColor(26,46,73);}}if(x===startX&&/\s/.test(char))continue;doc.text(/\s/.test(char)?' ':char,x,y);x+=w;}
    }
   }
   y+=24;
  }
  y+=10;
 }
 const matches=assignments.filter(a=>a.agency_id===agency.id).sort((a,b)=>(items.find(i=>i.id===a.item_id)?.name||'').localeCompare(items.find(i=>i.id===b.item_id)?.name||''));
 matches.forEach((assignment)=>{
  const item=items.find(i=>i.id===assignment.item_id);if(!item)throw new Error('An assigned item is unavailable. Refresh before exporting.');
  toolName=item.name;shade=[255,255,255];
  doc.setFont('helvetica','bold');doc.setFontSize(12);const title=doc.splitTextToSize(clean(item.name),width-130),headerHeight=16+title.length*15;
  const retention=assignment.retention_value+' '+assignment.retention_unit.toLowerCase();
  const metaHeight=32+Math.max(sourceLines(assignment.data_source).length,wrap(retention,118).length)*15;
  const height=headerHeight+metaHeight+52+(wrap(item.description).length+wrap(item.expected_outcome).length)*14;
  if(y+height>bottom&&height<=bottom-52)nextPage();
  if(y+headerHeight+42>bottom)nextPage();
  fill(headerHeight);doc.setTextColor(26,46,73);doc.setFont('helvetica','bold');doc.setFontSize(12);doc.text(title,margin+14,y+19);
  doc.setFont('helvetica','normal');doc.setFontSize(9);doc.setTextColor(91,107,127);doc.text(item.item_type,margin+width-14,y+19,{align:'right'});y+=headerHeight;
  metadata(assignment.data_source,retention);paragraph('Description',item.description);paragraph('Expected outcome',item.expected_outcome);y+=14;
 });
 if(!matches.length)paragraph('Assigned tools','No items assigned to this agency.');
 const count=doc.getNumberOfPages();for(let p=coverData?2:1;p<=count;p++){doc.setPage(p);doc.setFont('helvetica','normal');doc.setFontSize(8);doc.setTextColor(91,107,127);const footer=doc.splitTextToSize(clean(agency.agency_name),400)[0];doc.text(footer,margin,768);doc.text('Page '+(p-(coverData?1:0))+' of '+(count-(coverData?1:0)),570,768,{align:'right'});}
 return doc;
}

export async function downloadAgencyRulesPdf(agency:Agency,items:Item[],assignments:Assignment[],logo?:Blob,cover?:Blob){
 const logoData=logo?await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result as string);reader.onerror=()=>reject(new Error('Unable to read agency logo.'));reader.readAsDataURL(logo);}):undefined;
 const coverData=cover?await new Promise<string>((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result as string);reader.onerror=()=>reject(new Error('Unable to read report cover.'));reader.readAsDataURL(cover);}):undefined;
 const name=agency.agency_name.replace(/[^a-z0-9]+/gi,'-').replace(/^-|-$/g,'')||'Agency';
 buildAgencyRulesPdf(agency,items,assignments,logoData,coverData).save('Agency-Business-Rules-'+name+'.pdf');
}
