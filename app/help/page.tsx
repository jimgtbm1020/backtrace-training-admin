'use client';

const topics=[['Dashboard','Use the dashboard links to open each administration module.'],['Training Requests','Review, search, filter, export, and edit basic details for open requests.'],['Classes and Attendance','Review sessions, registration state, check-in windows, and export the overview.'],['Completions and Certificates','Review finalized records and export filtered results.'],['System Health','Run read-only connectivity checks for the core administration tables.'],['Protected actions','Attendance history, certificates, email delivery, release controls, webhooks, and tracking remain protected or disabled.']];

export default function HelpPage(){return <main className="shell"><header className="header"><div><div className="brand">Application Help</div><div className="subtitle">Backtrace Training Administration guide</div></div><a href="/">Back to dashboard</a></header><section className="card"><h2>Using the application</h2>{topics.map(([title,description])=><article key={title}><h3>{title}</h3><p>{description}</p></article>)}</section></main>;
}
