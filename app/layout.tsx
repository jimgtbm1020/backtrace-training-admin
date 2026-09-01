import './globals.css';

export const metadata={title:'Backtrace Training Administration',description:'Administrative training management'};

export default function RootLayout({children}:{children:React.ReactNode}){
  return <html lang="en"><body>{children}</body></html>;
}