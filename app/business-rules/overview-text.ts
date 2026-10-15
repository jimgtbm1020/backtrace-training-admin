export const defaultOverviewHeading='Core Features (Quick Overview)';
export const hasOverview=(agency:{overview_introduction?:string;overview_features?:string})=>Boolean(agency.overview_introduction?.trim()||agency.overview_features?.trim());
export function overviewBlocks(text:string){
 return text.replace(/\r/g,'').split(/\n\s*\n/).flatMap(paragraph=>paragraph.split(/\n(?=\s*[-•] )/)).map(text=>({bullet:/^\s*[-•] /.test(text),text:text.replace(/^\s*[-•] /,'').trim()})).filter(block=>block.text);
}
export function overviewSpans(text:string){return text.split(/(\*\*[^*]+\*\*)/g).filter(Boolean).map(text=>({bold:text.startsWith('**')&&text.endsWith('**'),text:text.startsWith('**')&&text.endsWith('**')?text.slice(2,-2):text}));}
