-- Exact-record administrator test-data cleanup. No records are automatically classified as tests.
create table private.training_cleanup_plans (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null,
 roots jsonb not null, records jsonb not null, blockers jsonb not null,
 created_at timestamptz not null default now(), executed_at timestamptz,
 execution_tx bigint, status text not null default 'preview'
);
alter table private.training_cleanup_plans enable row level security;
revoke all on private.training_cleanup_plans from public,anon,authenticated;

create function private.cleanup_catalog() returns table(table_name text,label text)
language sql stable set search_path='' as $$ values
 ('agencies','Agencies'),('agency_portal_links','Agency portal links'),
 ('public_training_request_links','Public request links'),('training_requests','Training requests and classes'),
 ('training_people','Attendee directory'),('training_attendees','Class attendees and certificates'),
 ('training_attendance_sessions','Attendance sessions'),('training_completion_records','Completion records'),
 ('request_modules','Requested modules'),('training_completion_modules','Completion modules'),
 ('training_notifications','Notifications'),('training_email_queue','Email queue'),
 ('training_email_delivery_events','Email delivery events'),('training_certificate_email_deliveries','Certificate email records'),
 ('training_bug_reports','Bug reports'),('training_bug_report_history','Bug report history'),
 ('training_products','Training products'),('training_product_modules','Product modules'),
 ('training_modules','Training modules'),('training_jurisdictions','Jurisdictions'),
 ('training_materials','Training resources'),('training_material_versions','Resource versions'),
 ('training_material_jurisdictions','Resource jurisdictions'),('training_class_materials','Class resource attachments'),
 ('training_material_share_links','Resource share links'),('training_material_share_items','Shared resources'),
 ('training_material_access_events','Resource access events'),('training_material_distributions','Resource delivery records'),
 ('training_signin_ingests','Sign-in imports'),('training_request_activity','Request activity') $$;

create function private.cleanup_key(p_table text,p_row jsonb) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_object_agg(a.attname,p_row->a.attname)
 from pg_catalog.pg_constraint c
 cross join lateral unnest(c.conkey) k(num)
 join pg_catalog.pg_attribute a on a.attrelid=c.conrelid and a.attnum=k.num
 where c.contype='p' and c.conrelid=to_regclass('public.'||quote_ident(p_table)) $$;

create function private.cleanup_label(p_row jsonb) returns text
language sql immutable set search_path='' as $$
 select left(coalesce(p_row->>'request_number',p_row->>'issue_number',p_row->>'completion_number',p_row->>'agency_name',p_row->>'full_name',p_row->>'title',p_row->>'subject',p_row->>'name',p_row->>'module_name',p_row->>'label',p_row->>'original_filename',p_row->>'id',p_row->>'request_id','Linked record') || coalesce(' — '||coalesce(p_row->>'summary',p_row->>'recipient_email',p_row->>'email'),''),240) $$;

-- All FK edges, including composite keys, for the current application schema.
create function private.cleanup_edges() returns table(child text,parent text,join_sql text,cascade_delete boolean)
language sql stable set search_path='' as $$
 select cc.relname::text,pc.relname::text,
 string_agg(format('to_jsonb(c)->%L = p.row_data->%L',ca.attname,pa.attname),' and ' order by k.ord),f.confdeltype='c'
 from pg_catalog.pg_constraint f
 join pg_catalog.pg_class cc on cc.oid=f.conrelid
 join pg_catalog.pg_class pc on pc.oid=f.confrelid
 cross join lateral unnest(f.conkey,f.confkey) with ordinality k(cnum,pnum,ord)
 join pg_catalog.pg_attribute ca on ca.attrelid=cc.oid and ca.attnum=k.cnum
 join pg_catalog.pg_attribute pa on pa.attrelid=pc.oid and pa.attnum=k.pnum
 where f.contype='f' and cc.relnamespace='public'::regnamespace and pc.relnamespace='public'::regnamespace
 group by f.oid,cc.relname,pc.relname,f.confdeltype $$;

