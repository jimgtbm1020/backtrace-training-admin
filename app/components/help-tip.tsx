'use client';

import {useId,useState} from 'react';

export default function HelpTip({text}:{text:string}){
  const id=useId();
  const [open,setOpen]=useState(false);

  return <span
    className="help-tip"
    data-open={open?'true':'false'}
    onBlur={event=>{
      if(!event.currentTarget.contains(event.relatedTarget as Node|null))setOpen(false);
    }}
    onKeyDown={event=>{
      if(event.key==='Escape'){
        setOpen(false);
        event.currentTarget.querySelector<HTMLButtonElement>('.help-tip__trigger')?.focus();
      }
    }}
  >
    <button
      type="button"
      className="help-tip__trigger"
      aria-label="Show help"
      aria-expanded={open}
      aria-describedby={id}
      onClick={()=>setOpen(value=>!value)}
    >?</button>
    <span id={id} className="help-tip__bubble" role="tooltip">{text}</span>
  </span>;
}
