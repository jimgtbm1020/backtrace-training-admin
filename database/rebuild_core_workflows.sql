-- Reconstructed request and attendance contracts. Apply after rebuild_saved_workflows.sql.

create or replace function private.bt_push_manager_notification(p_request_id uuid,p_type text,p_title text,p_message text,p_severity text,p_url text,p_dedupe text) returns integer language plpgsql security definer set search_path='' as $body$
declare n integer;begin
 if current_user not in ('postgres','service_role') and not public.is_active_user() then raise exception 'Active account required';end if;
 insert into public.training_notifications(user_id,request_id,notification_type,title,message,severity,action_url,dedupe_key)
 select id,p_request_id,p_type,p_title,p_message,p_severity,p_url,p_dedupe from public.profiles where active and role in ('admin','coordinator') on conflict(user_id,dedupe_key) do nothing;
 get diagnostics n=row_count;return n;end
$body$;

create or replace function public.push_manager_notification(p_request_id uuid,p_type text,p_title text,p_message text,p_severity text,p_url text,p_dedupe text) returns integer language sql security invoker set search_path='' as $wrapper$ select private.bt_push_manager_notification(p_request_id,p_type,p_title,p_message,p_severity,p_url,p_dedupe) $wrapper$;

revoke all on function private.bt_push_manager_notification(uuid,text,text,text,text,text,text),public.push_manager_notification(uuid,text,text,text,text,text,text) from public,anon;grant execute on function private.bt_push_manager_notification(uuid,text,text,text,text,text,text),public.push_manager_notification(uuid,text,text,text,text,text,text) to authenticated,service_role;

revoke all on function public.push_manager_notification(uuid,text,text,text,text,text,text),private.bt_push_manager_notification(uuid,text,text,text,text,text,text) from authenticated;

create or replace function private.bt_training_schedule_conflicts(p_request_id uuid,p_confirmed_date date,p_confirmed_start_time time,p_duration_minutes integer,p_assigned_trainer_id uuid) returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if not public.is_manager() then raise exception 'Manager access required';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('request_id',id,'request_number',request_number,'agency_name',agency_name)) from public.training_requests where id is distinct from p_request_id and archived_at is null and class_status not in ('Closed','Completed','Archived') and assigned_trainer_id=p_assigned_trainer_id and confirmed_date=p_confirmed_date and (confirmed_date+confirmed_start_time)<(p_confirmed_date+p_confirmed_start_time)+make_interval(mins=>p_duration_minutes) and (p_confirmed_date+p_confirmed_start_time)<(confirmed_date+confirmed_start_time)+make_interval(mins=>total_minutes)),'[]');end
$body$;

create or replace function public.training_schedule_conflicts(p_request_id uuid,p_confirmed_date date,p_confirmed_start_time time,p_duration_minutes integer,p_assigned_trainer_id uuid) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_training_schedule_conflicts(p_request_id,p_confirmed_date,p_confirmed_start_time,p_duration_minutes,p_assigned_trainer_id) $wrapper$;

revoke all on function private.bt_training_schedule_conflicts(uuid,date,time,integer,uuid),public.training_schedule_conflicts(uuid,date,time,integer,uuid) from public,anon;grant execute on function private.bt_training_schedule_conflicts(uuid,date,time,integer,uuid),public.training_schedule_conflicts(uuid,date,time,integer,uuid) to authenticated,service_role;

