-- Reconstructed supporting API contracts.

create or replace function private.bt_get_user_activity_history(p_start timestamptz default null,p_end timestamptz default null,p_actor uuid default null,p_category text default null,p_search text default null,p_limit integer default 5000) returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if public.current_user_role() is distinct from 'admin' then raise exception 'Administrator access required';end if;
 return coalesce((with events as (
 select id::text event_id,created_at occurred_at,'Requests'::text category,action,actor_id,request_id::text reference_id,request_id::text subject,details from public.training_request_activity
 union all select id::text,created_at,'User Administration',action,actor_id,target_user_id::text,target_user_id::text,details from public.user_management_activity
 union all select id::text,created_at,category,action,actor_id,entity_id,subject,details from public.administration_activity
 ), filtered as (select e.*,p.full_name actor_name,p.email actor_email from events e left join public.profiles p on p.id=e.actor_id where (p_start is null or e.occurred_at>=p_start) and (p_end is null or e.occurred_at<p_end) and (p_actor is null or e.actor_id=p_actor) and (p_category is null or e.category=p_category) and (p_search is null or (coalesce(e.subject,'')||' '||e.action||' '||coalesce(p.email,'')) ilike '%'||p_search||'%') order by e.occurred_at desc limit least(greatest(p_limit,1),5000)) select jsonb_agg(to_jsonb(f)) from filtered f),'[]');end
$body$;

create or replace function public.get_user_activity_history(p_start timestamptz default null,p_end timestamptz default null,p_actor uuid default null,p_category text default null,p_search text default null,p_limit integer default 5000) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_user_activity_history(p_start,p_end,p_actor,p_category,p_search,p_limit) $wrapper$;

revoke all on function private.bt_get_user_activity_history(timestamptz,timestamptz,uuid,text,text,integer),public.get_user_activity_history(timestamptz,timestamptz,uuid,text,text,integer) from public,anon;grant execute on function private.bt_get_user_activity_history(timestamptz,timestamptz,uuid,text,text,integer),public.get_user_activity_history(timestamptz,timestamptz,uuid,text,text,integer) to authenticated,service_role;

create or replace function private.bt_get_training_management_analytics(p_start_date date,p_end_date date) returns jsonb language plpgsql security definer set search_path='' as $body$
declare result jsonb;begin
 if not public.is_manager() then raise exception 'Manager access required';end if;
 if p_end_date<p_start_date then raise exception 'Invalid date range';end if;
 with r as materialized (select r.*,coalesce(p.full_name,p.email) trainer from public.training_requests r left join public.profiles p on p.id=r.assigned_trainer_id where r.created_at::date between p_start_date and p_end_date),
 monthly as (select date_trunc('month',coalesce(confirmed_date,created_at::date))::date month_start,count(*) request_count,sum(total_minutes) total_minutes from r group by 1),
 statuses as(select status,count(*) count from r group by 1),formats as(select training_format,count(*) count from r group by 1),
 trainers as(select assigned_trainer_id trainer_id,trainer trainer_name,count(*) requests,count(*) filter(where status='Completed') completed,sum(total_minutes) total_minutes,sum(estimated_attendees) attendees,count(*) filter(where confirmed_date>=current_date and status<>'Completed') upcoming from r group by 1,2),
 agencies as(select agency_id,agency_name,count(*) requests,count(*) filter(where status='Completed') completed,sum(total_minutes) total_minutes,sum(estimated_attendees) attendees,max(confirmed_date) last_training from r group by 1,2),
 modules as(select m.id,m.module_name,m.category,m.duration_minutes,count(*) selected_count from r join public.request_modules rm on rm.request_id=r.id join public.training_modules m on m.id=rm.module_id group by m.id)
 select jsonb_build_object('start_date',p_start_date,'end_date',p_end_date,'requests',coalesce((select jsonb_agg(to_jsonb(r)) from r),'[]'),'monthly',coalesce((select jsonb_agg(to_jsonb(m) order by month_start) from monthly m),'[]'),'status_stats',coalesce((select jsonb_agg(to_jsonb(s)) from statuses s),'[]'),'format_stats',coalesce((select jsonb_agg(to_jsonb(f)) from formats f),'[]'),'trainer_stats',coalesce((select jsonb_agg(to_jsonb(t)) from trainers t),'[]'),'agency_stats',coalesce((select jsonb_agg(to_jsonb(a)) from agencies a),'[]'),'module_stats',coalesce((select jsonb_agg(to_jsonb(m) order by selected_count desc) from modules m),'[]'),'kpis',(select jsonb_build_object('total_requests',count(*),'completed_requests',count(*) filter(where status='Completed'),'open_requests',count(*) filter(where status<>'Completed'),'completion_rate',coalesce(100.0*count(*) filter(where status='Completed')/nullif(count(*),0),0),'total_minutes',coalesce(sum(total_minutes),0),'total_attendees',coalesce(sum(estimated_attendees),0),'avg_lead_days',coalesce(avg(confirmed_date-created_at::date),0),'unassigned_requests',count(*) filter(where assigned_trainer_id is null and status<>'Completed'),'unscheduled_requests',count(*) filter(where confirmed_date is null and status<>'Completed')) from r)) into result;
 return result;end
