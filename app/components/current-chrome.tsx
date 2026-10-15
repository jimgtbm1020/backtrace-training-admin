'use client';

import {useEffect, useRef, useState} from 'react';
import {usePathname} from 'next/navigation';
import {createClient, Session} from '@supabase/supabase-js';
import styles from './current-chrome.module.css';
import PasswordForm from './password-form';

type Role = 'admin' | 'coordinator' | 'trainer' | 'viewer';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
);

export default function CurrentChrome({children}: {children: React.ReactNode}) {
  const pathname = usePathname();
  const [menu, setMenu] = useState<string | null>(null);
  const [session, setSession] = useState<Session | null>(null);
  const [identityChecked,setIdentityChecked]=useState(false),[identityError,setIdentityError]=useState(''),[passwordRequired,setPasswordRequired]=useState(false),[recovery,setRecovery]=useState(false);
  const identityRequest=useRef(0);
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
      setSession(next);setRole(null);setProfileUserId(null);setIdentityError('');
      const check=++identityRequest.current;
      if(!next){setIdentityChecked(true);setPasswordRequired(false);setRecovery(false);}
      else{setIdentityChecked(false);setTimeout(()=>{void supabase.auth.getUser().then(async({data,error})=>{if(!mounted||check!==identityRequest.current)return;if(error||!data.user){setIdentityError('Unable to verify your account. Sign out and sign in again.');setIdentityChecked(true);return;}const {data:claimsData,error:claimsError}=await supabase.auth.getClaims(next.access_token);if(!mounted||check!==identityRequest.current)return;if(claimsError)throw claimsError;const methods=claimsData?.claims?.amr as {method:string}[]|undefined;if(methods?.some(method=>(method.method==='recovery'||method.method==='otp'))&&claimsData?.claims?.session_id!==data.user.app_metadata?.password_recovery_completed_session)setRecovery(true);setPasswordRequired(data.user.app_metadata?.password_change_required===true);setIdentityChecked(true);}).catch(()=>{if(mounted&&check===identityRequest.current){setIdentityError('Unable to verify your account. Sign out and sign in again.');setIdentityChecked(true);}});},0);}
      if(next?.user){void loadRole(next.user.id);void loadCurrentVersion();void loadUnread();}
      else setUnread(0);
    };
    const recoveryHash=new URLSearchParams(window.location.hash.slice(1)).get('backtrace_recovery');
    if(recoveryHash){
      window.history.replaceState(null,'',window.location.pathname+window.location.search);
      void supabase.auth.verifyOtp({token_hash:recoveryHash,type:'recovery'}).then(({data,error})=>{
        if(!mounted)return;
        if(error||!data.session){setIdentityError('This password reset link is expired or already used. Request a new link from the sign-in page.');setIdentityChecked(true);return;}
        setRecovery(true);updateSession(data.session);
      });
    }else supabase.auth.getSession().then(({data})=>updateSession(data.session));
    const {data}=supabase.auth.onAuthStateChange((event,next)=>{if(event==='PASSWORD_RECOVERY')setRecovery(true);updateSession(next);});
    return()=>{mounted=false;profileRequest.current++;identityRequest.current++;data.subscription.unsubscribe();};
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
    const [{data,error},identity] = await Promise.all([supabase.from('profiles').select('role,active').eq('id', id).maybeSingle(),supabase.auth.getUser()]);
    if(request!==profileRequest.current)return;
    if(!identity.error&&identity.data.user?.id===id)setPasswordRequired(identity.data.user.app_metadata?.password_change_required===true);
    const allowed=!identity.error&&identity.data.user?.id===id&&!error&&data?.active&&['admin','coordinator','trainer','viewer'].includes(data.role);
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

  if(!identityChecked)return <main className="shell"><section className="card"><p role="status">Checking sign-in…</p></section></main>;
  if(identityError)return <main className="shell"><section className="card"><p role="alert">{identityError}</p><button onClick={()=>void signOut()}>Sign out</button></section></main>;
  if (!session) return <>{children}</>;
  if(passwordRequired||recovery)return <main className="shell"><h1>Backtrace Account Setup</h1><p>{session.user.email}</p><PasswordForm client={supabase} required={passwordRequired} recovery={recovery} onSaved={()=>window.location.assign('/')}/><button onClick={()=>void signOut()}>Sign out</button></main>;

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

        {profileUserId===session.user.id&&role&&<a className={pathname==='/account'?'active':''} href="/account">My Account</a>}

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
                ['/user-management', '/activity', '/bug-reports', '/request-activity', '/health', '/email-settings', '/test-data-cleanup'].some(
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

