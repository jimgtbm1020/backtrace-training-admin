'use client';

export default function GlobalError({reset}:{error:Error&{digest?:string};reset:()=>void}){return <html lang="en"><body><main className="shell"><section className="card"><h1>Administration unavailable</h1><p>The application encountered an unexpected error.</p><button onClick={()=>reset()}>Try again</button><a href="/">Return to dashboard</a></section></main></body></html>;
}