$body$;

create or replace function public.get_training_management_analytics(p_start_date date,p_end_date date) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_management_analytics(p_start_date,p_end_date) $wrapper$;

revoke all on function private.bt_get_training_management_analytics(date,date),public.get_training_management_analytics(date,date) from public,anon;grant execute on function private.bt_get_training_management_analytics(date,date),public.get_training_management_analytics(date,date) to authenticated,service_role;

create or replace function private.bt_get_training_email_delivery_dashboard() returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if public.current_user_role() is distinct from 'admin' then raise exception 'Administrator access required';end if;
 return jsonb_build_object('queue',(select jsonb_build_object('pending',count(*) filter(where status='pending'),'delivered',count(*) filter(where status in ('sent','delivered')),'failed',count(*) filter(where status='failed'),'provider_failed',0) from public.training_email_queue),'webhook',(select jsonb_build_object('enabled',webhook_enabled,'configured',webhook_secret is not null) from public.training_email_provider_settings where id=1),'templates','[]'::jsonb,'recent_events',coalesce((select jsonb_agg(to_jsonb(e)-'payload') from (select * from public.training_email_delivery_events order by event_at desc limit 100)e),'[]'));end
$body$;

create or replace function public.get_training_email_delivery_dashboard() returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_email_delivery_dashboard() $wrapper$;

revoke all on function private.bt_get_training_email_delivery_dashboard(),public.get_training_email_delivery_dashboard() from public,anon;grant execute on function private.bt_get_training_email_delivery_dashboard(),public.get_training_email_delivery_dashboard() to authenticated,service_role;

create or replace function private.bt_get_training_system_status() returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if public.current_user_role() is distinct from 'admin' then raise exception 'Administrator access required';end if;
 return jsonb_build_object('app',(select jsonb_build_object('version',version,'release_date',release_date) from public.training_app_versions where is_current limit 1),'communications',jsonb_build_object('email_delivery_enabled',coalesce((select enabled from public.training_email_provider_settings where id=1),false),'webhook_enabled',false,'tracking_enabled',false,'email_delivery_cron_active',false),'queue',(select jsonb_build_object('total',count(*),'pending',count(*) filter(where status='pending'),'protected_expected',0,'protected_present',0,'delete_guard_installed',exists(select 1 from pg_trigger where tgname='trg_guard_training_email_queue_delete')) from public.training_email_queue),'jobs',jsonb_build_object('auto_close_active',false,'reminders_active',false,'session_expiration_active',false));end
$body$;

create or replace function public.get_training_system_status() returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_system_status() $wrapper$;

revoke all on function private.bt_get_training_system_status(),public.get_training_system_status() from public,anon;grant execute on function private.bt_get_training_system_status(),public.get_training_system_status() to authenticated,service_role;

