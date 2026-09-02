import './globals.css';
import CurrentChrome from './components/current-chrome';

export const metadata={title:'Backtrace Training Administration',description:'Administrative training management'};

export default function RootLayout({children}:{children:React.ReactNode}){
  return <html lang="en"><body><CurrentChrome>{children}</CurrentChrome></body></html>;
}