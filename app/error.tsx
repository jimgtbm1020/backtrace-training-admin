'use client';

export default function Error({reset}:{error:Error&{digest?:string};reset:()=>void}){
  return <main className="shell"><section className="card"><h1>Something went wrong</h1><p>The administration page could not be loaded. You can try again or return to the dashboard.</p><button onClick={()=>reset()}>Try again</button><a href="/">Return to dashboard</a></section></main>;
}