create or replace function private.bt_generate_training_reminders() returns integer language plpgsql security definer set search_path='' as $body$
declare r record;n integer:=0;begin
 if not public.is_manager() then raise exception 'Manager access required';end if;
 for r in select * from public.training_requests where archived_at is null and class_status not in ('Closed','Completed','Archived') loop
 if r.assigned_trainer_id is null then n:=n+public.push_manager_notification(r.id,'unassigned','Trainer needed',r.request_number||' needs an assigned trainer','warning','/requests/edit?request='||r.id,'unassigned:'||r.id||':'||current_date);end if;
 if r.confirmed_date is null then n:=n+public.push_manager_notification(r.id,'unscheduled','Schedule needed',r.request_number||' needs a schedule','warning','/requests/edit?request='||r.id,'unscheduled:'||r.id||':'||current_date);end if;end loop;return n;end
$body$;

create or replace function public.generate_training_reminders() returns integer language sql security invoker set search_path='' as $wrapper$ select private.bt_generate_training_reminders() $wrapper$;

revoke all on function private.bt_generate_training_reminders(),public.generate_training_reminders() from public,anon;grant execute on function private.bt_generate_training_reminders(),public.generate_training_reminders() to authenticated,service_role;

create or replace function private.bt_publish_training_material_version(p_version_id uuid) returns void language plpgsql security definer set search_path='' as $body$
declare v public.training_material_versions%rowtype;begin
 if not public.can_manage_training_materials() then raise exception 'Not authorized';end if;
 select * into v from public.training_material_versions where id=p_version_id for update;
 if not found or v.storage_path is null then raise exception 'Upload a material first';end if;
 perform 1 from public.training_materials where id=v.material_id for update;
 update public.training_material_versions set is_current=false where material_id=v.material_id;
 update public.training_material_versions set is_current=true,status='published',updated_at=now() where id=v.id;end
$body$;

create or replace function public.publish_training_material_version(p_version_id uuid) returns void language sql security invoker set search_path='' as $wrapper$ select private.bt_publish_training_material_version(p_version_id) $wrapper$;

revoke all on function private.bt_publish_training_material_version(uuid),public.publish_training_material_version(uuid) from public,anon;grant execute on function private.bt_publish_training_material_version(uuid),public.publish_training_material_version(uuid) to authenticated,service_role;

create or replace function private.bt_create_agency_portal_link(p_agency_id uuid,p_label text default null,p_expires_at timestamptz default null,p_max_submissions integer default null) returns jsonb language plpgsql security definer set search_path='' as $body$
declare a public.agencies%rowtype;tok text;begin
 if not public.is_manager() then raise exception 'Manager access required';end if;
 select * into a from public.agencies where id=p_agency_id and active;
 if not found then raise exception 'Choose an active agency';end if;
 if p_expires_at<=now() or p_max_submissions<1 then raise exception 'Invalid expiration or submission limit';end if;
 tok:=encode(extensions.gen_random_bytes(24),'hex');
 insert into public.agency_portal_links(agency_id,token_hash,token_hint,label,expires_at,max_submissions) values(a.id,encode(extensions.digest(tok,'sha256'),'hex'),right(tok,8),p_label,p_expires_at,p_max_submissions);
 return jsonb_build_object('token',tok,'url','https://backtrace-training-admin.vercel.app/agency-portal?token='||tok,'agency_name',a.agency_name,'expires_at',p_expires_at,'max_submissions',p_max_submissions);end
$body$;

create or replace function public.create_agency_portal_link(p_agency_id uuid,p_label text default null,p_expires_at timestamptz default null,p_max_submissions integer default null) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_create_agency_portal_link(p_agency_id,p_label,p_expires_at,p_max_submissions) $wrapper$;

revoke all on function private.bt_create_agency_portal_link(uuid,text,timestamptz,integer),public.create_agency_portal_link(uuid,text,timestamptz,integer) from public,anon;grant execute on function private.bt_create_agency_portal_link(uuid,text,timestamptz,integer),public.create_agency_portal_link(uuid,text,timestamptz,integer) to authenticated,service_role;

