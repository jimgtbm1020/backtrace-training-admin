import {redirect} from 'next/navigation';

export default async function LegacyBusinessRules({searchParams}:{searchParams:Promise<Record<string,string|string[]|undefined>>}){
 const params=await searchParams;const query=new URLSearchParams();
 for(const [key,value] of Object.entries(params)){if(Array.isArray(value))value.forEach(v=>query.append(key,v));else if(value!==undefined)query.set(key,value);}
 redirect('/business-rules'+(query.size?'?'+query.toString():''));
}