create or replace function private.bt_set_training_schedule(p_request_id uuid,p_confirmed_date date,p_confirmed_start_time time,p_assigned_trainer_id uuid) returns void language plpgsql security definer set search_path='' as $body$
declare r public.training_requests%rowtype;begin
 if not public.is_manager() then raise exception 'Manager access required';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_assigned_trainer_id::text,0));
 select * into r from public.training_requests where id=p_request_id for update;
 if not found or r.class_status in ('Closed','Completed','Archived') then raise exception 'Request unavailable or locked';end if;
 if p_confirmed_date is null or p_confirmed_start_time is null or not exists(select 1 from public.profiles where id=p_assigned_trainer_id and active and role in ('admin','coordinator','trainer')) then raise exception 'Choose a date, time, and active trainer';end if;
 if jsonb_array_length(public.training_schedule_conflicts(r.id,p_confirmed_date,p_confirmed_start_time,r.total_minutes,p_assigned_trainer_id))>0 then raise exception 'Scheduling conflict';end if;
 update public.training_requests set confirmed_date=p_confirmed_date,confirmed_start_time=p_confirmed_start_time,assigned_trainer_id=p_assigned_trainer_id,class_status=case when class_status='Draft' then 'Scheduled' else class_status end,status='Scheduled',scheduled_at=now(),scheduled_by=auth.uid(),updated_by=auth.uid(),updated_at=now() where id=r.id;
 insert into public.training_request_activity(request_id,actor_id,action,details) values(r.id,auth.uid(),'schedule_updated',jsonb_build_object('date',p_confirmed_date,'time',p_confirmed_start_time,'trainer_id',p_assigned_trainer_id));end
$body$;

create or replace function public.set_training_schedule(p_request_id uuid,p_confirmed_date date,p_confirmed_start_time time,p_assigned_trainer_id uuid) returns void language sql security invoker set search_path='' as $wrapper$ select private.bt_set_training_schedule(p_request_id,p_confirmed_date,p_confirmed_start_time,p_assigned_trainer_id) $wrapper$;

revoke all on function private.bt_set_training_schedule(uuid,date,time,uuid),public.set_training_schedule(uuid,date,time,uuid) from public,anon;grant execute on function private.bt_set_training_schedule(uuid,date,time,uuid),public.set_training_schedule(uuid,date,time,uuid) to authenticated,service_role;

-- Update Basic Backtrace Search Techniques from 90 minutes to 240 minutes.
-- Historical requests are intentionally not rewritten; this affects new submissions and future edits.