create or replace function private.bt_revoke_agency_portal_link(p_link_id uuid) returns void language plpgsql security definer set search_path='' as $body$
begin if not public.is_manager() then raise exception 'Manager access required';end if;update public.agency_portal_links set active=false,updated_by=auth.uid(),updated_at=now() where id=p_link_id;end
$body$;

create or replace function public.revoke_agency_portal_link(p_link_id uuid) returns void language sql security invoker set search_path='' as $wrapper$ select private.bt_revoke_agency_portal_link(p_link_id) $wrapper$;

revoke all on function private.bt_revoke_agency_portal_link(uuid),public.revoke_agency_portal_link(uuid) from public,anon;grant execute on function private.bt_revoke_agency_portal_link(uuid),public.revoke_agency_portal_link(uuid) to authenticated,service_role;

grant select on public.agency_portal_links to authenticated;create policy manager_portal_read on public.agency_portal_links for select to authenticated using(public.is_manager());

create function public.is_canonical_training_token(p_token text) returns boolean language sql immutable set search_path='' as $$ select p_token ~ '^[0-9a-f]{48}$' $$;

create or replace function private.bt_resolve_public_training_request_token(p_token text) returns jsonb language plpgsql security definer set search_path='' as $body$
declare l public.public_training_request_links%rowtype;begin
 if not public.is_canonical_training_token(p_token) then raise exception 'Invalid training request link';end if;
 select * into l from public.public_training_request_links where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') and active and (expires_at is null or expires_at>now()) and (max_submissions is null or submission_count<max_submissions);
 if not found then raise exception 'Training request link unavailable';end if;
 return jsonb_build_object('label',l.label,'modules',coalesce((select jsonb_agg(jsonb_build_object('id',id,'module_name',module_name,'category',category,'duration_minutes',duration_minutes)) from public.training_modules where active),'[]'));end
$body$;

create or replace function public.resolve_public_training_request_token(p_token text) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_resolve_public_training_request_token(p_token) $wrapper$;

revoke all on function private.bt_resolve_public_training_request_token(text),public.resolve_public_training_request_token(text) from public,anon;grant execute on function private.bt_resolve_public_training_request_token(text),public.resolve_public_training_request_token(text) to authenticated,service_role;

-- Public requests: persist Teams links and ignore tools for fixed-duration courses.
CREATE OR REPLACE FUNCTION public.submit_public_training_request(p_token text, p_data jsonb, p_module_ids bigint[] DEFAULT '{}'::bigint[])
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  l public.public_training_request_links%rowtype;
  v_id uuid;
  v_number text;
  v_basic boolean := coalesce((p_data->>'basic_training')::boolean,false);
  v_train_the_trainer boolean := coalesce((p_data->>'train_the_trainer')::boolean,false);
  v_refresher boolean := coalesce((p_data->>'refresher_course')::boolean,false);
  v_advanced boolean := coalesce((p_data->>'advanced_training')::boolean,false);
  v_total integer := 0;
  v_agency_id uuid;
  v_actor uuid := null;
  v_agency_name text := nullif(trim(p_data->>'agency_name'),'');
  v_contact_person text := nullif(trim(p_data->>'contact_person'),'');
  v_contact_email text := lower(nullif(trim(p_data->>'contact_email'),''));
  v_trainer_name text := nullif(trim(p_data->>'trainer_contact_name'),'');
  v_trainer_email text := lower(nullif(trim(p_data->>'trainer_contact_email'),''));
  v_trainer_phone text := nullif(trim(p_data->>'trainer_contact_phone'),'');
  v_requested_by text;
  v_format text := coalesce(nullif(trim(p_data->>'training_format'),''),'In Person');
  v_teams_url text := nullif(trim(p_data->>'teams_meeting_url'),'');
