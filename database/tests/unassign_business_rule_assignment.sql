-- Run after unassign_business_rule_assignment. All test records roll back.
begin;
do $test$
declare admin_id uuid; test_role text; agency_a uuid; agency_b uuid; tool uuid; other_tool uuid; assignment_id uuid; other_assignment_id uuid; stamp timestamptz; old_stamp timestamptz; n integer;
begin
 select id into admin_id from public.profiles where active and role='admin' limit 1;
 if admin_id is null then raise exception 'An administrator is required for this test.';end if;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);
 perform set_config('request.jwt.claim.sub',admin_id::text,true);execute 'set local role authenticated';
 insert into public.business_rules_agencies(agency_name) values('Unassign QA A '||gen_random_uuid()) returning id into agency_a;
 insert into public.business_rules_agencies(agency_name) values('Unassign QA B '||gen_random_uuid()) returning id into agency_b;
 insert into public.resource_items(name,item_type,description) values('Unassign QA Tool '||gen_random_uuid(),'Tool','Rollback test') returning id into tool;
 insert into public.resource_items(name,item_type,description) values('Unassign QA Other '||gen_random_uuid(),'Dashboard','Rollback test') returning id into other_tool;
 perform public.save_business_rule_assignments(agency_a,jsonb_build_array(jsonb_build_object('item_id',tool,'data_source','A feed','retention_value',5,'retention_unit','Years'),jsonb_build_object('item_id',other_tool)));
 perform public.save_business_rule_assignments(agency_b,jsonb_build_array(jsonb_build_object('item_id',tool,'data_source','B feed','retention_value',90,'retention_unit','Days')));
 select id,updated_at into assignment_id,stamp from public.agency_item_assignments where agency_id=agency_a and item_id=tool;
 select id into other_assignment_id from public.agency_item_assignments where agency_id=agency_b and item_id=tool;
 begin perform public.unassign_business_rule_assignment(agency_b,assignment_id,stamp);raise exception 'Cross-agency removal allowed';exception when raise_exception then if sqlerrm<>'This assignment is no longer available. Refresh records.' then raise;end if;end;
 begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,null);raise exception 'Missing version allowed';exception when raise_exception then if sqlerrm<>'Refresh records before unassigning this tool.' then raise;end if;end;
 old_stamp:=stamp;
 update public.agency_item_assignments set data_source='A revised feed' where id=assignment_id returning updated_at into stamp;
 begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,old_stamp);raise exception 'Stale removal allowed';exception when raise_exception then if sqlerrm<>'This assignment changed. Refresh records before unassigning it.' then raise;end if;end;
 update public.business_rules_agencies set active=false where id=agency_a;
 begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,stamp);raise exception 'Inactive agency removal allowed';exception when raise_exception then if sqlerrm<>'Choose an active business rules agency.' then raise;end if;end;
 delete from public.agency_item_assignments where id=assignment_id;get diagnostics n=row_count;if n<>0 then raise exception 'RLS allowed inactive agency removal';end if;
 update public.business_rules_agencies set active=true where id=agency_a;
 -- Role simulation is confined to this transaction and always rolled back.
 for test_role in select unnest(array['trainer','viewer']) loop
  execute 'reset role';update public.profiles set role=test_role where id=admin_id;execute 'set local role authenticated';
  begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,stamp);raise exception 'Read-only user removal allowed';exception when raise_exception then if sqlerrm<>'Administrator or Coordinator access is required.' then raise;end if;end;
  delete from public.agency_item_assignments where id=assignment_id;get diagnostics n=row_count;if n<>0 then raise exception 'RLS allowed read-only user removal';end if;
 end loop;
 execute 'reset role';update public.profiles set role='admin',active=false where id=admin_id;execute 'set local role authenticated';
 begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,stamp);raise exception 'Inactive account removal allowed';exception when raise_exception then if sqlerrm<>'Administrator or Coordinator access is required.' then raise;end if;end;
 execute 'reset role';update public.profiles set active=true where id=admin_id;execute 'set local role anon';
 begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,stamp);raise exception 'Anonymous RPC allowed';exception when insufficient_privilege then null;end;
 begin delete from public.agency_item_assignments where id=assignment_id;raise exception 'Anonymous direct delete allowed';exception when insufficient_privilege then null;end;
 execute 'reset role';perform set_config('request.jwt.claims',jsonb_build_object('sub',admin_id,'role','authenticated')::text,true);perform set_config('request.jwt.claim.sub',admin_id::text,true);execute 'set local role authenticated';
 if not public.unassign_business_rule_assignment(agency_a,assignment_id,stamp) then raise exception 'Administrator unassign failed';end if;
 if exists(select 1 from public.agency_item_assignments where id=assignment_id) then raise exception 'Assignment was not removed';end if;
 if not exists(select 1 from public.agency_item_assignments where id=other_assignment_id and data_source='B feed' and retention_value=90 and retention_unit='Days') then raise exception 'Other agency assignment changed';end if;
 if not exists(select 1 from public.agency_item_assignments where agency_id=agency_a and item_id=other_tool) then raise exception 'Other tool assignment changed';end if;
 if (select count(*) from public.resource_items where id in (tool,other_tool))<>2 then raise exception 'Catalog items changed';end if;
 begin perform public.unassign_business_rule_assignment(agency_a,assignment_id,stamp);raise exception 'Repeat removal accepted';exception when raise_exception then if sqlerrm<>'This assignment is no longer available. Refresh records.' then raise;end if;end;
 perform public.save_business_rule_assignments(agency_a,jsonb_build_array(jsonb_build_object('item_id',tool)));
 select id,updated_at into assignment_id,stamp from public.agency_item_assignments where agency_id=agency_a and item_id=tool;
 if assignment_id is null then raise exception 'Reassignment failed';end if;
 execute 'reset role';update public.profiles set role='coordinator' where id=admin_id;execute 'set local role authenticated';
 if not public.unassign_business_rule_assignment(agency_a,assignment_id,stamp) then raise exception 'Coordinator unassign failed';end if;
 execute 'reset role';
end $test$;
rollback;
select 'PASS: exact assignment removal, catalog and other agency preservation, reassigning, stale/missing version checks, inactive agency protection, manager/read-only/anonymous permissions. Fixtures rolled back.' as result;