create function private.build_cleanup_plan(p_roots jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare root_item jsonb;e record;n integer;added integer;v_blockers jsonb:='[]';v_bad jsonb;v_records jsonb;
begin
 if auth.uid() is null or public.current_user_role() is distinct from 'admin' then raise exception 'Active administrator access required.';end if;
 if jsonb_typeof(p_roots) is distinct from 'array' or jsonb_array_length(p_roots) not between 1 and 100 then raise exception 'Select between 1 and 100 exact test records.';end if;
 -- Drop caller-created temporary objects before using privileged code.
 drop table if exists pg_temp.bt_cleanup_rows;
 create temporary table bt_cleanup_rows(table_name text not null,key jsonb not null,row_data jsonb not null,primary key(table_name,key)) on commit drop;
 for root_item in select value from jsonb_array_elements(p_roots) loop
 if not exists(select 1 from private.cleanup_catalog() x where x.table_name=root_item->>'table') then raise exception 'Unsupported cleanup category.';end if;
 execute format('insert into pg_temp.bt_cleanup_rows select %L,private.cleanup_key(%L,to_jsonb(c)),to_jsonb(c) from public.%I c where private.cleanup_key(%L,to_jsonb(c))=$1 on conflict do nothing',root_item->>'table',root_item->>'table',root_item->>'table',root_item->>'table') using root_item->'key';
 get diagnostics n=row_count;if n=0 and not exists(select 1 from pg_temp.bt_cleanup_rows where table_name=root_item->>'table' and key=root_item->'key') then raise exception 'A selected record no longer exists. Search again.';end if;
 end loop;
 loop
 added:=0;
 for e in select * from private.cleanup_edges() where cascade_delete or (child='training_email_delivery_events' and parent='training_email_queue') loop
 if exists(select 1 from private.cleanup_catalog() x where x.table_name=e.child) then
 execute format('insert into pg_temp.bt_cleanup_rows select %L,private.cleanup_key(%L,to_jsonb(c)),to_jsonb(c) from public.%I c join pg_temp.bt_cleanup_rows p on p.table_name=%L and %s on conflict do nothing',e.child,e.child,e.child,e.parent,e.join_sql);
 get diagnostics n=row_count;added:=added+n;
 end if;
 end loop;
 -- Certificate/material emails are linked without notification_id. Include their exact queues.
 insert into pg_temp.bt_cleanup_rows
 select 'training_email_queue',jsonb_build_object('id',q.id),to_jsonb(q)
 from public.training_email_queue q join pg_temp.bt_cleanup_rows p on
 (p.table_name='training_certificate_email_deliveries' and (p.row_data->>'queue_id')::bigint=q.id)
 or (p.table_name='training_material_distributions' and (p.row_data->>'email_queue_id')::bigint=q.id)
 on conflict do nothing;
 get diagnostics n=row_count;added:=added+n;
 if (select count(*) from pg_temp.bt_cleanup_rows)>5000 then raise exception 'Cleanup exceeds 5,000 records. Use smaller batches.';end if;
 exit when added=0;
 end loop;
 -- Never null, cascade or alter a linked row outside the reviewed plan.
 for e in select * from private.cleanup_edges() loop
 execute format('select coalesce(jsonb_agg(distinct jsonb_build_object(''table'',%L,''key'',private.cleanup_key(%L,to_jsonb(c)),''label'',private.cleanup_label(to_jsonb(c)))),''[]''::jsonb) from public.%I c join pg_temp.bt_cleanup_rows p on p.table_name=%L and %s where not exists(select 1 from pg_temp.bt_cleanup_rows s where s.table_name=%L and s.key=private.cleanup_key(%L,to_jsonb(c)))',e.child,e.child,e.child,e.parent,e.join_sql,e.child,e.child) into v_bad;
 v_blockers:=v_blockers||v_bad;
 end loop;
 -- A module attachment must not cause an unreviewed class update.
 select coalesce(jsonb_agg(jsonb_build_object('table','training_requests','key',jsonb_build_object('id',r.id),'label',private.cleanup_label(to_jsonb(r)))),'[]') into v_bad
 from public.training_requests r where exists(select 1 from pg_temp.bt_cleanup_rows p where p.table_name='request_modules' and p.row_data->>'request_id'=r.id::text)
 and not exists(select 1 from pg_temp.bt_cleanup_rows p where p.table_name='training_requests' and p.key=jsonb_build_object('id',r.id));
 v_blockers:=v_blockers||v_bad;
 select jsonb_agg(jsonb_build_object('table',table_name,'key',key,'row',row_data) order by table_name,key::text) into v_records from pg_temp.bt_cleanup_rows;
 return jsonb_build_object('records',v_records,'blockers',v_blockers);
end $$;

create function private.cleanup_row_authorized(p_table text,p_row jsonb) returns boolean
language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and public.current_user_role()='admin' and exists(
 select 1 from private.training_cleanup_plans p cross join lateral jsonb_array_elements(p.records) r
 where p.id::text=current_setting('app.test_cleanup_plan',true) and p.actor_id=auth.uid()
 and p.status='executing' and p.execution_tx=txid_current() and root_item->>'table'=p_table
 and root_item->'key'=private.cleanup_key(p_table,p_row)) $$;

create function public.get_test_cleanup_catalog() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or public.current_user_role() is distinct from 'admin' then raise exception 'Active administrator access required.';end if;
 select jsonb_agg(jsonb_build_object('table',table_name,'label',label) order by label) into result from private.cleanup_catalog();return result;end $$;

create function public.search_test_cleanup_records(p_table text,p_search text default '',p_offset integer default 0) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;begin
 if auth.uid() is null or public.current_user_role() is distinct from 'admin' then raise exception 'Active administrator access required.';end if;
 if not exists(select 1 from private.cleanup_catalog() x where x.table_name=p_table) then raise exception 'Unsupported cleanup category.';end if;
 if length(coalesce(p_search,''))>200 or p_offset<0 or p_offset>100000 then raise exception 'Invalid search.';end if;
 execute format('select coalesce(jsonb_agg(x),''[]'') from (select jsonb_build_object(''table'',%L,''key'',private.cleanup_key(%L,to_jsonb(c)),''label'',private.cleanup_label(to_jsonb(c)),''created'',coalesce(to_jsonb(c)->>''created_at'',to_jsonb(c)->>''registered_at'',to_jsonb(c)->>''requested_at'')) x from public.%I c where $1='''' or position(lower($1) in lower(to_jsonb(c)::text))>0 order by private.cleanup_key(%L,to_jsonb(c))::text limit 50 offset $2) q',p_table,p_table,p_table,p_table) into result using coalesce(p_search,''),p_offset;return result;end $$;

create function public.preview_test_cleanup(p_roots jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare v jsonb;p uuid;v_rows jsonb;begin
 v:=private.build_cleanup_plan(p_roots);
 insert into private.training_cleanup_plans(actor_id,roots,records,blockers) values(auth.uid(),p_roots,v->'records',v->'blockers') returning id into p;
 select jsonb_agg(jsonb_build_object('table',r->>'table','key',r->'key','label',private.cleanup_label(r->'row')) order by r->>'table',r->'key'::text) into v_rows from jsonb_array_elements(v->'records') r;
 return jsonb_build_object('id',p,'records',v_rows,'blockers',v->'blockers','count',jsonb_array_length(v_rows),'expires_at',now()+interval '15 minutes');end $$;

create function public.delete_test_cleanup(p_plan_id uuid,p_confirmation text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p private.training_cleanup_plans%rowtype;v jsonb;r record;v_remaining jsonb;v_order text[]:='{}';v_table text;v_progress boolean;v_count integer:=0;n integer;
begin
 if auth.uid() is null or public.current_user_role() is distinct from 'admin' then raise exception 'Active administrator access required.';end if;
 select * into p from private.training_cleanup_plans where id=p_plan_id for update;
 if p.id is null or p.actor_id<>auth.uid() or p.status<>'preview' or p.created_at<now()-interval '15 minutes' then raise exception 'Preview expired or unavailable. Preview again.';end if;
 if p_confirmation is distinct from 'DELETE '||jsonb_array_length(p.records)::text||' TEST RECORDS' then raise exception 'Type the exact confirmation shown in the preview.';end if;
 -- Lock all application record tables so reviewed rows and dependencies cannot change mid-delete.
 for r in select table_name from private.cleanup_catalog() order by table_name loop execute format('lock table public.%I in share row exclusive mode nowait',r.table_name);end loop;
 v:=private.build_cleanup_plan(p.roots);
 if v->'records' is distinct from p.records or v->'blockers' is distinct from '[]'::jsonb then raise exception 'Records or linked data changed, or shared records remain. Preview again.';end if;
 -- Compute child-first deletion order; fail closed on future FK cycles.
 select array_agg(distinct x->>'table') into v_order from jsonb_array_elements(p.records) x;
 v_remaining:=to_jsonb(v_order);v_order:='{}';
 while jsonb_array_length(v_remaining)>0 loop
 v_progress:=false;
 for v_table in select jsonb_array_elements_text(v_remaining) loop
 if not exists(select 1 from private.cleanup_edges() e where e.parent=v_table and e.child<>v_table and v_remaining ? e.child) then
 v_order:=array_append(v_order,v_table);v_remaining:=v_remaining-v_table;v_progress:=true;
 end if;end loop;
 if not v_progress then raise exception 'Linked-record cycle requires administrator review.';end if;
 end loop;
 update private.training_cleanup_plans set status='executing',execution_tx=txid_current() where id=p.id;
 perform set_config('app.test_cleanup_plan',p.id::text,true);
 foreach v_table in array v_order loop
 execute format('delete from public.%I c using pg_temp.bt_cleanup_rows p where p.table_name=%L and private.cleanup_key(%L,to_jsonb(c))=p.key',v_table,v_table,v_table);
 get diagnostics n=row_count;v_count:=v_count+n;
 end loop;
 if v_count<>jsonb_array_length(p.records) then raise exception 'Deletion count changed; cleanup rolled back.';end if;
 update private.training_cleanup_plans set status='deleted',executed_at=now(),execution_tx=null where id=p.id;
 perform set_config('app.test_cleanup_plan','',true);
 insert into public.administration_activity(actor_id,category,action,entity_type,entity_id,subject,details)
 values(auth.uid(),'Administration','test_data_deleted','test_cleanup',p.id::text,'Reviewed test-data cleanup',jsonb_build_object('record_count',v_count,'selected_roots',p.roots));
 return jsonb_build_object('deleted',v_count,'cleanup_id',p.id);
end $$;

revoke all on function private.cleanup_catalog(),private.cleanup_key(text,jsonb),private.cleanup_label(jsonb),private.cleanup_edges(),private.build_cleanup_plan(jsonb),private.cleanup_row_authorized(text,jsonb) from public,anon,authenticated;
revoke all on function public.get_test_cleanup_catalog(),public.search_test_cleanup_records(text,text,integer),public.preview_test_cleanup(jsonb),public.delete_test_cleanup(uuid,text) from public,anon;
grant execute on function public.get_test_cleanup_catalog(),public.search_test_cleanup_records(text,text,integer),public.preview_test_cleanup(jsonb),public.delete_test_cleanup(uuid,text) to authenticated;
CREATE OR REPLACE FUNCTION public.enforce_training_completion_integrity()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare
  v_class_status text;
  v_elapsed_minutes integer;
begin
  if tg_op='DELETE' and private.cleanup_row_authorized(TG_TABLE_NAME,to_jsonb(old)) then return old; end if;
  if tg_op = 'DELETE' then
    if old.record_status = 'Finalized'
       and not (
         private.demo_cleanup_authorized()
         and old.completion_number in ('BTC-2026-0001', 'BTC-2026-0002')
       ) then
      raise exception 'Finalized completion records cannot be deleted.';
    end if;
    return old;
  end if;

  if tg_op = 'UPDATE' and old.record_status = 'Finalized' then
    if to_jsonb(new) is distinct from to_jsonb(old) then
      raise exception 'Finalized completion records are locked and cannot be edited.';
    end if;
    return new;
  end if;

  if new.record_status = 'Finalized' then
    select class_status into v_class_status
      from public.training_requests where id = new.request_id;

    if v_class_status is null then raise exception 'Training request not found.'; end if;
    if v_class_status not in ('Closed','Completed') then
      raise exception 'Close the class in Attendance before finalizing Completion.';
    end if;
    if new.actual_training_date is null then raise exception 'Actual training date is required before finalizing.'; end if;
    if new.actual_attendees is null then raise exception 'Actual attendance is required before finalizing.'; end if;
    if new.actual_minutes is null or new.actual_minutes <= 0 then
      raise exception 'Actual training duration must be greater than zero before finalizing.';
    end if;
    if (new.actual_start_time is null) <> (new.actual_end_time is null) then
      raise exception 'Actual start and end times must either both be entered or both be left blank.';
    end if;
    if new.actual_start_time is not null and new.actual_end_time is not null then
      v_elapsed_minutes := (((extract(epoch from (new.actual_end_time-new.actual_start_time))/60)::integer + 1440) % 1440);
      if v_elapsed_minutes <= 0 then
        raise exception 'Actual start and end times must define a positive training duration.';
      end if;
      if new.actual_minutes <> v_elapsed_minutes then
        raise exception 'Actual training duration must match the entered start and end times.';
      end if;
    end if;
  end if;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.sync_request_module_total_minutes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE' and private.cleanup_row_authorized(TG_TABLE_NAME,to_jsonb(old)) then return old; end if;
  if tg_op = 'DELETE' then
    perform public.recalculate_training_request_total_minutes(old.request_id);
    return old;
  elsif tg_op = 'UPDATE' then
    if old.request_id is distinct from new.request_id then
      perform public.recalculate_training_request_total_minutes(old.request_id);
    end if;
    perform public.recalculate_training_request_total_minutes(new.request_id);
    return new;
  else
    perform public.recalculate_training_request_total_minutes(new.request_id);
    return new;
  end if;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.guard_completed_request_modules()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_request_id uuid;
  v_status text;
  v_class_status text;
begin
  if tg_op='DELETE' and private.cleanup_row_authorized(TG_TABLE_NAME,to_jsonb(old)) then return old; end if;
  v_request_id := case when tg_op='DELETE' then old.request_id else new.request_id end;
  select status,class_status into v_status,v_class_status from public.training_requests where id=v_request_id;
  if v_status='Completed' or v_class_status in ('Completed','Archived') then
    raise exception 'Training module selections are locked after the class is completed.';
  end if;
  return case when tg_op='DELETE' then old else new end;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.protect_training_request_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'private'
AS $function$
declare
  v_role text;
begin
  if tg_op='DELETE' and private.cleanup_row_authorized(TG_TABLE_NAME,to_jsonb(old)) then return old; end if;
  v_role := public.current_user_role();

  if current_user = 'authenticated' and v_role not in ('admin','coordinator') then
    raise exception 'Administrator or coordinator access is required to delete a training request.';
  end if;

  if not (
    private.demo_cleanup_authorized()
    and old.request_number in ('BT-2026-0001', 'BT-2026-0003')
  ) and (
    old.class_status in ('Registration Open','In Progress','Closed','Completed','Archived')
    or old.class_started_at is not null
    or old.class_closed_at is not null
    or old.completed_at is not null
    or exists (select 1 from public.training_attendance_sessions s where s.request_id=old.id)
    or exists (select 1 from public.training_attendees a where a.request_id=old.id)
    or exists (select 1 from public.training_completion_records c where c.request_id=old.id)
  ) then
    raise exception 'This training request has operational or historical records and cannot be deleted. Preserve it in Training History instead.';
  end if;

  insert into public.administration_activity(actor_id, category, action, entity_type, entity_id, subject, details)
  values (auth.uid(), 'Requests', 'training_request_deleted', 'training_request', old.id::text,
    coalesce(old.request_number || ' — ' || old.agency_name, old.request_number, old.agency_name, 'Training Request'),
    jsonb_build_object('request_number', old.request_number, 'agency_name', old.agency_name,
      'status', old.status, 'class_status', old.class_status,
      'submission_source', old.submission_source, 'created_at', old.created_at));
  return old;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.enforce_training_request_module_completeness_from_module()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE' and private.cleanup_row_authorized(TG_TABLE_NAME,to_jsonb(old)) then return old; end if;
  if tg_op='DELETE' then
    perform public.check_training_request_module_completeness(old.request_id);
    return old;
  end if;
  if tg_op='UPDATE' and old.request_id is distinct from new.request_id then
    perform public.check_training_request_module_completeness(old.request_id);
  end if;
  perform public.check_training_request_module_completeness(new.request_id);
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.protect_issued_certificate_attendee_deletion()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if tg_op='DELETE' and private.cleanup_row_authorized(TG_TABLE_NAME,to_jsonb(old)) then return old; end if;
  if old.certificate_public_id is not null
     or old.certificate_number is not null
     or old.certificate_issued_at is not null then
    raise exception 'Certified attendee records are permanent and cannot be deleted.';
  end if;
  return old;
end;
$function$
;