create or replace function public.save_training_request(
  p_id uuid,
  p_data jsonb,
  p_module_ids bigint[] default '{}'::bigint[]
)
returns uuid
language plpgsql
set search_path to 'public'
as $function$
declare
  v_id uuid;
  v_basic boolean := coalesce((p_data->>'basic_training')::boolean,false);
  v_train_the_trainer boolean := coalesce((p_data->>'train_the_trainer')::boolean,false);
  v_refresher boolean := coalesce((p_data->>'refresher_course')::boolean,false);
  v_advanced boolean := coalesce((p_data->>'advanced_training')::boolean,false);
  v_total integer;
  v_manager boolean := public.is_manager();
  v_old_module_ids bigint[] := array[]::bigint[];
  v_new_module_ids bigint[] := array[]::bigint[];
  v_added jsonb := '[]'::jsonb;
  v_removed jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or public.current_user_role() not in ('admin','coordinator','trainer') then raise exception 'Active staff account required';end if;
  if (v_basic::int + v_train_the_trainer::int + v_refresher::int + v_advanced::int) <> 1 then
    raise exception 'Select exactly one Training Type Requested.';
  end if;
  if p_id is not null then
    select coalesce(array_agg(module_id order by module_id),array[]::bigint[]) into v_old_module_ids from public.request_modules where request_id=p_id;
  end if;
  if p_id is null then
    insert into public.training_requests (
      agency_id,agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,
      trainer_contact_name,trainer_contact_email,trainer_contact_phone,
      preferred_date,alternate_date,preferred_start_time,preferred_end_time,time_zone,
      training_format,estimated_attendees,training_location,training_resources,
      objectives,topics,experience_level,outcomes,additional_requirements,requested_by,submission_source,
      status,assigned_trainer_id,confirmed_date,confirmed_start_time,basic_training,train_the_trainer,refresher_course,advanced_training,internal_notes
    ) values (
      nullif(p_data->>'agency_id','')::uuid,
      nullif(p_data->>'agency_name',''),nullif(p_data->>'agency_address',''),nullif(p_data->>'city_state_zip',''),
      nullif(p_data->>'contact_person',''),nullif(p_data->>'contact_phone',''),nullif(p_data->>'contact_email',''),
      nullif(p_data->>'trainer_contact_name',''),lower(nullif(p_data->>'trainer_contact_email','')),nullif(p_data->>'trainer_contact_phone',''),
      nullif(p_data->>'preferred_date','')::date,nullif(p_data->>'alternate_date','')::date,
      nullif(p_data->>'preferred_start_time','')::time,nullif(p_data->>'preferred_end_time','')::time,nullif(p_data->>'time_zone',''),
      coalesce(nullif(p_data->>'training_format',''),'In Person'),nullif(p_data->>'estimated_attendees','')::integer,nullif(p_data->>'training_location',''),
      coalesce(array(select jsonb_array_elements_text(coalesce(p_data->'training_resources','[]'::jsonb))),array[]::text[]),
      nullif(p_data->>'objectives',''),nullif(p_data->>'topics',''),nullif(p_data->>'experience_level',''),nullif(p_data->>'outcomes',''),
      nullif(p_data->>'additional_requirements',''),nullif(p_data->>'requested_by',''),coalesce(nullif(p_data->>'submission_source',''),'internal'),
      coalesce(nullif(p_data->>'status',''),'Received'),
      case when v_manager then nullif(p_data->>'assigned_trainer_id','')::uuid else null end,
      case when v_manager then nullif(p_data->>'confirmed_date','')::date else null end,
      case when v_manager then nullif(p_data->>'confirmed_start_time','')::time else null end,
      v_basic,v_train_the_trainer,v_refresher,v_advanced,nullif(p_data->>'internal_notes','')
    ) returning id into v_id;
  else
    if not public.can_edit_request(p_id) then raise exception 'You do not have permission to edit this request.'; end if;
    update public.training_requests set
      agency_id=nullif(p_data->>'agency_id','')::uuid,
      agency_name=nullif(p_data->>'agency_name',''), agency_address=nullif(p_data->>'agency_address',''), city_state_zip=nullif(p_data->>'city_state_zip',''),
      contact_person=nullif(p_data->>'contact_person',''), contact_phone=nullif(p_data->>'contact_phone',''), contact_email=nullif(p_data->>'contact_email',''),
      trainer_contact_name=nullif(p_data->>'trainer_contact_name',''), trainer_contact_email=lower(nullif(p_data->>'trainer_contact_email','')), trainer_contact_phone=nullif(p_data->>'trainer_contact_phone',''),
      preferred_date=nullif(p_data->>'preferred_date','')::date, alternate_date=nullif(p_data->>'alternate_date','')::date,
      preferred_start_time=nullif(p_data->>'preferred_start_time','')::time, preferred_end_time=nullif(p_data->>'preferred_end_time','')::time,
      time_zone=nullif(p_data->>'time_zone',''), training_format=coalesce(nullif(p_data->>'training_format',''),'In Person'),
      estimated_attendees=nullif(p_data->>'estimated_attendees','')::integer, training_location=nullif(p_data->>'training_location',''),
      training_resources=coalesce(array(select jsonb_array_elements_text(coalesce(p_data->'training_resources','[]'::jsonb))),array[]::text[]),
      objectives=nullif(p_data->>'objectives',''), topics=nullif(p_data->>'topics',''), experience_level=nullif(p_data->>'experience_level',''),
      outcomes=nullif(p_data->>'outcomes',''), additional_requirements=nullif(p_data->>'additional_requirements',''), requested_by=nullif(p_data->>'requested_by',''),
      status=coalesce(nullif(p_data->>'status',''),'Received'),
      assigned_trainer_id=case when v_manager then nullif(p_data->>'assigned_trainer_id','')::uuid else assigned_trainer_id end,
      confirmed_date=case when v_manager then nullif(p_data->>'confirmed_date','')::date else confirmed_date end,
      confirmed_start_time=case when v_manager then nullif(p_data->>'confirmed_start_time','')::time else confirmed_start_time end,
      basic_training=v_basic, train_the_trainer=v_train_the_trainer, refresher_course=v_refresher, advanced_training=v_advanced, internal_notes=nullif(p_data->>'internal_notes','')
    where id=p_id;
    v_id := p_id;
  end if;
  delete from public.request_modules where request_id=v_id;
  insert into public.request_modules(request_id,module_id)
  select v_id,m.id from public.training_modules m where (v_refresher or v_advanced) and m.active=true and m.id = any(coalesce(p_module_ids,array[]::bigint[]));
  select coalesce(array_agg(module_id order by module_id),array[]::bigint[]) into v_new_module_ids from public.request_modules where request_id=v_id;
  if v_old_module_ids is distinct from v_new_module_ids then
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',m.module_name,'category',m.category) order by m.category,m.sort_order,m.module_name),'[]'::jsonb) into v_added
    from public.training_modules m where m.id=any(v_new_module_ids) and not (m.id=any(v_old_module_ids));
    select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',m.module_name,'category',m.category) order by m.category,m.sort_order,m.module_name),'[]'::jsonb) into v_removed
    from public.training_modules m where m.id=any(v_old_module_ids) and not (m.id=any(v_new_module_ids));
    insert into public.training_request_activity(request_id,actor_id,action,details) values(v_id,auth.uid(),'modules_changed',jsonb_build_object('added',v_added,'removed',v_removed));
  end if;
  select (case when v_basic then 240 else 0 end) + (case when v_train_the_trainer then 480 else 0 end) + coalesce(sum(m.duration_minutes),0)
  into v_total from public.request_modules rm join public.training_modules m on m.id=rm.module_id where rm.request_id=v_id;
  update public.training_requests
  set total_minutes=coalesce(v_total,(case when v_basic then 240 else 0 end)+(case when v_train_the_trainer then 480 else 0 end)),
      scheduled_at=case when confirmed_date is not null and confirmed_start_time is not null then coalesce(scheduled_at,now()) else scheduled_at end,
      scheduled_by=case when confirmed_date is not null and confirmed_start_time is not null then coalesce(scheduled_by,auth.uid()) else scheduled_by end
  where id=v_id;
  return v_id;
