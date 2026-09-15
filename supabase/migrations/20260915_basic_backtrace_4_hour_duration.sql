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
  select v_id,m.id from public.training_modules m where m.active=true and m.id = any(coalesce(p_module_ids,array[]::bigint[]));
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

create or replace function public.submit_public_training_request(
  p_token text,
  p_data jsonb,
  p_module_ids bigint[] default '{}'::bigint[]
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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
  v_actor uuid := '4363cbe2-258a-483d-8d94-0a07d760f5f4';
  v_agency_name text := nullif(trim(p_data->>'agency_name'),'');
  v_contact_person text := nullif(trim(p_data->>'contact_person'),'');
  v_contact_email text := lower(nullif(trim(p_data->>'contact_email'),''));
  v_trainer_name text := nullif(trim(p_data->>'trainer_contact_name'),'');
  v_trainer_email text := lower(nullif(trim(p_data->>'trainer_contact_email'),''));
  v_trainer_phone text := nullif(trim(p_data->>'trainer_contact_phone'),'');
  v_requested_by text;
begin
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

  v_requested_by := coalesce(nullif(trim(p_data->>'requested_by'),''),v_contact_person);
  select id into v_agency_id from public.agencies
    where lower(trim(agency_name))=lower(v_agency_name) order by active desc, created_at limit 1;

  if v_agency_id is null then
    insert into public.agencies(agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,active,created_by,updated_by)
    values(v_agency_name,nullif(trim(p_data->>'agency_address'),''),nullif(trim(p_data->>'city_state_zip'),''),v_contact_person,nullif(trim(p_data->>'contact_phone'),''),v_contact_email,true,v_actor,v_actor)
    returning id into v_agency_id;
  else
    update public.agencies set agency_address=coalesce(nullif(trim(p_data->>'agency_address'),''),agency_address),
      city_state_zip=coalesce(nullif(trim(p_data->>'city_state_zip'),''),city_state_zip),
      contact_person=coalesce(v_contact_person,contact_person),contact_phone=coalesce(nullif(trim(p_data->>'contact_phone'),''),contact_phone),
      contact_email=coalesce(v_contact_email,contact_email),active=true,updated_by=v_actor,updated_at=now()
    where id=v_agency_id;
  end if;

  insert into public.training_requests(
    agency_id,agency_name,agency_address,city_state_zip,contact_person,contact_phone,contact_email,
    trainer_contact_name,trainer_contact_email,trainer_contact_phone,preferred_date,alternate_date,
    preferred_start_time,preferred_end_time,time_zone,training_format,estimated_attendees,training_location,
    training_resources,objectives,topics,experience_level,outcomes,additional_requirements,requested_by,status,
    basic_training,train_the_trainer,refresher_course,advanced_training,total_minutes,submission_source,
    public_request_link_id,created_by,updated_by
  ) values(
    v_agency_id,v_agency_name,nullif(trim(p_data->>'agency_address'),''),nullif(trim(p_data->>'city_state_zip'),''),
    v_contact_person,nullif(trim(p_data->>'contact_phone'),''),v_contact_email,v_trainer_name,v_trainer_email,
    v_trainer_phone,nullif(p_data->>'preferred_date','')::date,nullif(p_data->>'alternate_date','')::date,
    nullif(p_data->>'preferred_start_time','')::time,nullif(p_data->>'preferred_end_time','')::time,
    nullif(trim(p_data->>'time_zone'),''),coalesce(nullif(trim(p_data->>'training_format'),''),'In Person'),
    nullif(p_data->>'estimated_attendees','')::integer,nullif(trim(p_data->>'training_location'),''),
    coalesce(array(select jsonb_array_elements_text(coalesce(p_data->'training_resources','[]'::jsonb))),array[]::text[]),
    nullif(trim(p_data->>'objectives'),''),nullif(trim(p_data->>'topics'),''),nullif(trim(p_data->>'experience_level'),''),
    nullif(trim(p_data->>'outcomes'),''),nullif(trim(p_data->>'additional_requirements'),''),v_requested_by,'Received',
    v_basic,v_train_the_trainer,v_refresher,v_advanced,0,'public_request',nullif(l.id,'00000000-0000-0000-0000-000000000000'),v_actor,v_actor
  ) returning id,request_number into v_id,v_number;

  insert into public.request_modules(request_id,module_id)
  select v_id,m.id from public.training_modules m where m.active=true and m.id=any(coalesce(p_module_ids,array[]::bigint[])) on conflict do nothing;

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
