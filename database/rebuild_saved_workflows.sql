-- Saved workflows restored to the reconstructed baseline. See source markers.

-- SOURCE: database/bug_tracker_workflow.sql
create sequence public.training_bug_ticket_sequence;
alter table public.training_bug_reports
 add column issue_number text not null default ('BT-BUG-'||lpad(nextval('public.training_bug_ticket_sequence')::text,6,'0')) unique,
 add column priority text not null default 'Normal' check(priority in ('Low','Normal','High','Critical')),
 add column assigned_to uuid references public.profiles(id) on delete set null,
 add column resolution_summary text check(resolution_summary is null or length(resolution_summary)<=2000);
grant usage on sequence public.training_bug_ticket_sequence to anon,authenticated;

create table public.training_bug_report_history(
 id uuid primary key default gen_random_uuid(),
 bug_report_id uuid not null references public.training_bug_reports(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 action text not null,
 changes jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index training_bug_report_history_report_idx on public.training_bug_report_history(bug_report_id,created_at);
alter table public.training_bug_report_history enable row level security;
grant select on public.training_bug_report_history to authenticated;
create policy bug_history_admin_select on public.training_bug_report_history for select to authenticated
using(exists(select 1 from public.profiles where id=(select auth.uid()) and active and role='admin'));

create or replace function public.prepare_training_bug_report()
returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op='INSERT' then
 new.status:='Open';new.priority:='Normal';new.assigned_to:=null;new.admin_notes:=null;
 new.resolution_summary:=null;new.resolved_at:=null;new.resolved_by:=null;
 new.issue_number:='BT-BUG-'||lpad(nextval('public.training_bug_ticket_sequence')::text,6,'0');
 new.created_at:=now();new.updated_at:=now();
 else
 if (to_jsonb(new)-array['status','priority','assigned_to','admin_notes','resolution_summary','updated_at','resolved_at','resolved_by'])
 is distinct from (to_jsonb(old)-array['status','priority','assigned_to','admin_notes','resolution_summary','updated_at','resolved_at','resolved_by']) then
 raise exception 'Submitted report details and ticket number cannot be changed.';end if;
 if new.assigned_to is not null and not exists(select 1 from public.profiles where id=new.assigned_to and active and role in ('admin','coordinator')) then
 raise exception 'Choose an active administrator or coordinator as the issue owner.';end if;
 if new.status in ('Resolved','Closed') then
 if nullif(btrim(new.resolution_summary),'') is null then raise exception 'A resolution summary is required to resolve or close an issue.';end if;
 new.resolved_at:=coalesce(old.resolved_at,now());new.resolved_by:=coalesce(old.resolved_by,auth.uid());
 else new.resolved_at:=null;new.resolved_by:=null;end if;
 new.updated_at:=clock_timestamp();
 end if;
 return new;
end $$;
create trigger prepare_training_bug_report before insert or update on public.training_bug_reports
for each row execute function public.prepare_training_bug_report();

create or replace function public.audit_training_bug_report()
returns trigger language plpgsql security definer set search_path = '' as $$
declare delta jsonb:='{}'::jsonb;k text;
begin
 if tg_op='INSERT' then delta:=jsonb_build_object('status',jsonb_build_object('after',new.status));
 else
 foreach k in array array['status','priority','assigned_to','admin_notes','resolution_summary'] loop
 if to_jsonb(new)->k is distinct from to_jsonb(old)->k then
 delta:=delta||jsonb_build_object(k,jsonb_build_object('before',to_jsonb(old)->k,'after',to_jsonb(new)->k));
 end if;end loop;
 end if;
 if tg_op='INSERT' or delta<>'{}'::jsonb then
 insert into public.training_bug_report_history(bug_report_id,actor_id,action,changes)
 values(new.id,auth.uid(),case when tg_op='INSERT' then 'Submitted' else 'Updated' end,delta);
 end if;
 return new;
end $$;
create trigger audit_training_bug_report after insert or update on public.training_bug_reports
for each row execute function public.audit_training_bug_report();

create or replace function public.submit_training_bug_report(p_data jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v public.training_bug_reports%rowtype;v_version text;v_page text:=nullif(btrim(p_data->>'page_url'),'');
begin
 if auth.uid() is not null and not exists(select 1 from public.profiles where id=auth.uid() and active) then
 raise exception 'An active account is required.';end if;
 if v_page is not null and v_page !~ '^https://[a-zA-Z0-9.-]+(/[[:graph:]]*)?$' then raise exception 'Invalid reported page URL.';end if;
 select version into v_version from public.training_app_versions where is_current order by release_date desc limit 1;
 insert into public.training_bug_reports(source,component,summary,details,expected_behavior,contact_name,contact_email,reporter_user_id,page_url,user_agent,app_version)
 values(case when auth.uid() is null then 'request_form' else 'tracker' end,
 coalesce(nullif(btrim(p_data->>'component'),''),'Application problem'),btrim(p_data->>'summary'),btrim(p_data->>'details'),
 nullif(btrim(p_data->>'expected_behavior'),''),nullif(btrim(p_data->>'contact_name'),''),nullif(lower(btrim(p_data->>'contact_email')),''),
 auth.uid(),v_page,nullif(p_data->>'user_agent',''),v_version)
 returning * into v;
 return jsonb_build_object('id',v.id,'issue_number',v.issue_number,'status',v.status,'created_at',v.created_at);
end $$;
revoke all on function public.submit_training_bug_report(jsonb) from public;
grant execute on function public.submit_training_bug_report(jsonb) to anon,authenticated;

create or replace function public.get_my_training_bug_reports()
returns table(id uuid,issue_number text,summary text,status text,priority text,resolution_summary text,created_at timestamptz,updated_at timestamptz,resolved_at timestamptz)
language sql security definer set search_path = '' as $$
 select r.id,r.issue_number,r.summary,r.status,r.priority,r.resolution_summary,r.created_at,r.updated_at,r.resolved_at
 from public.training_bug_reports r where auth.uid() is not null and r.reporter_user_id=auth.uid()
 and exists(select 1 from public.profiles where id=auth.uid() and active)
 order by r.created_at desc;
$$;
revoke all on function public.get_my_training_bug_reports() from public,anon;
grant execute on function public.get_my_training_bug_reports() to authenticated;

create or replace function public.update_training_bug_report(p_id uuid,p_status text,p_priority text,p_assigned_to uuid,p_admin_notes text,p_resolution_summary text,p_expected_updated_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.training_bug_reports%rowtype;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active and role='admin') then
 raise exception 'Administrator access is required.';end if;
 select * into r from public.training_bug_reports where id=p_id for update;
 if not found then raise exception 'Bug report not found.';end if;
 if p_expected_updated_at is null or r.updated_at is distinct from p_expected_updated_at then
 raise exception 'This report changed since it was opened. Refresh before saving.';end if;
 update public.training_bug_reports set status=p_status,priority=p_priority,assigned_to=p_assigned_to,
 admin_notes=nullif(btrim(p_admin_notes),''),resolution_summary=nullif(btrim(p_resolution_summary),'') where id=p_id
 returning * into r;
 return jsonb_build_object('id',r.id,'issue_number',r.issue_number,'status',r.status,'updated_at',r.updated_at);
end $$;
revoke all on function public.update_training_bug_report(uuid,text,text,uuid,text,text,timestamptz) from public,anon;
grant execute on function public.update_training_bug_report(uuid,text,text,uuid,text,text,timestamptz) to authenticated;
revoke all on function public.prepare_training_bug_report() from public,anon,authenticated;
revoke all on function public.audit_training_bug_report() from public,anon,authenticated;


;

-- SOURCE: database/reviewed_test_data_cleanup.sql
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
 and p.status='executing' and p.execution_tx=txid_current() and r->>'table'=p_table
 and r->'key'=private.cleanup_key(p_table,p_row)) $$;

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
         false
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
    false
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



;

-- SOURCE: database/agency_business_rules.sql
-- Shared agencies are reused by requests, portals, and the Resource Library.
alter table public.agencies add column if not exists agency_city text;
alter table public.agencies add column if not exists agency_state text;
alter table public.agencies add column if not exists agency_zip text;

-- Legacy Agency Directory edits use a combined location. Clear stale structured
-- fields when that location alone changes, so both screens show the same address.
create function public.sync_agency_registry_location() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 if new.city_state_zip is distinct from old.city_state_zip
 and new.agency_city is not distinct from old.agency_city
 and new.agency_state is not distinct from old.agency_state
 and new.agency_zip is not distinct from old.agency_zip then
  new.agency_city:=null;new.agency_state:=null;new.agency_zip:=null;
 end if;
 return new;
end $$;
revoke all on function public.sync_agency_registry_location() from public,anon,authenticated;
create trigger agencies_registry_location before update on public.agencies for each row execute function public.sync_agency_registry_location();

create table public.resource_items (
 id uuid primary key default gen_random_uuid(),
 name text not null check (length(btrim(name)) between 1 and 160),
 item_type text not null check (item_type in ('Tool','Dashboard','Smart Tool','Misc.')),
 description text not null check (length(btrim(description)) between 1 and 4000),
 expected_outcome text not null default '' check (length(expected_outcome)<=2000),
 created_by uuid not null default auth.uid() references public.profiles(id),
 updated_by uuid not null default auth.uid() references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create unique index resource_items_name_type_uidx on public.resource_items(lower(regexp_replace(btrim(name),'\s+',' ','g')),item_type);
create index resource_items_created_by_idx on public.resource_items(created_by);
create index resource_items_updated_by_idx on public.resource_items(updated_by);

create table public.agency_item_assignments (
 id uuid primary key default gen_random_uuid(),
 agency_id uuid not null references public.agencies(id) on delete cascade,
 item_id uuid not null references public.resource_items(id) on delete cascade,
 data_source text not null check (length(btrim(data_source)) between 1 and 250),
 retention_value integer not null check (retention_value between 1 and 9999),
 retention_unit text not null check (retention_unit in ('Days','Months','Years')),
 created_by uuid not null default auth.uid() references public.profiles(id),
 updated_by uuid not null default auth.uid() references public.profiles(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(agency_id,item_id)
);
create index agency_item_assignments_item_idx on public.agency_item_assignments(item_id);
create index agency_item_assignments_created_by_idx on public.agency_item_assignments(created_by);
create index agency_item_assignments_updated_by_idx on public.agency_item_assignments(updated_by);

-- Invoker triggers maintain modification metadata and protect creation attribution.
create function public.touch_resource_registry() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 new.created_by:=old.created_by; new.created_at:=old.created_at;
 new.updated_at:=clock_timestamp(); new.updated_by:=coalesce(auth.uid(),old.updated_by);
 return new;
end $$;
revoke all on function public.touch_resource_registry() from public,anon,authenticated;
create trigger resource_items_touch before update on public.resource_items for each row execute function public.touch_resource_registry();
create trigger agency_item_assignments_touch before update on public.agency_item_assignments for each row execute function public.touch_resource_registry();

alter table public.resource_items enable row level security;
alter table public.agency_item_assignments enable row level security;
revoke all on public.resource_items,public.agency_item_assignments from anon,authenticated;
grant select,insert,update on public.resource_items,public.agency_item_assignments to authenticated;
grant all on public.resource_items,public.agency_item_assignments to service_role;
create policy resource_items_read on public.resource_items for select to authenticated using ((select public.current_user_role()) in ('admin','coordinator','trainer','viewer'));
create policy resource_items_insert on public.resource_items for insert to authenticated with check ((select public.current_user_role()) in ('admin','coordinator') and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy resource_items_update on public.resource_items for update to authenticated using ((select public.current_user_role()) in ('admin','coordinator')) with check ((select public.current_user_role()) in ('admin','coordinator') and updated_by=(select auth.uid()));
create policy agency_item_assignments_read on public.agency_item_assignments for select to authenticated using ((select public.current_user_role()) in ('admin','coordinator','trainer','viewer'));
create policy agency_item_assignments_insert on public.agency_item_assignments for insert to authenticated with check ((select public.current_user_role()) in ('admin','coordinator') and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy agency_item_assignments_update on public.agency_item_assignments for update to authenticated using ((select public.current_user_role()) in ('admin','coordinator')) with check ((select public.current_user_role()) in ('admin','coordinator') and updated_by=(select auth.uid()));

-- Preserve the existing exact-record review and deletion safeguards.
create or replace function private.cleanup_catalog() returns table(table_name text,label text)
language sql stable set search_path='' as $$ values
 ('resource_items','Resource item catalog'),('agency_item_assignments','Agency item assignments'),
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

;

-- SOURCE: database/separate_business_rules_agencies.sql
-- Dedicated in-house registry. No foreign key, synchronization, or public lookup links to training agencies.
lock table public.agencies,public.agency_item_assignments in share row exclusive mode;
create table public.business_rules_agencies (
 id uuid primary key default gen_random_uuid(),
 agency_name text not null check (length(btrim(agency_name)) between 1 and 160),
 agency_address text check (length(agency_address)<=250),
 city_state_zip text,
 agency_city text check (length(agency_city)<=120),
 agency_state text check (length(agency_state)<=60),
 agency_zip text check (length(agency_zip)<=20),
 active boolean not null default true,
 created_by uuid default auth.uid() references public.profiles(id),
 updated_by uuid default auth.uid() references public.profiles(id),
 created_at timestamptz not null default now(),updated_at timestamptz not null default now()
);
-- One-time snapshot preserves IDs so saved assignment/source/retention rows remain intact.
-- Training records are retained in their original table; future changes are independent.
insert into public.business_rules_agencies(id,agency_name,agency_address,city_state_zip,agency_city,agency_state,agency_zip,active,created_by,updated_by,created_at,updated_at)
select id,agency_name,agency_address,city_state_zip,agency_city,agency_state,agency_zip,coalesce(active,true),created_by,updated_by,coalesce(created_at,now()),coalesce(updated_at,created_at,now()) from public.agencies;
create unique index business_rules_agencies_name_uidx on public.business_rules_agencies(lower(regexp_replace(btrim(agency_name),'\s+',' ','g')));
create index business_rules_agencies_created_by_idx on public.business_rules_agencies(created_by);
create index business_rules_agencies_updated_by_idx on public.business_rules_agencies(updated_by);
alter table public.agency_item_assignments drop constraint agency_item_assignments_agency_id_fkey;
alter table public.agency_item_assignments add constraint agency_item_assignments_agency_id_fkey foreign key(agency_id) references public.business_rules_agencies(id) on delete cascade;

create function public.normalize_business_rules_agency() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 new.agency_name:=regexp_replace(btrim(new.agency_name),'\s+',' ','g');
 new.agency_address:=nullif(btrim(new.agency_address),'');
 new.agency_city:=nullif(btrim(new.agency_city),'');new.agency_state:=nullif(btrim(new.agency_state),'');new.agency_zip:=nullif(btrim(new.agency_zip),'');
 return new;
end $$;
revoke all on function public.normalize_business_rules_agency() from public,anon,authenticated;
create trigger business_rules_agencies_normalize before insert or update on public.business_rules_agencies for each row execute function public.normalize_business_rules_agency();
create trigger business_rules_agencies_location before update on public.business_rules_agencies for each row execute function public.sync_agency_registry_location();
create trigger business_rules_agencies_touch before update on public.business_rules_agencies for each row execute function public.touch_resource_registry();

alter table public.business_rules_agencies enable row level security;
revoke all on public.business_rules_agencies from public,anon,authenticated;
grant select,insert,update on public.business_rules_agencies to authenticated;
grant all on public.business_rules_agencies to service_role;
create policy business_rules_agencies_read on public.business_rules_agencies for select to authenticated using ((select public.current_user_role()) in ('admin','coordinator','trainer','viewer'));
create policy business_rules_agencies_insert on public.business_rules_agencies for insert to authenticated with check ((select public.current_user_role()) in ('admin','coordinator') and created_by=(select auth.uid()) and updated_by=(select auth.uid()));
create policy business_rules_agencies_update on public.business_rules_agencies for update to authenticated using ((select public.current_user_role()) in ('admin','coordinator')) with check ((select public.current_user_role()) in ('admin','coordinator') and updated_by=(select auth.uid()));

create or replace function public.import_business_rules_agencies(p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path=public as $$
declare r jsonb; n text; imported integer:=0; skipped integer:=0; existing_id uuid;
begin
 if not public.is_manager() then raise exception 'Administrator or Coordinator access is required.'; end if;
 if jsonb_typeof(p_rows) is distinct from 'array' then raise exception 'Supply an array of agency rows.'; end if;
 if jsonb_array_length(p_rows)<1 or jsonb_array_length(p_rows)>500 then raise exception 'Import between 1 and 500 agencies at a time.'; end if;
 -- Serialize imports and manual agency saves; recheck names inside the transaction.
 lock table public.business_rules_agencies in share row exclusive mode;
 for r in select value from jsonb_array_elements(p_rows) loop
  n:=nullif(regexp_replace(btrim(r->>'agency_name'),'\s+',' ','g'),'');
  if n is null or length(n)>160 or length(coalesce(r->>'agency_address',''))>250 or length(coalesce(r->>'agency_city',''))>120 or length(coalesce(r->>'agency_state',''))>60 or length(coalesce(r->>'agency_zip',''))>20 then
   raise exception 'Invalid agency row. Review the name and address field lengths.';
  end if;
  select id into existing_id from public.business_rules_agencies where lower(regexp_replace(btrim(agency_name),'\s+',' ','g'))=lower(n) limit 1;
  if existing_id is not null then skipped:=skipped+1; continue; end if;
  insert into public.business_rules_agencies(agency_name,agency_address,agency_city,agency_state,agency_zip,city_state_zip,created_by,updated_by)
  values(n,btrim(coalesce(r->>'agency_address','')),nullif(btrim(r->>'agency_city'),''),nullif(btrim(r->>'agency_state'),''),nullif(btrim(r->>'agency_zip'),''),
   concat_ws(', ',nullif(btrim(r->>'agency_city'),''),nullif(btrim(r->>'agency_state'),''),nullif(btrim(r->>'agency_zip'),'')),auth.uid(),auth.uid());
  imported:=imported+1;
 end loop;
 return jsonb_build_object('imported',imported,'skipped',skipped);
end; $$;
revoke all on function public.import_business_rules_agencies(jsonb) from public,anon;
grant execute on function public.import_business_rules_agencies(jsonb) to authenticated;

-- Compatibility for an already-open pre-release import screen: never import into training.
create or replace function public.import_agencies(p_rows jsonb)
returns jsonb language plpgsql security invoker set search_path='' as $$
begin
 return public.import_business_rules_agencies(p_rows);
end $$;
revoke all on function public.import_agencies(jsonb) from public,anon;
grant execute on function public.import_agencies(jsonb) to authenticated;

create or replace function private.cleanup_catalog() returns table(table_name text,label text)
language sql stable set search_path='' as $$ values
 ('resource_items','Resource item catalog'),('agency_item_assignments','Agency item assignments'),
 ('business_rules_agencies','Business Rules agencies'),('agencies','Training agencies'),('agency_portal_links','Agency portal links'),
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

;

-- SOURCE: database/bulk_business_rule_assignments.sql
-- Atomic batch insert/update; staff permissions and RLS remain in force.
create or replace function public.save_business_rule_assignments(p_agency_id uuid,p_rows jsonb)
returns integer language plpgsql security invoker set search_path = '' as $$
declare r jsonb; old public.agency_item_assignments%rowtype; tool uuid; n integer:=0;
begin
 if public.current_user_role() is null or public.current_user_role() not in ('admin','coordinator') then raise exception 'Administrator or Coordinator access is required.';end if;
 if p_rows is null or jsonb_typeof(p_rows)<>'array' then raise exception 'Select 1 to 100 tools.';end if;
 if jsonb_array_length(p_rows) not between 1 and 100 then raise exception 'Select 1 to 100 tools.';end if;
 -- Serialize batches for this agency and protect active status during save.
 perform id from public.business_rules_agencies where id=p_agency_id and active for update;
 if not found then raise exception 'Choose an active business rules agency.';end if;
 if (select count(distinct value->>'item_id') from jsonb_array_elements(p_rows))<>jsonb_array_length(p_rows) then raise exception 'Select each tool once.';end if;
 for r in select value from jsonb_array_elements(p_rows) order by value->>'item_id' loop
  tool:=(r->>'item_id')::uuid;
  if jsonb_typeof(r)<>'object' or nullif(btrim(r->>'data_source'),'') is null or length(btrim(r->>'data_source'))>250 or coalesce(r->>'retention_value','') !~ '^[0-9]+$' or (r->>'retention_value')::numeric not between 1 and 9999 or coalesce(r->>'retention_unit','') not in ('Days','Months','Years') then raise exception 'Each tool needs a data source and a whole retention period from 1 to 9999 with Days, Months, or Years.';end if;
  perform id from public.resource_items where id=tool for key share;
  if not found then raise exception 'A selected tool is unavailable. Refresh records.';end if;
  select * into old from public.agency_item_assignments where agency_id=p_agency_id and item_id=tool for update;
  if found then
   if nullif(r->>'expected_updated_at','') is null or old.updated_at<>(r->>'expected_updated_at')::timestamptz then raise exception 'An assignment changed. No assignments saved. Clear selection, refresh records, and review again.';end if;
   update public.agency_item_assignments set data_source=btrim(r->>'data_source'),retention_value=(r->>'retention_value')::integer,retention_unit=r->>'retention_unit',updated_by=auth.uid() where id=old.id;
  else
   if nullif(r->>'expected_updated_at','') is not null then raise exception 'An assignment was removed. No assignments saved. Clear selection and refresh records.';end if;
   insert into public.agency_item_assignments(agency_id,item_id,data_source,retention_value,retention_unit) values(p_agency_id,tool,btrim(r->>'data_source'),(r->>'retention_value')::integer,r->>'retention_unit');
  end if;
  n:=n+1;
 end loop;
 return n;
exception when unique_violation then raise exception 'An assignment was added by another user. No assignments saved. Clear selection and refresh records.';
end $$;
revoke all on function public.save_business_rule_assignments(uuid,jsonb) from public,anon;
grant execute on function public.save_business_rule_assignments(uuid,jsonb) to authenticated;

;

-- SOURCE: database/trainer_assignment_workflow.sql
alter table public.training_requests
 add column trainer_response text not null default 'Pending' check (trainer_response in ('Pending','Accepted','Declined')),
 add column trainer_responded_at timestamptz,
 add column trainer_decline_reason text;

create or replace function public.guard_trainer_response_fields()
returns trigger language plpgsql set search_path = '' as $$
begin
 if current_user='authenticated' and (
 new.trainer_response is distinct from old.trainer_response or
 new.trainer_responded_at is distinct from old.trainer_responded_at or
 new.trainer_decline_reason is distinct from old.trainer_decline_reason) then
 raise exception 'Use the controlled trainer response workflow.';
 end if;
 if new.assigned_trainer_id is distinct from old.assigned_trainer_id then
 new.trainer_response:='Pending';new.trainer_responded_at:=null;new.trainer_decline_reason:=null;
 if old.class_status in ('Draft','Scheduled') then new.teams_meeting_url:=null;end if;
 end if;
 return new;
end $$;
create trigger trg_guard_trainer_response_fields before update on public.training_requests
for each row execute function public.guard_trainer_response_fields();

create or replace function public.respond_to_training_assignment(p_request_id uuid,p_response text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.training_requests%rowtype;v_reason text:=nullif(btrim(p_reason),'');
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active and role='trainer') then
 raise exception 'An active trainer account is required.';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if not found or r.assigned_trainer_id is distinct from auth.uid() then
 raise exception 'Only the assigned trainer can respond to this request.';end if;
 if r.class_status in ('In Progress','Closed','Completed','Archived') or r.archived_at is not null or r.status='Completed' then
 raise exception 'This class is locked for trainer responses.';end if;
 if p_response is null or p_response not in ('Accepted','Declined') then raise exception 'Choose Accepted or Declined.';end if;
 if r.trainer_response=p_response then return jsonb_build_object('trainer_response',r.trainer_response);end if;
 if r.trainer_response<>'Pending' then raise exception 'This assignment has already been answered. Contact administration for reassignment.';end if;
 if p_response='Declined' and r.class_status='Registration Open' then raise exception 'Contact administration to decline a class with open registration.';end if;
 if p_response='Declined' and v_reason is null then raise exception 'A reason is required when declining.';end if;
 if length(coalesce(v_reason,''))>1000 then raise exception 'Keep the decline reason within 1000 characters.';end if;
 update public.training_requests set trainer_response=p_response,trainer_responded_at=now(),
 trainer_decline_reason=case when p_response='Declined' then v_reason else null end,updated_by=auth.uid() where id=r.id;
 insert into public.training_request_activity(request_id,actor_id,action,details)
 values(r.id,auth.uid(),'trainer_assignment_response',jsonb_build_object('response',p_response,'reason',case when p_response='Declined' then v_reason else null end));
 perform public.push_manager_notification(r.id,'assignment','Trainer Assignment '||p_response,
 r.request_number||' — '||r.agency_name||': assigned trainer '||lower(p_response)||' the request.',
 case when p_response='Declined' then 'warning' else 'success' end,
 '/requests/edit','trainer-response:'||r.id::text||':'||auth.uid()::text||':'||extract(epoch from now())::text);
 return jsonb_build_object('trainer_response',p_response);
end $$;

create or replace function public.set_training_request_teams_link(p_request_id uuid,p_url text)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.training_requests%rowtype;v_new text:=nullif(btrim(coalesce(p_url,'')),'');v_host text;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active) then
 raise exception 'An active account is required.';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if not found then raise exception 'Training request not found.';end if;
 if not public.is_manager() and not (
 r.assigned_trainer_id is not distinct from auth.uid() and r.trainer_response='Accepted' and
 exists(select 1 from public.profiles where id=auth.uid() and active and role='trainer')) then
 raise exception 'Only managers or the assigned trainer after acceptance can update the Teams meeting link.';end if;
 if r.class_status in ('In Progress','Closed','Completed','Archived') or r.archived_at is not null or r.status='Completed' then
 raise exception 'This class is locked for Teams link updates.';end if;
 if v_new is not null and r.training_format not in ('Virtual','Hybrid') then
 raise exception 'A Teams meeting link can only be added to Virtual or Hybrid training.';end if;
 if v_new is not null then
 v_host:=lower(substring(v_new from '^https://([^/?#]+)(?:[/?#]|$)'));
 if v_host is null or v_host not in ('teams.microsoft.com','teams.live.com','teams.cloud.microsoft') then
 raise exception 'Enter a valid Microsoft Teams meeting link.';end if;
 if v_new ~ '[[:space:]]' then raise exception 'Enter a valid Microsoft Teams meeting link.';end if;
 end if;
 update public.training_requests set teams_meeting_url=v_new,updated_by=auth.uid() where id=r.id;
 if r.teams_meeting_url is distinct from v_new then
 insert into public.training_request_activity(request_id,actor_id,action,details)
 values(r.id,auth.uid(),case when v_new is null then 'teams_meeting_link_removed' else 'teams_meeting_link_updated' end,
 jsonb_build_object('previous_url',r.teams_meeting_url,'new_url',v_new));end if;
end $$;
revoke all on function public.respond_to_training_assignment(uuid,text,text) from public,anon;
grant execute on function public.respond_to_training_assignment(uuid,text,text) to authenticated;
revoke all on function public.set_training_request_teams_link(uuid,text) from public,anon;
grant execute on function public.set_training_request_teams_link(uuid,text) to authenticated;
revoke all on function public.guard_trainer_response_fields() from public,anon,authenticated;

;

-- SOURCE: database/dashboard_notification_attention.sql
create or replace function public.get_dashboard_notification_attention()
returns jsonb language plpgsql stable security invoker set search_path='' as $function$
declare v_role text;
begin
  v_role := public.current_user_role();
  if auth.uid() is null or v_role is null or v_role not in ('admin','trainer') then
    raise exception 'An active administrator or trainer account is required.';
  end if;
  return (
    with owned as materialized (
      select n.*,row_number() over (partition by n.request_id,n.notification_type order by n.created_at desc,n.id desc) as notification_rank, r.assigned_trainer_id,r.trainer_response,r.confirmed_date,r.confirmed_start_time,
        r.created_at as request_created_at,r.total_minutes,
        r.id is not null and r.archived_at is null
          and lower(coalesce(r.status,'')) not in ('completed','closed','archived','cancelled','finalized')
          and lower(coalesce(r.class_status,'')) not in ('closed','completed','archived','cancelled','finalized') as live_request,
        r.class_status,
        case r.time_zone when 'Central' then 'America/Chicago' when 'Mountain' then 'America/Denver' when 'Pacific' then 'America/Los_Angeles' else 'America/New_York' end as zone
      from public.training_notifications n
      left join public.training_requests r on r.id=n.request_id
      where n.user_id=auth.uid()
    ), classified as materialized (
      select o.*,
        coalesce(o.live_request and o.notification_rank=1 and case
          when o.notification_type='assignment' then
            (v_role='trainer' and o.assigned_trainer_id=auth.uid() and o.trainer_response='Pending' and o.class_status<>'In Progress')
            or (v_role='admin' and o.trainer_response='Declined' and o.severity='warning')
          when o.notification_type='unassigned' then v_role='admin' and o.assigned_trainer_id is null
          when o.notification_type='unscheduled' then v_role='admin' and o.confirmed_date is null
          when o.notification_type='schedule_conflict' then exists (
            select 1 from public.training_requests other
            where other.id<>o.request_id and other.assigned_trainer_id=o.assigned_trainer_id
              and other.confirmed_date=o.confirmed_date and other.archived_at is null
              and lower(other.status) not in ('completed','closed','archived','cancelled','finalized')
              and lower(other.class_status) not in ('closed','completed','archived','cancelled','finalized')
              and other.confirmed_start_time is not null and o.confirmed_start_time is not null
              and other.total_minutes>0 and o.total_minutes>0
              and (o.confirmed_date+o.confirmed_start_time)<(other.confirmed_date+other.confirmed_start_time)+pg_catalog.make_interval(mins=>other.total_minutes)
              and (other.confirmed_date+other.confirmed_start_time)<(o.confirmed_date+o.confirmed_start_time)+pg_catalog.make_interval(mins=>o.total_minutes)
          )
          else false end,false) as action_pending,
        case
          when o.notification_type='unassigned' then o.request_created_at+interval '24 hours'
          when o.notification_type='unscheduled' then o.request_created_at+interval '72 hours'
          when o.notification_type in ('assignment','schedule_conflict') and o.confirmed_date is not null
            then (o.confirmed_date+coalesce(o.confirmed_start_time,time '23:59:59')) at time zone o.zone
          else null end as due_at
      from owned o
    ), attention as materialized (
      select c.*,coalesce(c.action_pending and c.due_at<now(),false) as overdue,
        case when c.action_pending and c.notification_type='assignment' and v_role='trainer' then '/trainer-workspace'
          when c.action_pending and c.notification_type='schedule_conflict' then '/calendar?request='||c.request_id::text
          when c.action_pending then '/requests/edit?request='||c.request_id::text
          else c.action_url end as dashboard_action_url
      from classified c where c.read_at is null or c.action_pending
    ), latest as (
      select id,request_id,notification_type,title,message,severity,read_at,created_at,action_pending,overdue,due_at,dashboard_action_url as action_url
      from attention order by created_at desc,id desc limit 5
    )
    select pg_catalog.jsonb_build_object(
      'attention_count',(select count(*) from attention),
      'unread_count',(select count(*) from classified where read_at is null),
      'open_action_count',(select count(*) from classified where action_pending),
      'overdue_count',(select count(*) from attention where overdue),
      'items',coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(l) order by l.created_at desc,l.id desc) from latest l),'[]'::jsonb)
    )
  );
end $function$;
revoke all on function public.get_dashboard_notification_attention() from public,anon;
grant execute on function public.get_dashboard_notification_attention() to authenticated;
comment on function public.get_dashboard_notification_attention() is 'Own notifications for active administrators/trainers under RLS; unresolved workflow actions remain independent of read status. Read-only, no reminders or outgoing email generated.';


;

-- SOURCE: supabase/migrations/20260903_extend_active_user_history_with_sessions.sql
-- Extend the authenticated active-user read-only directory payload with attendance session summaries.
-- Direct session/attendee table RLS remains restricted; operational writes are unchanged.
create or replace function public.get_training_attendee_directory()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $function$
begin
  if not public.is_active_user() then
    raise exception 'Active Backtrace account required.';
  end if;

  return jsonb_build_object(
    'people', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',p.id,'agency_name',p.agency_name,'badge_id',p.badge_id,'full_name',p.full_name,
        'email',p.email,'title_position',p.title_position,'first_seen_at',p.first_seen_at,'last_seen_at',p.last_seen_at
      ) order by lower(p.full_name),lower(p.email))
      from public.training_people p
    ),'[]'::jsonb),
    'attendance', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',a.id,'person_id',a.person_id,'request_id',a.request_id,'full_name',a.full_name,'email',a.email,
        'title_position',a.title_position,'badge_id',a.badge_id,'attendance_status',a.attendance_status,
        'certificate_number',a.certificate_number,'certificate_public_id',a.certificate_public_id,
        'registered_at',a.registered_at,'checked_in_at',a.checked_in_at
      ) order by a.registered_at,a.id)
      from public.training_attendees a
    ),'[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id',s.request_id,'active',s.active,'registration_open',s.registration_open,
        'checkin_open_at',s.checkin_open_at,'checkin_close_at',s.checkin_close_at
      ))
      from public.training_attendance_sessions s
    ),'[]'::jsonb),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'request_number',r.request_number,'confirmed_date',r.confirmed_date,'status',r.status,
        'class_status',r.class_status,'basic_training',r.basic_training,'train_the_trainer',r.train_the_trainer,
        'refresher_course',r.refresher_course,'advanced_training',r.advanced_training
      ))
      from public.training_requests r
    ),'[]'::jsonb),
    'completions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id',c.request_id,'actual_training_date',c.actual_training_date,'record_status',c.record_status
      ))
      from public.training_completion_records c
    ),'[]'::jsonb)
  );
