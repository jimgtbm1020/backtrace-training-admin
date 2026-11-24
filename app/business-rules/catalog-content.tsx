import {Fragment,ReactNode} from 'react';
import styles from './rules.module.css';

// Render a small, text-only formatting subset. Stored text is never rewritten,
// and HTML, links and scripts are never interpreted as markup.
function inline(text:string):ReactNode {
 const parts=text.split(/(\*\*[^*\n]+\*\*|__[^_\n]+__)/g);
 return parts.map((part,index)=>/^(?:\*\*[^*\n]+\*\*|__[^_\n]+__)$/.test(part)
  ? <strong key={index}>{part.slice(2,-2)}</strong>
  : <Fragment key={index}>{part}</Fragment>);
}

function listText(text:string){
 const label=text.match(/^([^:\n]{1,70}:)(\s+[\s\S]+)$/);
 return label?<><strong className={styles.outcomeLabel}>{inline(label[1])}</strong>{inline(label[2])}</>:inline(text);
}

export default function CatalogContent({text}:{text:string}){
 const lines=text.replace(/\r\n?/g,'\n').split('\n');
 const blocks:ReactNode[]=[];
 const bullet=(line:string)=>line.match(/^\s*(?:[-*•]\s+|(\d+)[.)]\s+)(.+)$/);
 let index=0;
 while(index<lines.length){
  if(!lines[index].trim()){index++;continue;}
  const first=bullet(lines[index]);
  if(first){
   const ordered=!!first[1],start=Number(first[1])||1;
   const entries:{text:string;value?:number}[]=[];
   while(index<lines.length){
    const match=bullet(lines[index]);
    if(!match||!!match[1]!==ordered)break;
    index++;
    let value=match[2];
    // Indented continuation lines belong to the same bullet.
    while(index<lines.length&&/^\s+\S/.test(lines[index])&&!bullet(lines[index]))value+='\n'+lines[index++].trimStart();
    entries.push({text:value,value:ordered?Number(match[1]):undefined});
   }
   const entriesMarkup=entries.map((entry,i)=><li key={i} value={entry.value}>{listText(entry.text)}</li>);
   blocks.push(ordered?<ol key={index} start={start}>{entriesMarkup}</ol>:<ul key={index}>{entriesMarkup}</ul>);
  }else if(/^#{1,6}\s+/.test(lines[index])){
   blocks.push(<p className={styles.contentHeading} key={index}>{inline(lines[index++].replace(/^#{1,6}\s+/,''))}</p>);
  }else{
   const paragraph:string[]=[];
   while(index<lines.length&&lines[index].trim()&&!bullet(lines[index])&&!/^#{1,6}\s+/.test(lines[index]))paragraph.push(lines[index++]);
   blocks.push(<p key={index}>{inline(paragraph.join('\n'))}</p>);
  }
 }
 return <div className={styles.catalogContent}>{blocks}</div>;
}