begin
  if v_teams_url is not null and v_format not in ('Virtual','Hybrid') then
    raise exception 'A Teams meeting link can only be added to Virtual or Hybrid training.';
  end if;
  if v_teams_url is not null and v_teams_url !~* '^https://([a-z0-9-]+[.])*(teams[.]microsoft[.]com|teams[.]live[.]com|teams[.]cloud[.]microsoft)(/|$)' then
    raise exception 'Enter a valid Microsoft Teams meeting link.';
  end if;
  if nullif(trim(coalesce(p_token,'')),'') is not null then
    if not public.is_canonical_training_token(p_token) then raise exception 'Training request link is invalid.'; end if;
    select * into l from public.public_training_request_links
      where token_hash=encode(extensions.digest(btrim(p_token),'sha256'),'hex') for update;
    if l.id is null or not l.active then raise exception 'Training request link is not active.'; end if;
    if l.expires_at is not null and l.expires_at <= now() then raise exception 'Training request link has expired.'; end if;
    if l.max_submissions is not null and l.submission_count >= l.max_submissions then raise exception 'Training request link submission limit has been reached.'; end if;
    v_actor := l.created_by;
  end if;

  if v_agency_name is null then raise exception 'Agency Name is required.'; end if;
  if nullif(trim(p_data->>'agency_address'),'') is null then raise exception 'Agency Address is required.'; end if;
  if nullif(trim(p_data->>'city_state_zip'),'') is null then raise exception 'City, State, ZIP is required.'; end if;
  if v_contact_person is null then raise exception 'Contact Person is required.'; end if;
  if nullif(trim(p_data->>'contact_phone'),'') is null then raise exception 'Contact Phone is required.'; end if;
  if v_contact_email is null or position('@' in v_contact_email)=0 then raise exception 'A valid Contact Email is required.'; end if;
  if v_trainer_name is null then raise exception 'Trainer Name is required.'; end if;
  if v_trainer_email is null or position('@' in v_trainer_email)=0 then raise exception 'A valid Trainer Email is required.'; end if;
  if v_trainer_phone is null then raise exception 'Trainer Phone Number is required.'; end if;
  if (v_basic::int + v_train_the_trainer::int + v_refresher::int + v_advanced::int) <> 1 then
    raise exception 'Select exactly one Training Type Requested.';
  end if;
  if exists(select 1 from public.training_requests where submission_source='public_request' and lower(contact_email)=v_contact_email and created_at > now()-interval '5 minutes') then
    raise exception 'A training request from this email was submitted recently. Please wait a few minutes before submitting another request.';
  end if;

  if (v_refresher or v_advanced) and coalesce(cardinality(p_module_ids),0)=0 then raise exception 'Select training tools';end if;
  v_requested_by := coalesce(nullif(trim(p_data->>'requested_by'),''),v_contact_person);
  select id into v_agency_id from public.agencies
    where lower(trim(agency_name))=lower(v_agency_name) order by active desc, created_at limit 1;

  if v_agency_id is null then
    insert into public.agencies(agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,active,created_by,updated_by)
    values(v_agency_name,nullif(trim(p_data->>'agency_address'),''),nullif(trim(p_data->>'city_state_zip'),''),v_contact_person,nullif(trim(p_data->>'contact_phone'),''),v_contact_email,true,v_actor,v_actor)
    returning id into v_agency_id;
  end if;

  insert into public.training_requests(
    agency_id,agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,
    trainer_contact_name,trainer_contact_email,trainer_contact_phone,preferred_date,alternate_date,
    preferred_start_time,preferred_end_time,time_zone,training_format,teams_meeting_url,estimated_attendees,training_location,
    training_resources,objectives,topics,experience_level,outcomes,additional_requirements,requested_by,status,
    basic_training,train_the_trainer,refresher_course,advanced_training,total_minutes,submission_source,
    public_request_link_id,created_by,updated_by
  ) values(
    v_agency_id,v_agency_name,nullif(trim(p_data->>'agency_address'),''),nullif(trim(p_data->>'city_state_zip'),''),
    v_contact_person,nullif(trim(p_data->>'contact_phone'),''),v_contact_email,v_trainer_name,v_trainer_email,
    v_trainer_phone,nullif(p_data->>'preferred_date','')::date,nullif(p_data->>'alternate_date','')::date,
    nullif(p_data->>'preferred_start_time','')::time,nullif(p_data->>'preferred_end_time','')::time,
    nullif(trim(p_data->>'time_zone'),''),v_format,v_teams_url,
    nullif(p_data->>'estimated_attendees','')::integer,nullif(trim(p_data->>'training_location'),''),
    coalesce(array(select jsonb_array_elements_text(coalesce(p_data->'training_resources','[]'::jsonb))),array[]::text[]),
    nullif(trim(p_data->>'objectives'),''),nullif(trim(p_data->>'topics'),''),nullif(trim(p_data->>'experience_level'),''),
    nullif(trim(p_data->>'outcomes'),''),nullif(trim(p_data->>'additional_requirements'),''),v_requested_by,'Received',
    v_basic,v_train_the_trainer,v_refresher,v_advanced,0,'public_request',nullif(l.id,'00000000-0000-0000-0000-000000000000'),v_actor,v_actor
  ) returning id,request_number into v_id,v_number;

  insert into public.request_modules(request_id,module_id)
  select v_id,m.id from public.training_modules m where (v_refresher or v_advanced) and m.active=true and m.id=any(coalesce(p_module_ids,array[]::bigint[])) on conflict do nothing;

  select (case when v_basic then 240 else 0 end)+(case when v_train_the_trainer then 480 else 0 end)+coalesce(sum(m.duration_minutes),0)
    into v_total from public.request_modules rm join public.training_modules m on m.id=rm.module_id where rm.request_id=v_id;
  update public.training_requests set total_minutes=coalesce(v_total,0) where id=v_id;

  if l.id is not null then
    update public.public_training_request_links set submission_count=submission_count+1,last_used_at=now(),updated_at=now() where id=l.id;
  end if;
  insert into public.training_request_activity(request_id,actor_id,action,details)
    values(v_id,null,'public_request_submitted',jsonb_build_object('public_request_link_id',l.id,'requested_by',v_requested_by,'agency_id',v_agency_id));
  perform public.push_manager_notification(v_id,'portal_submission','New External Training Request',
    v_number||' — '||v_agency_name||' submitted a training request.','info',
    'https://backtrace-training-admin.vercel.app/requests?request='||v_id::text,'public-request:'||v_id::text);
  return jsonb_build_object('id',v_id,'request_number',v_number,'total_minutes',v_total,'agency_name',v_agency_name,'agency_id',v_agency_id);