end;
$function$;



grant execute on function public.save_training_request(uuid,jsonb,bigint[]) to authenticated;

create or replace function private.bt_admin_save_training_request(p_id uuid,p_data jsonb,p_module_ids bigint[] default '{}'::bigint[]) returns uuid language plpgsql security definer set search_path='' as $body$
declare v uuid;begin
 if not public.is_manager() then raise exception 'Manager access required';end if;
 if exists(select 1 from public.training_requests where id=p_id and class_status in ('Closed','Completed','Archived')) then raise exception 'Request is locked';end if;
 v:=public.save_training_request(p_id,p_data,p_module_ids);
 perform public.set_training_request_teams_link(v,p_data->>'teams_meeting_url');
 if nullif(p_data->>'confirmed_date','') is not null then perform public.set_training_schedule(v,(p_data->>'confirmed_date')::date,(p_data->>'confirmed_start_time')::time,(p_data->>'assigned_trainer_id')::uuid);end if;
 return v;end
$body$;

create or replace function public.admin_save_training_request(p_id uuid,p_data jsonb,p_module_ids bigint[] default '{}'::bigint[]) returns uuid language sql security invoker set search_path='' as $wrapper$ select private.bt_admin_save_training_request(p_id,p_data,p_module_ids) $wrapper$;

revoke all on function private.bt_admin_save_training_request(uuid,jsonb,bigint[]),public.admin_save_training_request(uuid,jsonb,bigint[]) from public,anon;grant execute on function private.bt_admin_save_training_request(uuid,jsonb,bigint[]),public.admin_save_training_request(uuid,jsonb,bigint[]) to authenticated,service_role;

