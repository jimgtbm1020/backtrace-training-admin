import {jsPDF} from 'jspdf';
import {Agency,Item,Assignment,agencyAddress} from './types';

export function buildAgencyRulesPdf(agency:Agency,items:Item[],assignments:Assignment[]){
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
 function metadata(source:string,retention:string){
  const left=wrap(source,340),right=wrap(retention,132),height=26+Math.max(left.length,right.length)*14;
  if(height>bottom-y)nextPage(true);
  if(height>bottom-y){paragraph('Data source',source);paragraph('Retention',retention);return;}
  fill(height);doc.setFont('helvetica','bold');doc.setFontSize(9);doc.setTextColor(91,107,127);doc.text('Data source',margin+14,y+13);doc.text('Retention',margin+382,y+13);
  doc.setFont('helvetica','normal');doc.setFontSize(10);doc.setTextColor(26,46,73);doc.text(left,margin+14,y+28);doc.text(right,margin+382,y+28);y+=height;
 }
 doc.setTextColor(91,107,127);doc.setFontSize(9);doc.text('BACKTRACE TRAINING ADMINISTRATION',margin,30);
 doc.setTextColor(26,46,73);doc.setFontSize(22);doc.text('Agency Business Rules',margin,62);
 doc.setFontSize(14);const names=doc.splitTextToSize(clean(agency.agency_name),width);doc.text(names,margin,88);y=88+names.length*17;
 doc.setFontSize(10);const address=doc.splitTextToSize(clean(agencyAddress(agency)),width);doc.text(address,margin,y);y+=address.length*14+18;
 doc.setDrawColor(210,220,233);doc.line(margin,y-8,margin+width,y-8);
 const matches=assignments.filter(a=>a.agency_id===agency.id).sort((a,b)=>(items.find(i=>i.id===a.item_id)?.name||'').localeCompare(items.find(i=>i.id===b.item_id)?.name||''));
 matches.forEach((assignment,index)=>{
  const item=items.find(i=>i.id===assignment.item_id);if(!item)throw new Error('An assigned item is unavailable. Refresh before exporting.');
  toolName=item.name;shade=index%2?[245,248,252]:[255,255,255];
  doc.setFont('helvetica','bold');doc.setFontSize(12);const title=doc.splitTextToSize(clean(item.name),width-130),headerHeight=16+title.length*15;
  const retention=assignment.retention_value+' '+assignment.retention_unit.toLowerCase();
  const metaHeight=26+Math.max(wrap(assignment.data_source,340).length,wrap(retention,132).length)*14;
  const height=headerHeight+metaHeight+52+(wrap(item.description).length+wrap(item.expected_outcome).length)*14;
  if(y+height>bottom&&height<=bottom-52)nextPage();
  if(y+headerHeight+42>bottom)nextPage();
  fill(headerHeight);doc.setTextColor(26,46,73);doc.setFont('helvetica','bold');doc.setFontSize(12);doc.text(title,margin+14,y+19);
  doc.setFont('helvetica','normal');doc.setFontSize(9);doc.setTextColor(91,107,127);doc.text(item.item_type,margin+width-14,y+19,{align:'right'});y+=headerHeight;
  metadata(assignment.data_source,retention);paragraph('Description',item.description);paragraph('Expected outcome',item.expected_outcome);y+=14;
 });
 if(!matches.length)paragraph('Assigned tools','No items assigned to this agency.');
 const count=doc.getNumberOfPages();for(let p=1;p<=count;p++){doc.setPage(p);doc.setFont('helvetica','normal');doc.setFontSize(8);doc.setTextColor(91,107,127);const footer=doc.splitTextToSize(clean(agency.agency_name),400)[0];doc.text(footer,margin,768);doc.text('Page '+p+' of '+count,570,768,{align:'right'});}
 return doc;
}

export function downloadAgencyRulesPdf(agency:Agency,items:Item[],assignments:Assignment[]){
 const name=agency.agency_name.replace(/[^a-z0-9]+/gi,'-').replace(/^-|-$/g,'')||'Agency';
 buildAgencyRulesPdf(agency,items,assignments).save('Agency-Business-Rules-'+name+'.pdf');
}
