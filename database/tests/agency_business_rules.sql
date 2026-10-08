begin;
do $test$
declare a uuid;t uuid;g uuid;g2 uuid;i uuid;s uuid;r uuid;stamp timestamptz;n integer;p jsonb;result jsonb;
begin
 select id into a from public.profiles where active and role='admin' limit 1;
 select id into t from public.profiles where active and role='trainer' limit 1;
 if a is null or t is null then raise exception 'QA requires an active administrator and trainer';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 insert into public.business_rules_agencies(agency_name,agency_address,city_state_zip,agency_city,agency_state,agency_zip,created_by,updated_by)
 values('Registry Rollback Agency','100 QA Street','QA City, NJ, 00000','QA City','NJ','00000',a,a) returning id into g;
 insert into public.business_rules_agencies(agency_name,created_by,updated_by) values('Registry Rollback Other Agency',a,a) returning id into g2;
 insert into public.resource_items(name,item_type,description,expected_outcome) values('Registry Rollback Tool','Tool','Find linked records.','Identify relevant connections.') returning id into i;
 insert into public.agency_item_assignments(agency_id,item_id,data_source,retention_value,retention_unit) values(g,i,'Agency One Feed',90,'Days') returning id,updated_at into s,stamp;
 insert into public.agency_item_assignments(agency_id,item_id,data_source,retention_value,retention_unit) values(g2,i,'Agency Two Feed',7,'Years');
 if (select count(*) from public.agency_item_assignments where item_id=i)<>2 then raise exception 'Item reuse failed';end if;
 begin insert into public.resource_items(name,item_type,description) values(' registry   rollback tool ','Tool','Duplicate');raise exception 'Duplicate catalog item allowed';exception when unique_violation then null;end;
 begin insert into public.agency_item_assignments(agency_id,item_id,data_source,retention_value,retention_unit) values(g,i,'Duplicate',1,'Days');raise exception 'Duplicate agency/item pair allowed';exception when unique_violation then null;end;
 begin insert into public.agency_item_assignments(agency_id,item_id,data_source,retention_value,retention_unit) values(g,gen_random_uuid(),'Bad FK',1,'Days');raise exception 'Unknown item allowed';exception when foreign_key_violation then null;end;
 begin update public.agency_item_assignments set retention_value=0 where id=s;raise exception 'Zero retention allowed';exception when check_violation then null;end;
 update public.agency_item_assignments set retention_value=120 where id=s and updated_at=stamp;
 update public.agency_item_assignments set retention_value=999 where id=s and updated_at=stamp;
 get diagnostics n=row_count;if n<>0 then raise exception 'Stale assignment update allowed';end if;
 if (select data_source from public.agency_item_assignments where agency_id=g2 and item_id=i)<>'Agency Two Feed' then raise exception 'Agency-specific source overwritten';end if;
 -- An agency registered before it trains must not be linked automatically to training.
 insert into public.training_requests(agency_name,basic_training,trainer_contact_name,trainer_contact_email,trainer_contact_phone,created_by,updated_by,total_minutes)
 values('  REGISTRY ROLLBACK AGENCY  ',true,'QA Trainer','qa@example.invalid','555-0100',a,a,240) returning id into r;
 if (select agency_id from public.training_requests where id=r) is not null then raise exception 'Business Rules agency leaked into training matching';end if;
 if (select count(*) from public.business_rules_agencies where lower(btrim(agency_name))='registry rollback agency')<>1 then raise exception 'Duplicate agency created';end if;
 if (select retention_value from public.agency_item_assignments where id=s)<>120 then raise exception 'Training changed retention';end if;
 if (select agency_address from public.business_rules_agencies where id=g)<>'100 QA Street' then raise exception 'Training overwrote agency';end if;
 update public.business_rules_agencies set city_state_zip='New City, PA, 11111' where id=g;
 if exists(select 1 from public.business_rules_agencies where id=g and (agency_city is not null or agency_state is not null or agency_zip is not null)) then raise exception 'Legacy address edit left stale structured address';end if;
 -- Trainers and viewers may read, but cannot change registry rules.
 execute 'reset role';
 perform set_config('request.jwt.claims',jsonb_build_object('sub',t,'role','authenticated')::text,true);perform set_config('request.jwt.claim.sub',t::text,true);
 execute 'set local role authenticated';
 if not exists(select 1 from public.resource_items where id=i) then raise exception 'Trainer read failed';end if;
 update public.resource_items set description='Unauthorized' where id=i;get diagnostics n=row_count;if n<>0 then raise exception 'Trainer update permitted';end if;
 begin insert into public.resource_items(name,item_type,description) values('Unauthorized','Tool','Forbidden');raise exception 'Trainer insert permitted';exception when insufficient_privilege then null;end;
 execute 'reset role';update public.profiles set role='coordinator' where id=t;execute 'set local role authenticated';
 update public.resource_items set expected_outcome='Coordinator update' where id=i;get diagnostics n=row_count;if n<>1 then raise exception 'Coordinator update failed';end if;
 execute 'reset role';update public.profiles set role='viewer' where id=t;execute 'set local role authenticated';
 if not exists(select 1 from public.agency_item_assignments where id=s) then raise exception 'Viewer read failed';end if;
 update public.agency_item_assignments set data_source='Unauthorized' where id=s;get diagnostics n=row_count;if n<>0 then raise exception 'Viewer update permitted';end if;
 execute 'reset role';update public.profiles set active=false where id=t;execute 'set local role authenticated';
 if exists(select 1 from public.resource_items where id=i) then raise exception 'Inactive read permitted';end if;
 execute 'reset role';execute 'set local role anon';
 begin perform id from public.resource_items;raise exception 'Anonymous read permitted';exception when insufficient_privilege then null;end;
 execute 'reset role';
 -- Reviewed cleanup includes both agency assignments when removing a test item.
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);perform set_config('request.jwt.claim.sub',a::text,true);
 execute 'set local role authenticated';
 p:=public.preview_test_cleanup(jsonb_build_array(jsonb_build_object('table','resource_items','key',jsonb_build_object('id',i))));
 if (p->>'count')::integer<>3 or p->'blockers'<>'[]'::jsonb then raise exception 'Cleanup dependencies incorrect: %',p;end if;
 result:=public.delete_test_cleanup((p->>'id')::uuid,'DELETE 3 TEST RECORDS');
 if exists(select 1 from public.resource_items where id=i) or exists(select 1 from public.agency_item_assignments where item_id=i) then raise exception 'Reviewed cleanup failed';end if;
 if not exists(select 1 from public.business_rules_agencies where id=g) then raise exception 'Item cleanup deleted shared agency';end if;
 execute 'reset role';
end $test$;
rollback;
