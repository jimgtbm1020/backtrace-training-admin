'use client';

import {useEffect,useId,useRef,useState} from 'react';
import styles from './rules.module.css';

type Props = {
  name:string;
  itemType:string;
  description:string;
  expectedOutcome:string;
  disabled:boolean;
  getAccessToken:()=>Promise<string|null>;
  onUse:(description:string)=>void;
};

export default function DescriptionGenerator({name,itemType,description,expectedOutcome,disabled,getAccessToken,onUse}:Props) {
  const id = useId();
  const [open,setOpen] = useState(false);
  const [notes,setNotes] = useState('');
  const [draft,setDraft] = useState<string|null>(null);
  const [error,setError] = useState('');
  const [generating,setGenerating] = useState(false);
  const controller = useRef<AbortController|null>(null);
  const requestId = useRef(0);
  const draftField = useRef<HTMLTextAreaElement>(null);

  useEffect(() => {
    controller.current?.abort();
    controller.current = null;
    requestId.current += 1;
    setGenerating(false);
    setDraft(null);
    setError('');
    return () => {controller.current?.abort(); controller.current = null; requestId.current += 1;};
  }, [name,itemType,description,expectedOutcome,notes,disabled]);

  function cancel() {
    requestId.current += 1;
    controller.current?.abort();
    controller.current = null;
    setGenerating(false);
  }

  async function generate() {
    if (disabled || generating || controller.current) return;
    setError('');
    if (!name.trim()) {setError('Enter an item name first.'); return;}
    if (![notes,description,expectedOutcome].some(value => value.trim())) {
      setError('Add a few facts about what this item does, or enter an existing description or expected outcome.');
      return;
    }
    const abort = new AbortController();
    controller.current = abort;
    const generationId = ++requestId.current;
    setGenerating(true);
    setDraft(null);
    try {
      const token = await getAccessToken();
      if (generationId !== requestId.current || abort.signal.aborted) return;
      if (!token) throw new Error('Your session expired. Please sign in again.');
      const response = await fetch('/api/business-rules/description', {
        method:'POST',
        headers:{'Content-Type':'application/json', Authorization:'Bearer ' + token},
        signal:AbortSignal.any([abort.signal, AbortSignal.timeout(55000)]),
        body:JSON.stringify({name,item_type:itemType,description,expected_outcome:expectedOutcome,notes})
      });
      const result = await response.json().catch(() => ({}));
      if (generationId !== requestId.current || abort.signal.aborted) return;
      if (!response.ok) throw new Error(result.message || 'Unable to generate a description. Please try again.');
      if (typeof result.description !== 'string' || !result.description.trim() || result.description.length > 4000) {
        throw new Error('The service returned an invalid draft. Please try again.');
      }
      setDraft(result.description);
    } catch (e) {
      if (generationId === requestId.current && !abort.signal.aborted) {
        setError(e instanceof Error && e.name === 'TimeoutError'
          ? 'Description generation took too long. Please try again.'
          : e instanceof Error ? e.message : 'Unable to generate a description.');
      }
    } finally {
      if (controller.current === abort) controller.current = null;
      if (generationId === requestId.current) setGenerating(false);
    }
  }

  useEffect(() => {
    if (draft && !generating) draftField.current?.focus();
  }, [generating]); // Focus once when generation finishes, not after every draft edit.

  return <div className={styles.descriptionAssistant}>
    <button type="button" className={styles.generateDescriptionButton} disabled={disabled}
      aria-expanded={open} aria-controls={id} onClick={() => {
        if (open) cancel();
        setOpen(value => !value);
      }}>Generate Description</button>
    {open && <section id={id} className={styles.descriptionGenerator} aria-label="Description generator" aria-busy={generating}>
      <p>Generate an AI draft from the item name, type, and details you provide.</p>
      <label>Key features / notes
        <textarea maxLength={2000} rows={3} value={notes} disabled={disabled}
          onChange={event => {cancel();setNotes(event.target.value);}}
          placeholder="For example: searches arrest records, shows arrest history, exports results to Excel."/>
      </label>
      <small>Notes can be brief. An existing description or expected outcome can also provide context.</small>
      <div className={styles.actions}>
        <button type="button" className={styles.primary} disabled={disabled || generating} onClick={() => void generate()}>
          {generating ? 'Generating…' : draft !== null ? 'Generate Again' : 'Generate Draft'}
        </button>
        {generating && <button type="button" onClick={cancel}>Cancel generation</button>}
      </div>
      {generating && <p role="status" aria-live="polite">Creating your description…</p>}
      {error && <p className={styles.error} role="alert">{error}</p>}
      {draft !== null && <div className={styles.descriptionDraft}>
        <label>Suggested description
          <textarea ref={draftField} rows={4} maxLength={4000} value={draft} disabled={disabled}
            onChange={event => setDraft(event.target.value)}/>
        </label>
        <p>Review and edit the draft, then choose Use Description. Save the item to keep your changes.</p>
        <div className={styles.actions}>
          <button type="button" className={styles.primary} disabled={disabled || !draft.trim()} onClick={() => {
            onUse(draft.trim());setDraft(null);setOpen(false);
          }}>Use Description</button>
          <button type="button" disabled={disabled} onClick={() => setDraft(null)}>Discard Draft</button>
        </div>
      </div>}
    </section>}
  </div>;
}
