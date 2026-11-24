export type ReportSpan={text:string;bold:boolean};
export type ReportBlock={text:string;marker:string;heading:boolean};

export const cleanReportText=(text:string)=>text.replace(/[\u2018\u2019]/g,"'").replace(/[\u201c\u201d]/g,'"').replace(/[\u2013\u2014\u2011]/g,'-');

export function reportBlocks(value:string):ReportBlock[]{
 const blocks:ReportBlock[]=[];
 let current:ReportBlock|null=null;
 for(const line of value.replace(/\r\n?/g,'\n').split('\n')){
  if(!line.trim()){current=null;continue;}
  const bullet=line.match(/^\s*(?:([-*•])\s+|(\d+[.)])\s+)(.+)$/);
  const heading=line.match(/^#{1,6}\s+(.+)$/);
  if(bullet||heading||!current){
   current={text:bullet?bullet[3]:heading?heading[1]:line.trim(),marker:bullet?(bullet[2]||'•'):'',heading:!!heading};
   blocks.push(current);
  }else current.text+=' '+line.trim();
 }
 return blocks;
}

export function reportSpans(text:string,highlightLabel=false):ReportSpan[]{
 const label=highlightLabel?text.match(/^([^:\n]{1,75}:)(\s+[\s\S]+)$/):null;
 const split=(value:string)=>value.split(/(\*\*[^*\n]+\*\*|__[^_\n]+__)/g).filter(Boolean).map(part=>{
  const bold=/^(?:\*\*[^*\n]+\*\*|__[^_\n]+__)$/.test(part);
  return {bold,text:cleanReportText(bold?part.slice(2,-2):part)};
 });
 return label?[...split(label[1]).map(span=>({...span,bold:true})),...split(label[2])]:split(text);
}
