begin;
do $test$
declare a uuid;t uuid;other_user uuid;r uuid;u uuid;c uuid;d uuid;n bigint;summary jsonb;before_count integer;after_count integer;item jsonb;
begin
 select id into a from public.profiles where active and role='admin' limit 1;
 select id into t from public.profiles where active and role='trainer' order by id limit 1;
 select id into other_user from public.profiles where active and role='trainer' and id<>t limit 1;
 if a is null or t is null or other_user is null then raise exception 'QA needs existing admin and two trainers';end if;
 -- Fixtures and their trigger-generated queue rows remain uncommitted and are rolled back.
 insert into public.training_requests(agency_name,basic_training,trainer_contact_name,trainer_contact_email,trainer_contact_phone,created_by,updated_by,assigned_trainer_id,confirmed_date,confirmed_start_time,time_zone,total_minutes)
 values('Dashboard attention rollback assignment',true,'QA Contact','qa@example.invalid','555-0100',a,a,t,current_date-1,'09:00','Pacific',240) returning id into r;
 insert into public.training_notifications(user_id,request_id,notification_type,title,message,severity,action_url,dedupe_key,read_at,created_at)
 values(t,r,'assignment','QA read assignment still pending','Read status must not close pending work','warning','/requests/edit','dashboard-qa-read-pending',now(),now()+interval '1 day') returning id into n;
 insert into public.training_notifications(user_id,notification_type,title,message,severity,dedupe_key,created_at)
 values(other_user,'qa_info','QA other recipient private','Must never appear for another recipient','info','dashboard-qa-isolation',now()+interval '2 days');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',t,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',t::text,true);
 execute 'set local role authenticated';
 summary:=public.get_dashboard_notification_attention();
 if not exists(select 1 from jsonb_array_elements(summary->'items') i where (i->>'id')::bigint=n and (i->>'action_pending')::boolean and i->>'read_at' is not null and (i->>'overdue')::boolean) then raise exception 'Read pending/overdue assignment missing: %',summary;end if;
 if exists(select 1 from jsonb_array_elements(summary->'items') i where i->>'title'='QA other recipient private') then raise exception 'Cross-recipient disclosure';end if;
 select i into item from jsonb_array_elements(summary->'items') i where (i->>'id')::bigint=n;
 if (item->>'due_at')::timestamptz is distinct from ((current_date-1+time '09:00') at time zone 'America/Los_Angeles') then raise exception 'Pacific timezone incorrect';end if;
 perform public.respond_to_training_assignment(r,'Accepted',null);
 summary:=public.get_dashboard_notification_attention();
 if exists(select 1 from jsonb_array_elements(summary->'items') i where (i->>'id')::bigint=n) then raise exception 'Accepted read assignment still pending';end if;
 execute 'reset role';
 -- Exact counts are independent of the five-item preview.
 for before_count in 1..7 loop
 insert into public.training_notifications(user_id,notification_type,title,message,severity,dedupe_key,created_at)
 values(t,'qa_info','QA own informational '||before_count,'Count beyond first five','info','dashboard-qa-info-'||before_count,now()+interval '3 days'+before_count*interval '1 second');
 end loop;
 execute 'set local role authenticated';
 summary:=public.get_dashboard_notification_attention();
 if jsonb_array_length(summary->'items')<>5 or (summary->>'unread_count')::integer<7 then raise exception 'Count/limit incorrect';end if;
 before_count:=(summary->>'unread_count')::integer;
 update public.training_notifications set read_at=now() where dedupe_key='dashboard-qa-info-7';
 after_count:=(public.get_dashboard_notification_attention()->>'unread_count')::integer;
 if after_count<>before_count-1 then raise exception 'Mark read did not update unread count';end if;
 execute 'reset role';
 -- Manager needs remain after reading, and clear when assigned/scheduled.
 insert into public.training_requests(agency_name,basic_training,trainer_contact_name,trainer_contact_email,trainer_contact_phone,created_by,updated_by,created_at)
 values('Dashboard attention rollback manager',true,'QA Contact','qa@example.invalid','555-0100',a,a,now()-interval '5 days') returning id into u;
 insert into public.training_notifications(user_id,request_id,notification_type,title,message,severity,action_url,dedupe_key,read_at,created_at)
 values(a,u,'unassigned','QA missing assignment','Needs a trainer','warning','/requests/edit','dashboard-qa-unassigned',now(),now()+interval '5 days'),
 (a,u,'unscheduled','QA missing schedule','Needs a date','warning','/requests/edit','dashboard-qa-unscheduled',now(),now()+interval '5 days');
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 summary:=public.get_dashboard_notification_attention();
 if (summary->>'open_action_count')::integer<2 or (summary->>'overdue_count')::integer<2 then raise exception 'Read manager actions missing';end if;
 execute 'reset role';
 update public.training_requests set assigned_trainer_id=t,confirmed_date=current_date+10,confirmed_start_time='09:00' where id=u;
 execute 'set local role authenticated';
 summary:=public.get_dashboard_notification_attention();
 if exists(select 1 from jsonb_array_elements(summary->'items') i where i->>'title' in ('QA missing assignment','QA missing schedule')) then raise exception 'Resolved manager needs still open';end if;
 execute 'reset role';
 -- Stale conflict notices do not stay open after schedules no longer overlap.
 insert into public.training_requests(agency_name,basic_training,trainer_contact_name,trainer_contact_email,trainer_contact_phone,created_by,updated_by,assigned_trainer_id,confirmed_date,confirmed_start_time,total_minutes)
 values('Dashboard attention rollback conflict A',true,'QA Contact','qa@example.invalid','555-0100',a,a,t,current_date+20,'09:00',240) returning id into c;
 insert into public.training_requests(agency_name,basic_training,trainer_contact_name,trainer_contact_email,trainer_contact_phone,created_by,updated_by,assigned_trainer_id,confirmed_date,confirmed_start_time,total_minutes)
 values('Dashboard attention rollback conflict B',true,'QA Contact','qa@example.invalid','555-0100',a,a,t,current_date+20,'17:00',240) returning id into d;
 insert into public.training_notifications(user_id,request_id,notification_type,title,message,severity,action_url,dedupe_key,read_at,created_at)
 values(a,c,'schedule_conflict','QA read conflict','Overlap still needs correction','critical','/calendar','dashboard-qa-conflict',now(),now()+interval '6 days') returning id into n;
 execute 'set local role authenticated';
 summary:=public.get_dashboard_notification_attention();
 if exists(select 1 from jsonb_array_elements(summary->'items') i where (i->>'id')::bigint=n) then raise exception 'Non-overlapping read conflict falsely open';end if;
 execute 'reset role';
 update public.training_requests set confirmed_start_time='18:00' where id=d;
 execute 'set local role authenticated';
 summary:=public.get_dashboard_notification_attention();
 if exists(select 1 from jsonb_array_elements(summary->'items') i where (i->>'id')::bigint=n) then raise exception 'Resolved conflict still open';end if;
 execute 'reset role';
 -- Viewer, coordinator, inactive and signed-out sessions cannot call the summary.
 update public.profiles set role='viewer' where id=other_user;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',other_user,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',other_user::text,true);
 execute 'set local role authenticated';
 begin perform public.get_dashboard_notification_attention();raise exception 'Viewer incorrectly allowed';exception when raise_exception then if sqlerrm='Viewer incorrectly allowed' then raise;end if;end;
 execute 'reset role';
 update public.profiles set role='coordinator' where id=other_user;
 execute 'set local role authenticated';
 begin perform public.get_dashboard_notification_attention();raise exception 'Coordinator incorrectly allowed';exception when raise_exception then if sqlerrm='Coordinator incorrectly allowed' then raise;end if;end;
 execute 'reset role';
 update public.profiles set role='trainer',active=false where id=other_user;
 execute 'set local role authenticated';
 begin perform public.get_dashboard_notification_attention();raise exception 'Inactive trainer incorrectly allowed';exception when raise_exception then if sqlerrm='Inactive trainer incorrectly allowed' then raise;end if;end;
 execute 'reset role';
 if has_function_privilege('anon','public.get_dashboard_notification_attention()','execute') then raise exception 'Anonymous execute granted';end if;
 perform set_config('request.jwt.claims','{}',true);perform set_config('request.jwt.claim.sub','',true);
 execute 'set local role authenticated';
 begin perform public.get_dashboard_notification_attention();raise exception 'Signed-out incorrectly allowed';exception when raise_exception then if sqlerrm='Signed-out incorrectly allowed' then raise;end if;end;
 execute 'reset role';
end $test$;
rollback;