end;
$function$;

revoke all on function public.get_training_attendee_directory() from public, anon;
grant execute on function public.get_training_attendee_directory() to authenticated;


;

-- SOURCE: supabase/migrations/20260903_archive_status_timezone_parity.sql
-- Keep Past Training Classes aligned with timezone-aware class closure.
-- Archive membership is based on actual workflow state rather than UTC current_date.
create or replace function public.search_training_class_archive(
  p_search text default null::text,
  p_start_date date default null::date,
  p_end_date date default null::date,
  p_limit integer default 500
)
returns table(
  request_id uuid,
  request_number text,
  agency_name text,
  confirmed_date date,
  confirmed_start_time time without time zone,
  training_location text,
  training_format text,
  status text,
  total_minutes integer,
  trainer_name text,
  attendee_count bigint,
  checked_in_count bigint,
  completed_count bigint,
  certificate_count bigint,
  completion_number text,
  actual_training_date date,
  actual_minutes integer,
  actual_attendees integer
)
language sql
security definer
set search_path to 'public'
as $function$
  select
    r.id,r.request_number,r.agency_name,r.confirmed_date,r.confirmed_start_time,
    r.training_location,r.training_format,r.status,r.total_minutes,
    coalesce(p.full_name,p.email),
    count(a.id),
    count(a.id) filter(where a.checked_in_at is not null),
    count(a.id) filter(where a.attendance_status='completed'),
    count(a.id) filter(where a.certificate_public_id is not null),
    c.completion_number,c.actual_training_date,c.actual_minutes,c.actual_attendees
  from public.training_requests r
  left join public.profiles p on p.id=r.assigned_trainer_id
  left join public.training_attendees a on a.request_id=r.id
  left join public.training_completion_records c on c.request_id=r.id
  where public.is_active_user()
    and public.can_edit_request(r.id)
    and r.confirmed_date is not null
    and (
      r.status='Completed'
      or r.class_status in ('Closed','Completed','Archived')
      or c.record_status='Finalized'
    )
    and (p_start_date is null or coalesce(c.actual_training_date,r.confirmed_date) >= p_start_date)
    and (p_end_date is null or coalesce(c.actual_training_date,r.confirmed_date) <= p_end_date)
    and (
      coalesce(trim(p_search),'')=''
      or r.request_number ilike '%'||trim(p_search)||'%'
      or r.agency_name ilike '%'||trim(p_search)||'%'
      or coalesce(r.training_location,'') ilike '%'||trim(p_search)||'%'
      or coalesce(p.full_name,p.email,'') ilike '%'||trim(p_search)||'%'
      or exists(
        select 1
        from public.training_attendees ax
        where ax.request_id=r.id
          and (
            ax.full_name ilike '%'||trim(p_search)||'%'
            or ax.email ilike '%'||trim(p_search)||'%'
            or coalesce(ax.badge_id,'') ilike '%'||trim(p_search)||'%'
          )
      )
    )
  group by r.id,p.full_name,p.email,c.completion_number,c.actual_training_date,c.actual_minutes,c.actual_attendees
  order by coalesce(c.actual_training_date,r.confirmed_date) desc,r.confirmed_start_time desc nulls last
  limit greatest(1,least(coalesce(p_limit,500),2000));
