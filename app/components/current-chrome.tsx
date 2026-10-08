'use client';

import {useEffect, useRef, useState} from 'react';
import {usePathname} from 'next/navigation';
import {createClient, Session} from '@supabase/supabase-js';
import styles from './current-chrome.module.css';

type Role = 'admin' | 'coordinator' | 'trainer' | 'viewer';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

export default function CurrentChrome({children}: {children: React.ReactNode}) {
  const pathname = usePathname();
  const [menu, setMenu] = useState<string | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [role, setRole] = useState<Role | null>(null);
  const [version, setVersion] = useState('…');
  const [unread, setUnread] = useState(0);
  const [profileUserId,setProfileUserId]=useState<string|null>(null);
  const profileRequest=useRef(0);
  const navigationRef=useRef<HTMLElement|null>(null);
  const [dropdownTop,setDropdownTop]=useState(158);

  useEffect(() => {
    setMenu(null);
    if (session?.user) void loadUnread();
  }, [pathname]);

  useEffect(() => {
    let mounted=true;
    const updateSession=(next:Session|null)=>{
      if(!mounted)return;
      profileRequest.current++;
      setSession(next);setRole(null);setProfileUserId(null);
      if(next?.user){void loadRole(next.user.id);void loadCurrentVersion();void loadUnread();}
      else setUnread(0);
    };
    supabase.auth.getSession().then(({data})=>updateSession(data.session));
    const {data}=supabase.auth.onAuthStateChange((_event,next)=>updateSession(next));
    return()=>{mounted=false;profileRequest.current++;data.subscription.unsubscribe();};
  }, []);

  useEffect(() => {
    if (!session?.user) return;
    const refresh = () => {void loadUnread();void loadRole(session.user.id);};
    const timer = window.setInterval(refresh, 30000);
    window.addEventListener('focus', refresh);
    window.addEventListener('backtrace-notifications-changed', refresh);
    const visible = () => {
      if (document.visibilityState === 'visible') refresh();
    };
    document.addEventListener('visibilitychange', visible);

    return () => {
      window.clearInterval(timer);
      window.removeEventListener('focus', refresh);
      window.removeEventListener('backtrace-notifications-changed', refresh);
      document.removeEventListener('visibilitychange', visible);
    };
  }, [session?.user?.id]);

  function positionDropdown(){if(navigationRef.current)setDropdownTop(Math.max(12,navigationRef.current.getBoundingClientRect().bottom+8));}
  function toggleMenu(name:string){positionDropdown();setMenu(menu===name?null:name);}
  useEffect(()=>{
    if(!menu)return;
    window.addEventListener('resize',positionDropdown);window.addEventListener('scroll',positionDropdown,{passive:true});
    return()=>{window.removeEventListener('resize',positionDropdown);window.removeEventListener('scroll',positionDropdown);};
  },[menu]);

  async function loadCurrentVersion() {
    const {data} = await supabase
      .from('training_app_versions')
      .select('version')
      .eq('is_current', true)
      .maybeSingle();
    if (data?.version) setVersion(data.version);
  }

  async function loadRole(id: string) {
    const request=++profileRequest.current;
    const {data,error} = await supabase.from('profiles').select('role,active').eq('id', id).maybeSingle();
    if(request!==profileRequest.current)return;
    const allowed=!error&&data?.active&&['admin','coordinator','trainer','viewer'].includes(data.role);
    setRole(allowed?data.role as Role:null);setProfileUserId(allowed?id:null);
  }

  async function loadUnread() {
    const {count, error} = await supabase
      .from('training_notifications')
      .select('id', {count: 'exact', head: true})
      .is('read_at', null);
    if (!error) setUnread(count ?? 0);
  }

  async function signOut() {
    await supabase.auth.signOut();
    window.location.assign('/');
  }

  const itemClass = (path: string) =>
    `${styles.item}${pathname.startsWith(path) ? ` ${styles.itemActive}` : ''}`;

  const triggerClass = (active: boolean) =>
    `${styles.trigger}${active ? ` ${styles.triggerActive}` : ''}`;

  const canAccessBusinessRules=!!session?.user&&profileUserId===session.user.id&&['admin','coordinator','trainer','viewer'].includes(role||'');

  if (!session) return <>{children}</>;

  return (
    <>
      <header className={`topbar ${styles.header}`}>
        <div>
          <div className="eyebrow">BACKTRACE</div>
          <div className={`app-title ${styles.titleRow}`}>
            <span>Training Administration</span>
            <div className={styles.titleActions}>
            <a className="version-badge" href="/version-history" aria-label="Open Version History">
              {`v${version}`}
            </a>
            {canAccessBusinessRules&&<a className={styles.businessRules} href="/business-rules" aria-current={pathname.startsWith('/business-rules')?'page':undefined}>Business Rules</a>}
            </div>
          </div>
        </div>
        <div className="user-area">
          <div>
            <strong>{session.user.email?.split('@')[0] || 'Jim'}</strong>
            <small>{role === 'admin' ? 'ADMIN' : role?.toUpperCase() || 'USER'}</small>
          </div>
          <button className="signout" onClick={() => void signOut()}>
            Sign Out
          </button>
        </div>
      </header>

      <nav ref={navigationRef} className="main-nav" aria-label="Main navigation" style={{'--dropdown-top':`${dropdownTop}px`} as React.CSSProperties}>
        <a className={pathname === '/' ? 'active' : ''} href="/">
          Dashboard
        </a>

        <div className={styles.navMenu}>
          <button
            className={triggerClass(
              ['/requests', '/request-training', '/trainer-workspace', '/calendar', '/today', '/classes', '/completions', '/reports'].some(
                (path) => pathname.startsWith(path),
              ),
            )}
            type="button"
            aria-expanded={menu === 'training'}
            onClick={() => toggleMenu('training')}
          >
            Training⌄
          </button>
          {menu === 'training' && (
            <div className={styles.dropdown}>
              <div className={styles.sectionTitle}>Workspace</div>
              <a className={itemClass('/requests')} href="/requests">Training Requests</a>
              <a className={itemClass('/request-training')} href="/request-training">Training Request Form</a>
              <a className={itemClass('/trainer-workspace')} href="/trainer-workspace">Trainer Workspace</a>
              <a className={itemClass('/calendar')} href="/calendar">Calendar</a>
              <a className={itemClass('/today')} href="/today">Today</a>

              <div className={styles.divider} />
              <div className={styles.sectionTitle}>Classes</div>
              <a className={itemClass('/classes')} href="/classes">Classes &amp; Attendance</a>
              <a className={itemClass('/completions')} href="/completions">Completions &amp; Certificates</a>

              {['admin', 'coordinator'].includes(role || '') && (
                <>
                  <div className={styles.divider} />
                  <div className={styles.sectionTitle}>Analytics</div>
                  <a className={itemClass('/reports')} href="/reports">Reports</a>
                </>
              )}
            </div>
          )}
        </div>

        <div className={styles.navMenu}>
          <button
            className={triggerClass(
              ['/attendees', '/agencies', '/agency-history', '/agency-portal'].some((path) => pathname.startsWith(path)),
            )}
            type="button"
            aria-expanded={menu === 'people'}
            onClick={() => toggleMenu('people')}
          >
            People⌄
          </button>
          {menu === 'people' && (
            <div className={styles.dropdown}>
              <div className={styles.sectionTitle}>People &amp; Agencies</div>
              <a className={itemClass('/attendees')} href="/attendees">Attendees</a>
              {['admin', 'coordinator'].includes(role || '') && (
                <a className={itemClass('/agencies')} href="/agencies">Agencies</a>
              )}
              <a className={itemClass('/agency-history')} href="/agency-history">Agency History</a>
              {['admin', 'coordinator'].includes(role || '') && (
                <a className={itemClass('/agency-portal')} href="/agency-portal/manage">Agency Portal</a>
              )}
            </div>
          )}
        </div>

        <a className={pathname.startsWith('/notifications') ? 'active' : 'notification-nav'} href="/notifications">
          Notifications
          {unread > 0 && (
            <span className="notification-badge" aria-label={`${unread} unread notifications`}>
              {unread > 99 ? '99+' : unread}
            </span>
          )}
        </a>

        {role === 'admin' && (
          <div className={styles.navMenu}>
            <button
              className={triggerClass(
                ['/account', '/user-management', '/activity', '/bug-reports', '/request-activity', '/health', '/email-settings', '/test-data-cleanup'].some(
                  (path) => pathname.startsWith(path),
                ),
              )}
              type="button"
              aria-expanded={menu === 'admin'}
              onClick={() => toggleMenu('admin')}
            >
              Administration⌄
            </button>
            {menu === 'admin' && (
              <div className={styles.dropdown}>
                <div className={styles.sectionTitle}>Administration</div>
                <a className={itemClass('/account')} href="/account">Administrator Account</a>
                <a className={itemClass('/user-management')} href="/user-management">User Management</a>
                <a className={itemClass('/activity')} href="/activity">Activity Log</a>
                <a className={itemClass('/bug-reports')} href="/bug-reports">Bug Reports</a>
                <a className={itemClass('/request-activity')} href="/request-activity">Request Activity</a>
                <a className={itemClass('/email-settings')} href="/email-settings">Email Settings</a>
                <a className={itemClass('/health')} href="/health">System Status</a>
                <a className={itemClass('/test-data-cleanup')} href="/test-data-cleanup">Test Data Cleanup</a>
              </div>
            )}
          </div>
        )}

        <div className={styles.navMenu}>
          <button
            className={triggerClass(pathname.startsWith('/help') || pathname.startsWith('/version-history'))}
            type="button"
            aria-expanded={menu === 'help'}
            onClick={() => toggleMenu('help')}
          >
            Help⌄
          </button>
          {menu === 'help' && (
            <div className={styles.dropdown}>
              <div className={styles.sectionTitle}>Help &amp; About</div>
              <a className={itemClass('/help')} href="/help">Application Help</a>
              <a className={itemClass('/version-history')} href="/version-history">Version History</a>
            </div>
          )}
        </div>

        <a className={pathname.startsWith('/library') ? 'active' : ''} href="/library">
          Resource Library
        </a>
      </nav>

      {children}
    </>
  );
}

