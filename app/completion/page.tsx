import {redirect} from 'next/navigation';

type SearchParams=Promise<Record<string,string|string[]|undefined>>;

export default async function LegacyCompletionRoute({searchParams}:{searchParams:SearchParams}){
  const params=await searchParams;
  const raw=params.request;
  const request=Array.isArray(raw)?raw[0]:raw;
  redirect(request?'/completions?request='+encodeURIComponent(request):'/completions');
}
