-- Final Production UAT: keep attendance session close timestamps valid in every close path.
-- A class may be manually closed before its configured check-in window opens.
-- Clamp checkin_close_at so it can never precede checkin_open_at.

create or replace function public.close_training_class(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  r public.training_requests%rowtype;
  s public.training_attendance_sessions%rowtype;
  v_registered bigint;
  v_checked bigint;
  v_completed bigint;
begin
  if not public.can_edit_request(p_request_id) then raise exception 'You do not have permission to close this class.'; end if;
  select * into r from public.training_requests where id=p_request_id for update;
  if r.id is null then raise exception 'Training request not found.'; end if;
  if r.class_status='Archived' then raise exception 'Archived classes cannot be changed.'; end if;
  if r.class_status='Completed' then return jsonb_build_object('request_id',r.id,'class_status','Completed','already_closed',true); end if;
  select * into s from public.training_attendance_sessions where request_id=r.id;
  if s.id is null then raise exception 'Generate the class before closing it.'; end if;
  select count(*),count(*) filter(where checked_in_at is not null),count(*) filter(where attendance_status='completed')
    into v_registered,v_checked,v_completed from public.training_attendees where request_id=r.id;
  update public.training_attendance_sessions
     set active=false,
         registration_open=false,
         checkin_close_at=case
           when checkin_open_at is null then least(coalesce(checkin_close_at,now()),now())
           else greatest(checkin_open_at,least(coalesce(checkin_close_at,now()),now()))
         end,
         updated_at=now()
   where request_id=r.id;
  update public.training_requests
     set class_status='Closed',class_closed_at=coalesce(class_closed_at,now()),class_closed_by=coalesce(class_closed_by,auth.uid()),updated_at=now(),updated_by=auth.uid()
   where id=r.id;
  insert into public.training_request_activity(request_id,actor_id,action,details)
  values(r.id,auth.uid(),'class_closed',jsonb_build_object('previous_status',r.class_status,'registered',v_registered,'checked_in',v_checked,'certificates',v_completed));
  insert into public.administration_activity(actor_id,category,action,entity_type,entity_id,subject,details)
  values(auth.uid(),'Attendance','class_closed','training_request',r.id::text,r.request_number||' — '||r.agency_name,jsonb_build_object('previous_status',r.class_status,'registered',v_registered,'checked_in',v_checked,'certificates',v_completed));
  return jsonb_build_object('request_id',r.id,'class_status','Closed','registered',v_registered,'checked_in',v_checked,'certificates',v_completed,'completion_url','https://backtrace-training-tracker.vercel.app/completion');
end
$function$;

create or replace function public.sync_attendance_session_to_class_status()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.class_status is distinct from old.class_status then
    if new.class_status = 'In Progress' then
      update public.training_attendance_sessions
         set registration_open=false,updated_at=now()
       where request_id=new.id and registration_open=true;
    elsif new.class_status in ('Closed','Completed','Archived') then
      update public.training_attendance_sessions
         set active=false,
             registration_open=false,
             checkin_close_at=case
               when checkin_open_at is null then least(coalesce(checkin_close_at,now()),now())
               else greatest(checkin_open_at,least(coalesce(checkin_close_at,now()),now()))
             end,
             updated_at=now()
       where request_id=new.id
         and (active=true or registration_open=true or checkin_close_at is null or checkin_close_at>now());
    end if;
  end if;
  return new;
end;
$function$;

create or replace function public.sync_training_request_when_completion_finalized()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if new.record_status='Finalized' and (tg_op='INSERT' or old.record_status is distinct from 'Finalized') then
    update public.training_requests
       set status='Completed',completed_at=coalesce(completed_at,now()),class_status='Completed',class_closed_at=coalesce(class_closed_at,now()),class_closed_by=coalesce(class_closed_by,auth.uid()),updated_at=now(),updated_by=coalesce(auth.uid(),updated_by)
     where id=new.request_id;
    update public.training_attendance_sessions
       set active=false,
           registration_open=false,
           checkin_close_at=case
             when checkin_open_at is null then least(coalesce(checkin_close_at,now()),now())
             else greatest(checkin_open_at,least(coalesce(checkin_close_at,now()),now()))
           end,
           updated_at=now()
     where request_id=new.request_id;
  end if;
  return new;
end;
$function$;

create or replace function public.auto_close_expired_training_classes()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  r public.training_requests%rowtype;
  v_tz text;
  v_local_date date;
  v_registered bigint;
  v_checked bigint;
  v_completed bigint;
  v_closed integer:=0;
  v_ids uuid[]:='{}';
  v_system boolean:=auth.uid() is null;
begin
  for r in
    select tr.* from public.training_requests tr
    where tr.confirmed_date is not null
      and tr.class_status not in ('Closed','Completed','Archived')
      and (v_system or public.can_edit_request(tr.id))
    order by tr.confirmed_date,tr.id for update
  loop
    v_tz:=case lower(coalesce(nullif(trim(r.time_zone),''),'eastern'))
      when 'eastern' then 'America/New_York' when 'et' then 'America/New_York' when 'est' then 'America/New_York' when 'edt' then 'America/New_York'
      when 'central' then 'America/Chicago' when 'ct' then 'America/Chicago' when 'cst' then 'America/Chicago' when 'cdt' then 'America/Chicago'
      when 'mountain' then 'America/Denver' when 'mt' then 'America/Denver' when 'mst' then 'America/Denver' when 'mdt' then 'America/Denver'
      when 'pacific' then 'America/Los_Angeles' when 'pt' then 'America/Los_Angeles' when 'pst' then 'America/Los_Angeles' when 'pdt' then 'America/Los_Angeles'
      else case when exists(select 1 from pg_timezone_names z where z.name=r.time_zone) then r.time_zone else 'America/New_York' end
    end;
    v_local_date:=(now() at time zone v_tz)::date;
    if r.confirmed_date<v_local_date then
      select count(*),count(*) filter(where checked_in_at is not null),count(*) filter(where attendance_status='completed')
        into v_registered,v_checked,v_completed from public.training_attendees where request_id=r.id;
      update public.training_attendance_sessions
         set active=false,
             registration_open=false,
             checkin_close_at=case
               when checkin_open_at is null then least(coalesce(checkin_close_at,now()),now())
               else greatest(checkin_open_at,least(coalesce(checkin_close_at,now()),now()))
             end,
             updated_at=now()
       where request_id=r.id;
      update public.training_requests
         set class_status='Closed',class_closed_at=coalesce(class_closed_at,now()),class_closed_by=coalesce(class_closed_by,auth.uid()),updated_at=now(),updated_by=coalesce(auth.uid(),updated_by)
       where id=r.id;
      insert into public.training_request_activity(request_id,actor_id,action,details)
      values(r.id,auth.uid(),'class_auto_closed',jsonb_build_object('previous_status',r.class_status,'reason','training_date_passed','closure_source',case when v_system then 'system_scheduler' else 'attendance_load' end,'confirmed_date',r.confirmed_date,'time_zone',v_tz,'registered',v_registered,'checked_in',v_checked,'certificates',v_completed));
      insert into public.administration_activity(actor_id,category,action,entity_type,entity_id,subject,details)
      values(auth.uid(),'Attendance','class_auto_closed','training_request',r.id::text,r.request_number||' — '||r.agency_name,jsonb_build_object('previous_status',r.class_status,'reason','training_date_passed','closure_source',case when v_system then 'system_scheduler' else 'attendance_load' end,'confirmed_date',r.confirmed_date,'time_zone',v_tz,'registered',v_registered,'checked_in',v_checked,'certificates',v_completed));
      v_closed:=v_closed+1;
      v_ids:=array_append(v_ids,r.id);
    end if;
  end loop;
  return jsonb_build_object('closed_count',v_closed,'request_ids',to_jsonb(v_ids),'source',case when v_system then 'system_scheduler' else 'attendance_user' end);
end
$function$;
