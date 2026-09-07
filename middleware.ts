import type {NextRequest} from 'next/server';
import {NextResponse} from 'next/server';

const ADMIN_ORIGIN = 'https://backtrace-training-admin.vercel.app';

const ATTENDANCE_HOSTS = new Set([
  'backtrace-training-attendance.vercel.app',
  'backtrace-training-attendance-jamesbircsak-7301s-projects.vercel.app',
]);

const TRACKER_HOSTS = new Set([
  'backtrace-training-tracker.vercel.app',
]);

function requestHost(request: NextRequest) {
  const forwardedHost = request.headers.get('x-forwarded-host');
  const host = forwardedHost || request.headers.get('host') || request.nextUrl.host;
  return host.split(':')[0].toLowerCase();
}

function redirectToAdmin(request: NextRequest, pathname: string) {
  const target = new URL(ADMIN_ORIGIN);
  target.pathname = pathname;
  target.search = request.nextUrl.search;
  return NextResponse.redirect(target, 308);
}

export function middleware(request: NextRequest) {
  const host = requestHost(request);

  if (ATTENDANCE_HOSTS.has(host)) {
    const pathname =
      request.nextUrl.pathname === '/' || request.nextUrl.pathname === '/attendance'
        ? '/classes'
        : request.nextUrl.pathname;
    return redirectToAdmin(request, pathname);
  }

  if (TRACKER_HOSTS.has(host)) {
    const pathname =
      request.nextUrl.pathname === '/completion'
        ? '/completions'
        : request.nextUrl.pathname;
    return redirectToAdmin(request, pathname);
  }

  return NextResponse.next();
}

export const config = {
  matcher: '/((?!_next/static|_next/image|favicon.ico).*)',
};
