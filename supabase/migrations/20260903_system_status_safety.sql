-- System Status safety parity and protected email queue hardening.
-- This file documents the production-safe SQL already applied on 2026-09-03.
-- It is idempotent and does not recreate, modify, send, or delete email queue rows.

create or replace function public.guard_training_email_queue_delete()
returns trigger
language plpgsql
security definer
set search_path='public'
as $function$
begin
  if tg_op = 'TRUNCATE' then
    raise log 'Blocked TRUNCATE on protected training_email_queue.';
    raise exception 'training_email_queue is protected and cannot be truncated.';
  end if;

  if tg_op = 'DELETE' then
    if current_setting('app.allow_training_email_queue_delete', true) = 'on' then
      return old;
    end if;
    raise log 'Blocked DELETE on protected training_email_queue row id=%', old.id;
    raise exception 'training_email_queue is protected and cannot be deleted directly.';
  end if;

  return old;
end;
$function$;

revoke all on function public.guard_training_email_queue_delete() from public, anon, authenticated;

drop trigger if exists trg_guard_training_email_queue_delete on public.training_email_queue;
create trigger trg_guard_training_email_queue_delete
before delete on public.training_email_queue
for each row
execute function public.guard_training_email_queue_delete();

drop trigger if exists trg_guard_training_email_queue_truncate on public.training_email_queue;
create trigger trg_guard_training_email_queue_truncate
before truncate on public.training_email_queue
for each statement
execute function public.guard_training_email_queue_delete();

create or replace function public.get_training_system_status()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $function$
declare
  v_role text;
  v_enabled_at timestamptz;
begin
  if auth.uid() is null then
    raise exception 'Sign in required.';
  end if;

  select role into v_role
  from public.profiles
  where id=auth.uid() and active=true;

  if v_role is distinct from 'admin' then
    raise exception 'Administrator access required.';
  end if;

  select enabled_at into v_enabled_at
  from public.training_email_provider_settings
  where id=1;

  return jsonb_build_object(
    'app', jsonb_build_object(
      'version', (select version from public.training_app_versions where is_current=true order by release_date desc nulls last limit 1),
      'release_date', (select release_date from public.training_app_versions where is_current=true order by release_date desc nulls last limit 1)
    ),
    'communications', jsonb_build_object(
      'email_delivery_enabled', coalesce((select enabled from public.training_email_provider_settings where id=1),false),
      'webhook_enabled', coalesce((select webhook_enabled from public.training_email_provider_settings where id=1),false),
      'tracking_enabled', coalesce((select enabled from public.training_email_tracking_state where id=1),false),
      'email_delivery_cron_active', coalesce((select active from cron.job where jobname='backtrace_training_email_delivery'),false)
    ),
    'queue', jsonb_build_object(
      'total', (select count(*) from public.training_email_queue),
      'pending', (select count(*) from public.training_email_queue where status='pending'),
      'protected_expected', 26,
      'protected_present', (
        select count(*) from public.training_email_queue
        where status='pending'
          and (v_enabled_at is null or queued_at < v_enabled_at)
      ),
      'delete_guard_installed', (
        select count(*)=2
        from pg_trigger t
        join pg_class c on c.oid=t.tgrelid
        join pg_namespace n on n.oid=c.relnamespace
        where n.nspname='public'
          and c.relname='training_email_queue'
          and t.tgname in ('trg_guard_training_email_queue_delete','trg_guard_training_email_queue_truncate')
          and not t.tgisinternal
      )
    ),
    'jobs', jsonb_build_object(
      'auto_close_active', coalesce((select active from cron.job where jobname='backtrace_training_auto_close_expired'),false),
      'reminders_active', coalesce((select active from cron.job where jobname='backtrace_training_reminders'),false),
      'session_expiration_active', coalesce((select active from cron.job where jobname='backtrace_training_session_expiration'),false)
    )
  );
end;
$function$;

revoke all on function public.get_training_system_status() from public, anon;
grant execute on function public.get_training_system_status() to authenticated;
