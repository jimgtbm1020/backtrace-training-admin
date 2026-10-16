import {useRef,useState} from 'react';
import {Agency} from './types';
import {defaultOverviewHeading,hasOverview,overviewBlocks,overviewSpans} from './overview-text';
import styles from './rules.module.css';
type Overview={overview_heading:string;overview_introduction:string;overview_features:string};
function Formatted({text}:{text:string}){return <>{overviewBlocks(text).map((block,i)=>{const content=overviewSpans(block.text).map((span,j)=>span.bold?<strong key={j}>{span.text}</strong>:<span key={j}>{span.text}</span>);return block.bullet?<ul key={i}><li>{content}</li></ul>:<p key={i} style={{whiteSpace:'pre-wrap'}}>{content}</p>;})}</>;}
export default function AgencyOverview({agency}:{agency:Pick<Agency,'overview_heading'|'overview_introduction'|'overview_features'>}){
 if(!hasOverview(agency))return null;
 return <section className={styles.overview}><h3>{agency.overview_heading||defaultOverviewHeading}</h3><Formatted text={agency.overview_introduction||''}/><Formatted text={agency.overview_features||''}/></section>;
}
export function OverviewEditor({value,onChange,agencies}:{value:Overview;onChange:(value:Overview)=>void;agencies:Agency[]}){
 const features=useRef<HTMLTextAreaElement>(null);const [source,setSource]=useState('');
 function format(bullet:boolean){const field=features.current;if(!field)return;const start=field.selectionStart,end=field.selectionEnd,selected=value.overview_features.slice(start,end);const insertion=bullet?(start&&value.overview_features[start-1]!=='\n'?'\n':'')+(selected||'Feature').split('\n').map(line=>'- '+line).join('\n'):'**'+(selected||'Bold text')+'**';const next=value.overview_features.slice(0,start)+insertion+value.overview_features.slice(end);if(next.length>12000)return;onChange({...value,overview_features:next});requestAnimationFrame(()=>{field.focus();field.setSelectionRange(start,start+insertion.length);});}
 return <div className={styles.full}><h3>Agency overview</h3><p>Optional. Appears above the tools and at the beginning of the PDF report.</p>
 <div className={styles.actions}><label>Copy from another agency<select value={source} onChange={e=>setSource(e.target.value)}><option value="">Choose agency</option>{agencies.filter(hasOverview).map(a=><option key={a.id} value={a.id}>{a.agency_name}</option>)}</select></label><button type="button" disabled={!source} onClick={()=>{const a=agencies.find(a=>a.id===source);if(a)onChange({overview_heading:a.overview_heading||defaultOverviewHeading,overview_introduction:a.overview_introduction||'',overview_features:a.overview_features||''});}}>Copy into draft</button></div><p>Copying replaces the overview in this draft. Review the wording, then save the agency.</p>
 <label>Overview heading<input className={styles.shortInput} maxLength={160} value={value.overview_heading} onChange={e=>onChange({...value,overview_heading:e.target.value})}/></label>
 <label>Introduction<textarea rows={4} maxLength={6000} value={value.overview_introduction} onChange={e=>onChange({...value,overview_introduction:e.target.value})}/></label>
 <label htmlFor="agency-overview-features">Key features</label><div className={styles.actions}><button type="button" onClick={()=>format(false)}>Bold</button><button type="button" onClick={()=>format(true)}>Bullet list</button></div>
 <textarea id="agency-overview-features" ref={features} rows={8} maxLength={12000} value={value.overview_features} onChange={e=>onChange({...value,overview_features:e.target.value})}/><p>Select text and use the buttons to format it. Separate paragraphs with a blank line.</p>
 {hasOverview(value)&&<><h4>Preview</h4><AgencyOverview agency={value}/></>}</div>;
}
