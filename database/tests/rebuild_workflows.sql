begin;
insert into auth.users(id,email,raw_user_meta_data) values('10000000-0000-0000-0000-000000000001','admin@rebuild.invalid','{}'),('10000000-0000-0000-0000-000000000002','viewer@rebuild.invalid','{}'),('10000000-0000-0000-0000-000000000003','trainer@rebuild.invalid','{}');
update public.profiles set active=true,role=case when email like 'admin@%' then 'admin' when email like 'trainer@%' then 'trainer' else 'viewer' end where email like '%@rebuild.invalid';
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000001',true);
set local role authenticated;
do $$declare r uuid; t uuid; begin
 r:=public.save_training_request(null,'{"agency_name":"Rebuild Test","basic_training":true,"training_format":"Virtual"}','{}');
 if (select total_minutes from public.training_requests where id=r)<>240 then raise exception 'Basic duration incorrect';end if;
 perform public.set_training_schedule(r,current_date+1,'09:00','10000000-0000-0000-0000-000000000003');
 if (select class_status from public.training_requests where id=r)<>'Scheduled' then raise exception 'Scheduling failed';end if;
 perform set_config('test.request_id',r::text,true);
 insert into public.resource_items(name,item_type,description) values('Arrest Tool','Tool','Arrest Data');
 begin insert into public.resource_items(name,item_type,description) values(' arrest   TOOL ','Dashboard','Arrest Data');raise exception 'Duplicate tool accepted';exception when unique_violation then null;end;
 if public.get_training_management_analytics(current_date,current_date)->'kpis'->>'total_requests'<>'1' then raise exception 'Analytics incorrect';end if;
end$$;
reset role;
insert into public.training_attendance_sessions(request_id) values(current_setting('test.request_id')::uuid);
set local role authenticated;
do $$declare r uuid:=current_setting('test.request_id')::uuid;a uuid;c jsonb; begin
 perform public.start_training_class(r);
 a:=public.add_training_attendee(r,'Test Attendee','attendee@rebuild.invalid','TEST-ID',null,true);
 perform public.close_training_class(r);
 c:=public.save_training_completion(r,jsonb_build_object('actual_training_date',current_date,'actual_start_time','09:00','actual_end_time','13:00','actual_minutes',240,'actual_attendees',1,'basic_training_completed',true),'{}',true);
 if c->>'record_status'<>'Finalized' then raise exception 'Finalization failed';end if;
 if (select class_status from public.training_requests where id=r)<>'Completed' then raise exception 'Class completion failed';end if;
 if not exists(select 1 from jsonb_array_elements(public.get_training_attendee_directory()->'attendance') attendee where attendee->>'certificate_number' is not null) then raise exception 'Certificate missing';end if;
 begin perform public.admin_save_training_request(r,'{"basic_training":true}','{}');raise exception 'Completed request was editable';exception when raise_exception then if sqlerrm='Completed request was editable' then raise;end if;end;
end$$;
reset role;
select set_config('request.jwt.claim.sub','10000000-0000-0000-0000-000000000002',true);
set local role authenticated;
do $$begin
 begin perform public.save_training_request(null,'{"basic_training":true}','{}');raise exception 'Viewer write allowed';exception when raise_exception then if sqlerrm='Viewer write allowed' then raise;end if;end;
 begin update public.profiles set role='admin' where id=auth.uid();raise exception 'Self escalation allowed';exception when insufficient_privilege then null;end;
 begin perform public.generate_training_reminders();raise exception 'Viewer reminders allowed';exception when raise_exception then if sqlerrm='Viewer reminders allowed' then raise;end if;end;
 if not public.is_active_user() then raise exception 'Viewer read helper broken';end if;
end$$;
reset role;
set local role anon;
do $$begin
 if has_function_privilege('anon','public.auto_close_expired_training_classes()','EXECUTE') then raise exception 'Anonymous autoclose enabled';end if;
 if has_function_privilege('authenticated','public.issue_training_certificate(uuid,uuid)','EXECUTE') then raise exception 'Internal certificate function exposed';end if;
 begin perform * from public.profiles;raise exception 'Anonymous profiles exposed';exception when insufficient_privilege then null;end;
end$$;
reset role;
rollback;
