import {Agency} from './types';
export type ImportRow={agency_name:string};
export const agencyKey=(name:string)=>name.trim().replace(/\s+/g,' ').toLowerCase();
export function parseAgencyCsv(text:string):ImportRow[]{
 const rows:string[][]=[];let row:string[]=[],cell='',quoted=false,closed=false;
 text=text.replace(/^\uFEFF/,'');
 for(let i=0;i<text.length;i++){
  const c=text[i];
  if(quoted){if(c==='"'){if(text[i+1]==='"'){cell+='"';i++;}else{quoted=false;closed=true;}}else cell+=c;continue;}
  if(c==='"'){if(cell||closed)throw new Error('Invalid CSV quoting.');quoted=true;continue;}
  if(c===','||c==='\n'||c==='\r'){row.push(cell.trim());cell='';closed=false;if(c!==','){if(c==='\r'&&text[i+1]==='\n')i++;if(row.some(Boolean))rows.push(row);row=[];}continue;}
  if(closed&&c.trim())throw new Error('Invalid text after a quoted CSV field.');cell+=c;
 }
 if(quoted)throw new Error('A quoted CSV field is not closed.');
 row.push(cell.trim());if(row.some(Boolean))rows.push(row);
 if(rows.length<2)throw new Error('The CSV needs a header and at least one agency.');
 const expected=['Agency Name','Street Address','City','State','ZIP'];
 const headers=rows.shift()!.map(x=>x.toLowerCase());
 const nameOnly=headers.length===1&&headers[0]==='agency name';
 const legacy=headers.length===5&&expected.every(h=>headers.includes(h.toLowerCase()));
 if(!nameOnly&&!legacy)throw new Error('Use a CSV with one column: Agency Name.');
 if(rows.length>500)throw new Error('Import up to 500 agencies at a time.');
 return rows.map((r,i)=>{
  if(r.length!==headers.length)throw new Error(`Row ${i+2}: expected ${headers.length} field${headers.length===1?'':'s'}.`);
  const name=r[headers.indexOf('agency name')].replace(/\s+/g,' ');
  if(!name)throw new Error(`Row ${i+2}: Agency Name is required.`);
  if(name.length>160)throw new Error(`Row ${i+2}: Agency Name exceeds 160 characters.`);
  return {agency_name:name};
 });
}
export function previewAgencies(rows:ImportRow[],agencies:Agency[]){
 const seen=new Set(agencies.map(a=>agencyKey(a.agency_name)));
 return rows.map(row=>{const key=agencyKey(row.agency_name);const duplicate=seen.has(key);seen.add(key);return {...row,duplicate};});
}
