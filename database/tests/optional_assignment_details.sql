-- Run after the optional_assignment_details migration. All fixtures roll back.
begin;
do $test$
declare admin_id uuid; trainer_id uuid; agency uuid; item uuid; invalid_item uuid; other_item uuid; stamp timestamptz; row_data jsonb; bad jsonb; n integer;
begin
 select id into admin_id from public.profiles where active and role='admin' limit 1;
 select id into trainer_id from public.profiles where active and role='trainer' limit 1;
 if admin_id is null then raise exception 'An active administrator is required for this test.';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',admin_id::text,true);
 execute 'set local role authenticated';
 insert into public.business_rules_agencies(agency_name) values('Optional details QA '||gen_random_uuid()) returning id into agency;
 for row_data in select value from jsonb_array_elements('[{}, {"data_source":" ","retention_value":"","retention_unit":""}, {"data_source":null,"retention_value":null,"retention_unit":null}, {"data_source":"RMS"}, {"retention_value":5}, {"retention_unit":"Years"}, {"data_source":"RMS","retention_value":90,"retention_unit":"Days"}]'::jsonb) loop
  insert into public.resource_items(name,item_type,description) values('Optional details QA '||gen_random_uuid(),'Tool','Rollback test') returning id into item;
  n:=public.save_business_rule_assignments(agency,jsonb_build_array(row_data||jsonb_build_object('item_id',item)));
  if n<>1 then raise exception 'Optional assignment save failed';end if;
  if not exists(select 1 from public.agency_item_assignments where agency_id=agency and item_id=item
    and data_source is not distinct from nullif(btrim(row_data->>'data_source'),'')
    and retention_value is not distinct from nullif(row_data->>'retention_value','')::integer
    and retention_unit is not distinct from nullif(row_data->>'retention_unit','')) then raise exception 'Optional values were not preserved';end if;
 end loop;
 select updated_at into stamp from public.agency_item_assignments where agency_id=agency and item_id=item;
 perform public.save_business_rule_assignments(agency,jsonb_build_array(jsonb_build_object('item_id',item,'expected_updated_at',stamp,'data_source',null,'retention_value',null,'retention_unit',null)));
 if not exists(select 1 from public.agency_item_assignments where agency_id=agency and item_id=item and data_source is null and retention_value is null and retention_unit is null) then raise exception 'Clearing existing metadata failed';end if;
 begin
  perform public.save_business_rule_assignments(agency,jsonb_build_array(jsonb_build_object('item_id',item,'expected_updated_at',stamp)));
  raise exception 'Stale update allowed';
 exception when raise_exception then if sqlerrm not like 'An assignment changed.%' then raise;end if;end;
 insert into public.resource_items(name,item_type,description) values('Optional invalid QA '||gen_random_uuid(),'Tool','Rollback test') returning id into invalid_item;
 insert into public.resource_items(name,item_type,description) values('Optional atomic QA '||gen_random_uuid(),'Tool','Rollback test') returning id into other_item;
 for bad in select value from jsonb_array_elements(jsonb_build_array(
   jsonb_build_object('retention_value',0),jsonb_build_object('retention_value',10000),jsonb_build_object('retention_value',-1),
   jsonb_build_object('retention_value',1.5),jsonb_build_object('retention_value','invalid'),jsonb_build_object('retention_unit','Weeks'),jsonb_build_object('data_source',repeat('X',251)))) loop
  begin
   perform public.save_business_rule_assignments(agency,jsonb_build_array(jsonb_build_object('item_id',other_item),bad||jsonb_build_object('item_id',invalid_item)));
   raise exception 'Invalid details allowed';
  exception when raise_exception then
   if sqlerrm not like 'Retention must be%' and sqlerrm not like 'Unit must be%' and sqlerrm not like 'Data source must be%' then raise;end if;
  end;
  if exists(select 1 from public.agency_item_assignments where agency_id=agency and item_id in (invalid_item,other_item)) then raise exception 'Invalid batch partially saved';end if;
 end loop;
 if trainer_id is not null then
  execute 'reset role';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',trainer_id,'role','authenticated')::text,true);
  perform set_config('request.jwt.claim.sub',trainer_id::text,true);
  execute 'set local role authenticated';
  begin perform public.save_business_rule_assignments(agency,jsonb_build_array(jsonb_build_object('item_id',invalid_item)));raise exception 'Trainer write allowed';
  exception when raise_exception then if sqlerrm<>'Administrator or Coordinator access is required.' then raise;end if;end;
 end if;
 execute 'reset role';execute 'set local role anon';
 begin perform public.save_business_rule_assignments(agency,jsonb_build_array(jsonb_build_object('item_id',invalid_item)));raise exception 'Anonymous write allowed';exception when insufficient_privilege then null;end;
 execute 'reset role';
end $test$;
rollback;
select 'PASS: blank, partial, full and cleared metadata; validation, atomicity, stale updates and role restrictions. Fixtures rolled back.' as result;