$function$;


;

-- SOURCE: supabase/migrations/20260904_final_uat_attendance_window_order.sql
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


;

-- SOURCE: supabase/migrations/20260903_final_uat_resource_crypto.sql
-- Final Production UAT: fix Resource Library secure-link cryptographic calls.
-- pgcrypto functions are installed in the Supabase extensions schema, while these
-- SECURITY DEFINER functions intentionally lock search_path to public.

create or replace function public.create_training_material_share(
  p_request_id uuid,
  p_material_version_ids uuid[],
  p_expires_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare tok text; h text; sid uuid; cnt integer; d integer;
begin
  if auth.uid() is null or not public.can_manage_training_materials() then raise exception 'Not authorized'; end if;
  if p_request_id is not null and not public.can_edit_request(p_request_id) then raise exception 'Not authorized for this training request'; end if;
  if p_material_version_ids is null or cardinality(p_material_version_ids)=0 then raise exception 'Select at least one material'; end if;
  if cardinality(p_material_version_ids)>50 then raise exception 'Too many materials selected'; end if;

  select count(*) into cnt
  from public.training_material_versions v
  join public.training_materials m on m.id=v.material_id
  where v.id=any(p_material_version_ids) and m.active=true and m.audience='student';

  if cnt<>cardinality(p_material_version_ids) then raise exception 'Student share contains an unavailable or internal material'; end if;

  d:=greatest(1,least(coalesce(p_expires_days,30),365));
  tok:=encode(extensions.gen_random_bytes(24),'hex');
  h:=encode(extensions.digest(tok,'sha256'),'hex');

  insert into public.training_material_share_links(token_hash,request_id,expires_at,created_by)
  values(h,p_request_id,now()+make_interval(days=>d),auth.uid()) returning id into sid;

  insert into public.training_material_share_items(share_id,material_version_id,sort_order)
  select sid,x,100+ord from unnest(p_material_version_ids) with ordinality t(x,ord);

  if p_request_id is not null then
    insert into public.training_class_materials(request_id,material_version_id,attached_by)
    select p_request_id,x,auth.uid() from unnest(p_material_version_ids) x on conflict do nothing;
  end if;

  return jsonb_build_object(
    'share_id',sid,
    'token',tok,
    'url','https://dzqsmqispdixwmklpwdf.supabase.co/functions/v1/training-materials-share?token='||tok,
    'expires_at',now()+make_interval(days=>d)
  );
end;
$function$;

create or replace function public.queue_training_material_distribution(
  p_request_id uuid,
  p_material_version_ids uuid[],
  p_recipient_emails text[] default null::text[],
  p_expires_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  rec record; tok text; h text; sid uuid; qid bigint; queued integer:=0;
  cnt integer; d integer; req record; html text; plain text; link text;
begin
  if auth.uid() is null or not public.can_manage_training_materials() then raise exception 'Not authorized'; end if;
  if p_request_id is null or not public.can_edit_request(p_request_id) then raise exception 'Not authorized for this training request'; end if;
  if p_material_version_ids is null or cardinality(p_material_version_ids)=0 then raise exception 'Select at least one material'; end if;

  select count(*) into cnt
  from public.training_material_versions v
  join public.training_materials m on m.id=v.material_id
  where v.id=any(p_material_version_ids) and m.active=true and m.audience='student';

  if cnt<>cardinality(p_material_version_ids) then raise exception 'Distribution contains an unavailable or internal material'; end if;

  select request_number,agency_name,confirmed_date into req
  from public.training_requests where id=p_request_id;

  d:=greatest(1,least(coalesce(p_expires_days,30),365));

  insert into public.training_class_materials(request_id,material_version_id,attached_by)
  select p_request_id,x,auth.uid() from unnest(p_material_version_ids) x on conflict do nothing;

  for rec in
    with requested as (
      select distinct lower(trim(e)) email, null::uuid attendee_id
      from unnest(coalesce(p_recipient_emails,'{}'::text[])) e
      where trim(e)<>''
    ), class_emails as (
      select distinct lower(trim(a.email)) email,a.id attendee_id
      from public.training_attendees a
      where a.request_id=p_request_id
        and coalesce(cardinality(p_recipient_emails),0)=0
        and trim(a.email)<>''
    )
    select * from requested union all select * from class_emails
  loop
    if position('@' in rec.email)=0 then continue; end if;

    tok:=encode(extensions.gen_random_bytes(24),'hex');
    h:=encode(extensions.digest(tok,'sha256'),'hex');

    insert into public.training_material_share_links(token_hash,request_id,recipient_email,expires_at,created_by)
    values(h,p_request_id,rec.email,now()+make_interval(days=>d),auth.uid())
    returning id into sid;

    insert into public.training_material_share_items(share_id,material_version_id,sort_order)
    select sid,x,100+ord from unnest(p_material_version_ids) with ordinality t(x,ord);

    link:='https://dzqsmqispdixwmklpwdf.supabase.co/functions/v1/training-materials-share?token='||tok;
    plain:='Backtrace Training Materials'||E'\n\n'||coalesce(req.agency_name,'')||' — '||coalesce(req.request_number,'')||E'\n\nOpen your secure training materials: '||link||E'\n\nThis link expires in '||d||' days.';
    html:='<div style="font-family:Arial,sans-serif;color:#172033"><h2 style="color:#0d2853">Backtrace Training Materials</h2><p><b>'||replace(coalesce(req.agency_name,''),'&','&amp;')||'</b><br>'||replace(coalesce(req.request_number,''),'&','&amp;')||'</p><p>Your training materials are available through the secure link below.</p><p><a href="'||link||'" style="display:inline-block;background:#2459a9;color:#fff;text-decoration:none;padding:10px 16px;border-radius:7px;font-weight:bold">Open Training Materials</a></p><p style="font-size:12px;color:#667085">This link expires in '||d||' days.</p></div>';

    insert into public.training_email_queue(recipient_email,subject,text_body,html_body,status,attempts,next_attempt_at,queued_at,dedupe_key)
    values(rec.email,'Training Materials — '||coalesce(req.agency_name,req.request_number),plain,html,'pending',0,now(),now(),'training-materials:'||sid::text)
    returning id into qid;

    insert into public.training_material_distributions(request_id,share_id,attendee_id,recipient_email,email_queue_id,created_by)
    values(p_request_id,sid,rec.attendee_id,rec.email,qid,auth.uid());

    queued:=queued+1;
  end loop;

  return jsonb_build_object('ok',true,'queued',queued,'request_id',p_request_id,'expires_days',d);
end;
$function$;


;

-- SOURCE: database/certificate_duration_repeat_issuance.sql
CREATE OR REPLACE FUNCTION public.issue_training_certificate(p_attendee_id uuid, p_actor uuid DEFAULT auth.uid())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  a public.training_attendees%rowtype;
  r public.training_requests%rowtype;
  c public.training_completion_records%rowtype;
  v_public uuid;
  v_num text;
  v_new boolean := false;
  v_trainer text;
  v_type text;
  v_date date;
begin
  select * into a from public.training_attendees where id=p_attendee_id for update;
  if a.id is null then raise exception 'Attendee not found.'; end if;
  if a.checked_in_at is null then raise exception 'Attendee must be checked in before a certificate can be issued.'; end if;
  if a.attendance_status='ineligible' then raise exception 'Attendee is not eligible for a certificate.'; end if;

  if a.certificate_public_id is null then
    select * into r from public.training_requests where id=a.request_id;
    select * into c from public.training_completion_records where request_id=a.request_id;
    select coalesce(full_name,email) into v_trainer from public.profiles where id=r.assigned_trainer_id;
    v_type := case when r.train_the_trainer then 'Train the Trainer Course (8 Hours)'
                   when r.refresher_course then 'Refresher Course'
                   when r.advanced_training then 'Advanced Training'
                   when r.basic_training then 'Basic Backtrace Search Techniques (4 Hours)'
                   else 'Backtrace Training' end;
    v_date := coalesce(c.actual_training_date,r.confirmed_date,r.preferred_date,current_date);

    v_new := true;
    v_public := gen_random_uuid();
    v_num := public.next_training_certificate_number();
    update public.training_attendees
      set attendance_status='completed',
          completion_confirmed_at=coalesce(completion_confirmed_at,now()),
          completion_confirmed_by=coalesce(completion_confirmed_by,p_actor),
          certificate_number=v_num,
          certificate_public_id=v_public,
          certificate_issued_at=now(),
          certificate_attendee_name_snapshot=a.full_name,
          certificate_agency_name_snapshot=coalesce(r.agency_name,a.agency_name),
          certificate_training_type_snapshot=v_type,
          certificate_training_date_snapshot=v_date,
          certificate_trainer_name_snapshot=coalesce(v_trainer,'Backtrace Trainer'),
          certificate_request_number_snapshot=r.request_number,
          certificate_total_minutes_snapshot=r.total_minutes,
          updated_at=now()
    where id=a.id;
  else
    return a.certificate_public_id;
  end if;
  if v_new then perform public.queue_training_certificate_email(a.id); end if;
  return v_public;
end;
$function$


;

-- The current interface identifies tools by name across all item types.
drop index public.resource_items_name_type_uidx;
create unique index resource_items_name_uidx on public.resource_items(lower(regexp_replace(btrim(name),'\s+',' ','g')));
