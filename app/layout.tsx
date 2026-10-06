import './globals.css';
import Script from 'next/script';
import CurrentChrome from './components/current-chrome';

export const metadata={title:'Backtrace Training Administration',description:'Administrative training management'};

export default function RootLayout({children}:{children:React.ReactNode}){
  return <html lang="en"><body><Script id="supabase-transport" strategy="beforeInteractive">{"(() => {\n  const databaseOrigin = \"https://wfkvcpclzhxdvknybvyb.supabase.co\";\n  const originalFetch = window.fetch.bind(window);\n  window.fetch = (input, init) => {\n    const url = new URL(typeof input === 'string' ? input : input instanceof URL ? input.href : input.url, window.location.href);\n    if (url.origin !== databaseOrigin || !/^\\/(rest|auth|functions|storage)\\/v1\\//.test(url.pathname)) return originalFetch(input, init);\n    const target = new URL('/api/supabase' + url.pathname + url.search, window.location.origin);\n    return originalFetch(input instanceof Request ? new Request(target, input) : target, init);\n  };\n})();"}</Script><CurrentChrome>{children}</CurrentChrome></body></html>;
}