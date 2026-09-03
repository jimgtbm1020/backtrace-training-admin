-- Correct System Status after intentional demo email cleanup.
-- The 26 historical pending email rows were demo records and were intentionally deleted.
-- Remove the temporary queue-delete guard and report only the live queue state.

drop trigger if exists trg_guard_training_email_queue_delete on public.training_email_queue;
drop trigger if exists trg_guard_training_email_queue_truncate on public.training_email_queue;
drop function if exists public.guard_training_email_queue_delete();

create or replace function public.get_training_system_status()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $function$
declare
  v_role text;
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
      'pending', (select count(*) from public.training_email_queue where status='pending')
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