end;
$function$;

-- Preserve the RPC's actor for unauthenticated public submissions to existing agencies.
CREATE OR REPLACE FUNCTION public.touch_agency()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $function$
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(),new.updated_by,old.updated_by);
  return new;
end;
$function$;



grant execute on function public.submit_public_training_request(text,jsonb,bigint[]),public.resolve_public_training_request_token(text),private.bt_resolve_public_training_request_token(text) to anon,authenticated;


create function private.guard_request_fields() returns trigger language plpgsql set search_path='' as $$begin
 if current_user='authenticated' then
  if tg_op='UPDATE' and old.class_status in ('Closed','Completed','Archived') then raise exception 'Request is locked';end if;
  if tg_op='UPDATE' and (new.class_status is distinct from old.class_status or new.created_by is distinct from old.created_by) then raise exception 'Use the controlled workflow';end if;
  if not public.is_manager() and (new.assigned_trainer_id is not null or new.confirmed_date is not null) and (tg_op='INSERT' or new.assigned_trainer_id is distinct from old.assigned_trainer_id or new.confirmed_date is distinct from old.confirmed_date or new.confirmed_start_time is distinct from old.confirmed_start_time) then raise exception 'Manager scheduling required';end if;
 end if;return new;end$$;
create trigger guard_request_fields before insert or update on public.training_requests for each row execute function private.guard_request_fields();
create trigger agency_touch before update on public.agencies for each row execute function public.touch_agency();
grant execute on function public.create_training_material_share(uuid,uuid[],integer),public.queue_training_material_distribution(uuid,uuid[],text[],integer) to authenticated;
-- Limit privileged functions restored from historical files to their explicit callers.
revoke all on function public.issue_training_certificate(uuid,uuid) from public,anon,authenticated;


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

