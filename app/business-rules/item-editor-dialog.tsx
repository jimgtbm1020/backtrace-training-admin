'use client';

import {ReactNode,useEffect,useRef,useState} from 'react';
import styles from './rules.module.css';

type Props={open:boolean;title:string;subtitle:string;dirty:boolean;busy:boolean;editing:boolean;error:string;onClose:()=>void;children:ReactNode};

export default function ItemEditorDialog({open,title,subtitle,dirty,busy,editing,error,onClose,children}:Props){
 const ref=useRef<HTMLDialogElement>(null);
 const bodyRef=useRef<HTMLDivElement>(null);
 const [confirmDiscard,setConfirmDiscard]=useState(false);
 const confirmationRef=useRef<HTMLDivElement>(null);
 useEffect(()=>{
  if(!open||!ref.current)return;
  const dialog=ref.current;
  const origin=document.activeElement instanceof HTMLElement?document.activeElement:null;
  const overflow=document.body.style.overflow;
  document.body.style.overflow='hidden';
  setConfirmDiscard(false);
  dialog.showModal();
  if(bodyRef.current)bodyRef.current.scrollTop=0;
  dialog.querySelector<HTMLInputElement>('input')?.focus({preventScroll:true});
  return()=>{
   dialog.close();
   document.body.style.overflow=overflow;
   const target=origin?.isConnected?origin:document.getElementById('catalog-new-item');
   target?.focus({preventScroll:true});
  };
 },[open]);
 useEffect(()=>{if(confirmDiscard)confirmationRef.current?.querySelector<HTMLButtonElement>('button')?.focus();},[confirmDiscard]);
 function close(){if(busy)return;if(dirty)setConfirmDiscard(true);else onClose();}
 return <dialog ref={ref} className={styles.itemEditorDialog} aria-labelledby="item-editor-title" aria-describedby="item-editor-subtitle" onCancel={event=>{event.preventDefault();close();}}>
  <div className={styles.itemEditorShell}>
   <header className={styles.itemEditorHeader}>
    <div><span className={styles.editorEyebrow}>ITEM CATALOG</span><h2 id="item-editor-title">{title}</h2><p id="item-editor-subtitle">{subtitle}</p></div>
    <button type="button" aria-label="Close item editor" disabled={busy} onClick={close}>Close</button>
   </header>
   <div ref={bodyRef} className={styles.itemEditorBody}>{open&&children}</div>
   <footer className={styles.itemEditorFooter}>
    {error&&<p className={styles.editorError} role="alert">{error}</p>}
    {confirmDiscard?<div ref={confirmationRef} className={styles.discardPrompt} role="alert" aria-label="Unsaved changes"><p>Discard your unsaved changes?</p><div className={styles.actions}><button type="button" className={styles.primary} onClick={()=>setConfirmDiscard(false)}>Keep editing</button><button type="button" onClick={onClose}>Discard changes</button></div></div>
     :<><span className={styles.editorSaveHint}>{busy?'Saving your item…':dirty?'Unsaved changes':'Changes appear in the catalog after saving.'}</span><div className={styles.actions}><button type="button" disabled={busy} onClick={close}>Cancel</button><button form="catalog-item-form" type="submit" className={styles.primary} disabled={busy}>{busy?'Saving…':editing?'Save changes':'Create item'}</button></div></>}
   </footer>
  </div>
 </dialog>;
}