create or replace function private.bt_get_training_class_archive_detail(p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if not public.is_active_user() then raise exception 'Active account required';end if;
 return jsonb_build_object('request',(select to_jsonb(r) from public.training_requests r where id=p_request_id),'trainer_name',(select coalesce(p.full_name,p.email) from public.profiles p join public.training_requests r on r.assigned_trainer_id=p.id where r.id=p_request_id),'attendees',coalesce((select jsonb_agg(to_jsonb(a) order by a.full_name) from public.training_attendees a where request_id=p_request_id),'[]'),'completion',(select to_jsonb(c) from public.training_completion_records c where request_id=p_request_id),'modules',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'name',m.module_name,'duration_minutes',m.duration_minutes)) from public.request_modules rm join public.training_modules m on m.id=rm.module_id where rm.request_id=p_request_id),'[]'));end
$body$;

create or replace function public.get_training_class_archive_detail(p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_class_archive_detail(p_request_id) $wrapper$;

revoke all on function private.bt_get_training_class_archive_detail(uuid),public.get_training_class_archive_detail(uuid) from public,anon;grant execute on function private.bt_get_training_class_archive_detail(uuid),public.get_training_class_archive_detail(uuid) to authenticated,service_role;

create or replace function private.bt_get_training_attendance_classes() returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if not public.is_active_user() then raise exception 'Active account required';end if;
 return coalesce((select jsonb_agg(to_jsonb(r)||jsonb_build_object('request_id',r.id,'trainer_name',p.full_name,'session_id',s.id,'session_active',coalesce(s.active,false),'registration_open',coalesce(s.registration_open,false),'token_hint',s.token_hint,'registered_count',(select count(*) from public.training_attendees a where a.request_id=r.id),'checked_in_count',(select count(*) from public.training_attendees a where a.request_id=r.id and a.checked_in_at is not null),'completed_count',(select count(*) from public.training_attendees a where a.request_id=r.id and a.certificate_number is not null))) from public.training_requests r left join public.profiles p on p.id=r.assigned_trainer_id left join public.training_attendance_sessions s on s.request_id=r.id where public.can_edit_request(r.id) and r.archived_at is null and r.confirmed_date is not null),'[]');end
$body$;

create or replace function public.get_training_attendance_classes() returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_attendance_classes() $wrapper$;

revoke all on function private.bt_get_training_attendance_classes(),public.get_training_attendance_classes() from public,anon;grant execute on function private.bt_get_training_attendance_classes(),public.get_training_attendance_classes() to authenticated,service_role;

create or replace function private.bt_create_training_attendance_link(p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $body$
declare r public.training_requests%rowtype;tok text;sid uuid;begin
 if not public.can_edit_request(p_request_id) then raise exception 'Not authorized';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if r.class_status in ('Closed','Completed','Archived') or r.confirmed_date is null then raise exception 'Class is locked or unscheduled';end if;
 tok:=encode(extensions.gen_random_bytes(24),'hex');
 insert into public.training_attendance_sessions(request_id,token_hash,token_hint) values(r.id,encode(extensions.digest(tok,'sha256'),'hex'),right(tok,8)) on conflict(request_id) do update set token_hash=excluded.token_hash,token_hint=excluded.token_hint,updated_at=now() returning id into sid;
 update public.training_requests set class_status=case when class_status='In Progress' then class_status else 'Registration Open' end where id=r.id;
 return jsonb_build_object('session_id',sid,'url','https://dzqsmqispdixwmklpwdf.supabase.co/functions/v1/training-attendance?token='||tok,'class_status','Registration Open');end
$body$;

create or replace function public.create_training_attendance_link(p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_create_training_attendance_link(p_request_id) $wrapper$;

revoke all on function private.bt_create_training_attendance_link(uuid),public.create_training_attendance_link(uuid) from public,anon;grant execute on function private.bt_create_training_attendance_link(uuid),public.create_training_attendance_link(uuid) to authenticated,service_role;

create or replace function private.bt_start_training_class(p_request_id uuid) returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if not public.can_edit_request(p_request_id) then raise exception 'Not authorized';end if;
 perform 1 from public.training_requests where id=p_request_id and class_status in ('Scheduled','Registration Open') for update;
 if not found or not exists(select 1 from public.training_attendance_sessions where request_id=p_request_id) then raise exception 'Generate an eligible class first';end if;
 update public.training_requests set class_status='In Progress',class_started_at=now(),class_started_by=auth.uid(),updated_by=auth.uid() where id=p_request_id;
 update public.training_attendance_sessions set registration_open=false,checkin_open_at=now(),checkin_close_at=null where request_id=p_request_id;
 return jsonb_build_object('class_status','In Progress');end
$body$;

create or replace function public.start_training_class(p_request_id uuid) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_start_training_class(p_request_id) $wrapper$;

revoke all on function private.bt_start_training_class(uuid),public.start_training_class(uuid) from public,anon;grant execute on function private.bt_start_training_class(uuid),public.start_training_class(uuid) to authenticated,service_role;

create or replace function private.bt_add_training_attendee(p_request_id uuid,p_full_name text,p_email text,p_badge_id text,p_title_position text default null,p_check_in boolean default false) returns uuid language plpgsql security definer set search_path='' as $body$
declare pid uuid;sid uuid;aid uuid;r public.training_requests%rowtype;begin
 if not public.can_edit_request(p_request_id) then raise exception 'Not authorized';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if r.class_status in ('Closed','Completed','Archived') then raise exception 'Class is locked';end if;
 select id into sid from public.training_attendance_sessions where request_id=p_request_id and active;
 if sid is null then raise exception 'Generate Class first';end if;
 if length(trim(p_full_name))<2 or position('@' in p_email)<2 or nullif(trim(p_badge_id),'') is null then raise exception 'Name, email and Badge / ID are required';end if;
 select id into pid from public.training_people where lower(email)=lower(trim(p_email)) and agency_name=r.agency_name limit 1;
 if pid is null then insert into public.training_people(agency_name,badge_id,full_name,email,title_position) values(r.agency_name,trim(p_badge_id),trim(p_full_name),lower(trim(p_email)),p_title_position) returning id into pid;end if;
 insert into public.training_attendees(request_id,session_id,person_id,agency_name,full_name,email,badge_id,title_position,checked_in_at,attendance_status) values(r.id,sid,pid,r.agency_name,trim(p_full_name),lower(trim(p_email)),trim(p_badge_id),p_title_position,case when p_check_in then now() end,case when p_check_in then 'checked_in' else 'registered' end) returning id into aid;return aid;end
$body$;

create or replace function public.add_training_attendee(p_request_id uuid,p_full_name text,p_email text,p_badge_id text,p_title_position text default null,p_check_in boolean default false) returns uuid language sql security invoker set search_path='' as $wrapper$ select private.bt_add_training_attendee(p_request_id,p_full_name,p_email,p_badge_id,p_title_position,p_check_in) $wrapper$;

revoke all on function private.bt_add_training_attendee(uuid,text,text,text,text,boolean),public.add_training_attendee(uuid,text,text,text,text,boolean) from public,anon;grant execute on function private.bt_add_training_attendee(uuid,text,text,text,text,boolean),public.add_training_attendee(uuid,text,text,text,text,boolean) to authenticated,service_role;

create or replace function private.bt_next_training_certificate_number() returns text language plpgsql security definer set search_path='' as $body$
begin return 'BT-CERT-'||lpad(nextval('public.training_certificate_number_seq')::text,6,'0');end
$body$;

create or replace function public.next_training_certificate_number() returns text language sql security invoker set search_path='' as $wrapper$ select private.bt_next_training_certificate_number() $wrapper$;

revoke all on function private.bt_next_training_certificate_number(),public.next_training_certificate_number() from public,anon;grant execute on function private.bt_next_training_certificate_number(),public.next_training_certificate_number() to authenticated,service_role;

revoke all on function public.next_training_certificate_number(),private.bt_next_training_certificate_number() from authenticated;

create or replace function private.bt_queue_training_certificate_email(p_attendee_id uuid) returns void language plpgsql security definer set search_path='' as $body$
declare a public.training_attendees%rowtype;q bigint;begin
 select * into a from public.training_attendees where id=p_attendee_id;
 if a.certificate_public_id is null then raise exception 'Certificate is not issued';end if;
 insert into public.training_email_queue(recipient_email,subject,text_body,dedupe_key) values(a.email,'Backtrace Training Certificate','Your certificate number is '||a.certificate_number||'.','certificate:'||a.id) on conflict(dedupe_key) do nothing returning id into q;
 if q is not null then insert into public.training_certificate_email_deliveries(attendee_id,email_queue_id) values(a.id,q);end if;end
$body$;

create or replace function public.queue_training_certificate_email(p_attendee_id uuid) returns void language sql security invoker set search_path='' as $wrapper$ select private.bt_queue_training_certificate_email(p_attendee_id) $wrapper$;

revoke all on function private.bt_queue_training_certificate_email(uuid),public.queue_training_certificate_email(uuid) from public,anon;grant execute on function private.bt_queue_training_certificate_email(uuid),public.queue_training_certificate_email(uuid) to authenticated,service_role;

revoke all on function public.queue_training_certificate_email(uuid),private.bt_queue_training_certificate_email(uuid) from authenticated;

create or replace function private.bt_set_training_attendee_completion(p_attendee_id uuid,p_completed boolean) returns uuid language plpgsql security definer set search_path='' as $body$
declare a public.training_attendees%rowtype;begin
 select * into a from public.training_attendees where id=p_attendee_id for update;
 if not found or not public.can_edit_request(a.request_id) then raise exception 'Not authorized';end if;
 if p_completed then return public.issue_training_certificate(a.id,auth.uid());end if;
 if a.certificate_public_id is not null then raise exception 'Issued certificates are permanent';end if;
 update public.training_attendees set attendance_status='ineligible' where id=a.id;return null;end
$body$;

create or replace function public.set_training_attendee_completion(p_attendee_id uuid,p_completed boolean) returns uuid language sql security invoker set search_path='' as $wrapper$ select private.bt_set_training_attendee_completion(p_attendee_id,p_completed) $wrapper$;

revoke all on function private.bt_set_training_attendee_completion(uuid,boolean),public.set_training_attendee_completion(uuid,boolean) from public,anon;grant execute on function private.bt_set_training_attendee_completion(uuid,boolean),public.set_training_attendee_completion(uuid,boolean) to authenticated,service_role;

create or replace function private.bt_get_training_certificate(p_certificate_id uuid) returns jsonb language plpgsql security definer set search_path='' as $body$
begin
 if not public.is_active_user() then raise exception 'Active account required';end if;
 return (select jsonb_build_object('attendee_name',certificate_attendee_name_snapshot,'agency_name',certificate_agency_name_snapshot,'training_type',certificate_training_type_snapshot,'training_date',certificate_training_date_snapshot,'trainer_name',certificate_trainer_name_snapshot,'certificate_number',certificate_number,'total_minutes',certificate_total_minutes_snapshot) from public.training_attendees where certificate_public_id=p_certificate_id);end
$body$;

create or replace function public.get_training_certificate(p_certificate_id uuid) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_certificate(p_certificate_id) $wrapper$;

revoke all on function private.bt_get_training_certificate(uuid),public.get_training_certificate(uuid) from public,anon;grant execute on function private.bt_get_training_certificate(uuid),public.get_training_certificate(uuid) to authenticated,service_role;

create or replace function private.bt_get_training_certificate_background_asset(p_asset_key text) returns jsonb language plpgsql security definer set search_path='' as $body$
begin if not public.is_active_user() then raise exception 'Active account required';end if;return null;end
$body$;

create or replace function public.get_training_certificate_background_asset(p_asset_key text) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_get_training_certificate_background_asset(p_asset_key) $wrapper$;

revoke all on function private.bt_get_training_certificate_background_asset(text),public.get_training_certificate_background_asset(text) from public,anon;grant execute on function private.bt_get_training_certificate_background_asset(text),public.get_training_certificate_background_asset(text) to authenticated,service_role;

create or replace function private.bt_save_training_completion(p_request_id uuid,p_data jsonb,p_module_ids bigint[] default '{}'::bigint[],p_finalize boolean default false) returns jsonb language plpgsql security definer set search_path='' as $body$
declare c public.training_completion_records%rowtype;r public.training_requests%rowtype;a record;begin
 if not public.can_edit_request(p_request_id) then raise exception 'Not authorized';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if r.class_status<>'Closed' then raise exception 'Close the class first';end if;
 select * into c from public.training_completion_records where request_id=p_request_id for update;
 if c.record_status='Finalized' then raise exception 'Completion is locked';end if;
 insert into public.training_completion_records(request_id,actual_training_date,actual_start_time,actual_end_time,actual_minutes,actual_attendees,basic_training_completed,trainer_notes,follow_up_required,follow_up_notes,agency_feedback_score,agency_feedback_notes,record_status,finalized_at,finalized_by)
 values(p_request_id,nullif(p_data->>'actual_training_date','')::date,nullif(p_data->>'actual_start_time','')::time,nullif(p_data->>'actual_end_time','')::time,nullif(p_data->>'actual_minutes','')::integer,nullif(p_data->>'actual_attendees','')::integer,coalesce((p_data->>'basic_training_completed')::boolean,false),p_data->>'trainer_notes',coalesce((p_data->>'follow_up_required')::boolean,false),p_data->>'follow_up_notes',nullif(p_data->>'agency_feedback_score','')::integer,p_data->>'agency_feedback_notes',case when p_finalize then 'Finalized' else 'Draft' end,case when p_finalize then now() end,case when p_finalize then auth.uid() end)
 on conflict(request_id) do update set actual_training_date=excluded.actual_training_date,actual_start_time=excluded.actual_start_time,actual_end_time=excluded.actual_end_time,actual_minutes=excluded.actual_minutes,actual_attendees=excluded.actual_attendees,basic_training_completed=excluded.basic_training_completed,trainer_notes=excluded.trainer_notes,follow_up_required=excluded.follow_up_required,follow_up_notes=excluded.follow_up_notes,agency_feedback_score=excluded.agency_feedback_score,agency_feedback_notes=excluded.agency_feedback_notes,record_status=excluded.record_status,finalized_at=excluded.finalized_at,finalized_by=excluded.finalized_by returning * into c;
 delete from public.training_completion_modules where request_id=p_request_id;
 insert into public.training_completion_modules(request_id,module_id) select p_request_id,id from public.training_modules where id=any(p_module_ids);
 if p_finalize then for a in select id from public.training_attendees where request_id=p_request_id and checked_in_at is not null and attendance_status<>'ineligible' loop perform public.issue_training_certificate(a.id,auth.uid());end loop;end if;
 return to_jsonb(c);end
$body$;

create or replace function public.save_training_completion(p_request_id uuid,p_data jsonb,p_module_ids bigint[] default '{}'::bigint[],p_finalize boolean default false) returns jsonb language sql security invoker set search_path='' as $wrapper$ select private.bt_save_training_completion(p_request_id,p_data,p_module_ids,p_finalize) $wrapper$;

revoke all on function private.bt_save_training_completion(uuid,jsonb,bigint[],boolean),public.save_training_completion(uuid,jsonb,bigint[],boolean) from public,anon;grant execute on function private.bt_save_training_completion(uuid,jsonb,bigint[],boolean),public.save_training_completion(uuid,jsonb,bigint[],boolean) to authenticated,service_role;


create trigger completion_integrity before insert or update or delete on public.training_completion_records for each row execute function public.enforce_training_completion_integrity();
create trigger completion_finalize after insert or update on public.training_completion_records for each row execute function public.sync_training_request_when_completion_finalized();
create trigger attendance_status after update on public.training_requests for each row execute function public.sync_attendance_session_to_class_status();
create trigger certificate_delete before delete on public.training_attendees for each row execute function public.protect_issued_certificate_attendee_deletion();
create trigger request_delete before delete on public.training_requests for each row execute function public.protect_training_request_deletion();
create trigger completed_modules before insert or update or delete on public.request_modules for each row execute function public.guard_completed_request_modules();
grant execute on function public.auto_close_expired_training_classes(),public.close_training_class(uuid),public.search_training_class_archive(text,date,date,integer) to authenticated;
