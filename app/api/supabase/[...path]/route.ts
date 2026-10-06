import { NextRequest } from 'next/server';
export const dynamic = 'force-dynamic';
export const runtime = 'nodejs';
const requestHeaders = ['authorization','apikey','content-type','accept','prefer','range','range-unit','x-client-info','accept-profile','content-profile','x-upsert','if-match','if-none-match','tus-resumable','upload-length','upload-offset','upload-metadata','x-signature'];
const responseHeaders = ['content-type','content-range','range-unit','preference-applied','etag','last-modified','tus-resumable','upload-offset','upload-length','upload-metadata'];
async function forward(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const { path } = await context.params;
  if (!['rest','auth','functions','storage'].includes(path[0]) || path[1] !== 'v1' || path.some(p => p === '..' || p === '.' || p.includes('/') || p.includes('\\'))) {
    return Response.json({ message: 'Unsupported API path.' }, { status: 404 });
  }
  const base = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!base || !key) return Response.json({ message: 'Database connection is not configured.' }, { status: 503 });
  if (request.headers.get('apikey') !== key) return Response.json({ message: 'Invalid API key.' }, { status: 401 });
  const upstream = new URL(base);
  upstream.pathname = '/' + path.map(encodeURIComponent).join('/');
  upstream.search = request.nextUrl.search;
  const headers = new Headers();
  for (const name of requestHeaders) { const value = request.headers.get(name); if (value !== null) headers.set(name, value); }
  try {
    const result = await fetch(upstream, {
      method: request.method, headers, cache: 'no-store', redirect: 'manual',
      body: ['GET','HEAD'].includes(request.method) ? undefined : await request.arrayBuffer(),
      signal: AbortSignal.timeout(55000)
    });
    const outputHeaders = new Headers({ 'Cache-Control': 'private, no-store', 'Vary': 'Authorization, apikey' });
    for (const name of responseHeaders) { const value = result.headers.get(name); if (value !== null) outputHeaders.set(name, value); }
    return new Response(result.body, { status: result.status, headers: outputHeaders });
  } catch {
    console.error('supabase_transport_unavailable', { service: path[0], method: request.method });
    return Response.json({ message: 'The database connection is temporarily unavailable. Please retry.' }, { status: 502, headers: { 'Cache-Control': 'no-store' } });
  }
}
export const GET = forward;
export const HEAD = forward;
export const POST = forward;
export const PATCH = forward;
export const PUT = forward;
export const DELETE = forward;
