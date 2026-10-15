-- Restore background delivery without exposing scheduler credentials to API clients.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;
create function public.configure_backtrace_delivery(p_key text) returns void language plpgsql security definer set search_path='' as $$begin
 if length(p_key)<100 then raise exception 'Invalid scheduler credential';end if;
 if exists(select 1 from vault.secrets where name='backtrace_delivery_key') then raise exception 'Scheduler credential is already configured';end if;
 perform vault.create_secret(p_key,'backtrace_delivery_key','Server-only Backtrace background delivery');end$$;
revoke all on function public.configure_backtrace_delivery(text) from public,anon,authenticated;
grant execute on function public.configure_backtrace_delivery(text) to service_role;
create function public.claim_training_email_batch() returns setof public.training_email_queue language plpgsql security definer set search_path='' as $$begin
 if not exists(select 1 from public.training_email_provider_settings where id=1 and enabled) then return;end if;
 -- Recover leases after a worker crash; the provider idempotency key prevents duplicate sends.
 update public.training_email_queue set status='pending' where status='processing' and updated_at<now()-interval '10 minutes' and attempts<3;
 return query with selected as(select id from public.training_email_queue where status='pending' and coalesce(next_attempt_at,now())<=now() and attempts<3 order by id for update skip locked limit 20)
 update public.training_email_queue q set status='processing',attempts=attempts+1,updated_at=now() from selected s where q.id=s.id returning q.*;end$$;
revoke all on function public.claim_training_email_batch() from public,anon,authenticated;
grant execute on function public.claim_training_email_batch() to service_role;
select cron.schedule('backtrace_training_email_delivery','* * * * *',$job$select net.http_post(url:='https://dzqsmqispdixwmklpwdf.supabase.co/functions/v1/deliver-training-email',headers:=jsonb_build_object('Content-Type','application/json','Authorization','Bearer '||(select decrypted_secret from vault.decrypted_secrets where name='backtrace_delivery_key')),body:='{}'::jsonb,timeout_milliseconds:=55000) where exists(select 1 from vault.secrets where name='backtrace_delivery_key');$job$);
select cron.schedule('backtrace_training_auto_close_expired','*/15 * * * *','select public.auto_close_expired_training_classes();');
create function private.generate_scheduled_reminders() returns void language plpgsql security definer set search_path='' as $$declare r record;begin
 for r in select * from public.training_requests where archived_at is null and class_status not in ('Closed','Completed','Archived') loop
 if r.assigned_trainer_id is null then perform public.push_manager_notification(r.id,'unassigned','Trainer needed',r.request_number||' needs a trainer','warning','/requests/edit?request='||r.id,'unassigned:'||r.id||':'||current_date);end if;
 if r.confirmed_date is null then perform public.push_manager_notification(r.id,'unscheduled','Schedule needed',r.request_number||' needs a schedule','warning','/requests/edit?request='||r.id,'unscheduled:'||r.id||':'||current_date);end if;end loop;end$$;
revoke all on function private.generate_scheduled_reminders() from public,anon,authenticated,service_role;
select cron.schedule('backtrace_training_reminders','0 * * * *','select private.generate_scheduled_reminders();');

create or replace function private.bt_get_training_system_status() returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if public.current_user_role() is distinct from 'admin' then raise exception 'Administrator access required';end if;
 return jsonb_build_object('app',(select jsonb_build_object('version',version,'release_date',release_date) from public.training_app_versions where is_current limit 1),'communications',jsonb_build_object('email_delivery_enabled',coalesce((select enabled from public.training_email_provider_settings where id=1),false),'webhook_enabled',false,'tracking_enabled',false,'email_delivery_cron_active',coalesce((select active from cron.job where jobname='backtrace_training_email_delivery'),false)),'queue',(select jsonb_build_object('total',count(*),'pending',count(*) filter(where status='pending'),'protected_expected',0,'protected_present',0,'delete_guard_installed',exists(select 1 from pg_trigger where tgname='trg_guard_training_email_queue_delete')) from public.training_email_queue),'jobs',jsonb_build_object('auto_close_active',coalesce((select active from cron.job where jobname='backtrace_training_auto_close_expired'),false),'reminders_active',coalesce((select active from cron.job where jobname='backtrace_training_reminders'),false),'session_expiration_active',false));end
$body$;

