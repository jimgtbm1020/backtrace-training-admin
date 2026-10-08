-- Run before the separation migration in the same rollback transaction.
do $$
declare a uuid;g uuid;i uuid;
begin
 select id into a from public.profiles where role='admin' and active limit 1;
 perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated')::text,true);perform set_config('request.jwt.claim.sub',a::text,true);
 insert into public.agencies(id,agency_name,agency_address,contact_person,contact_email,created_by,updated_by)
 values('00000000-0000-4000-8000-000000000124','Migration Rollback Agency','Preserved address','Private contact','migration@example.invalid',a,a) returning id into g;
 insert into public.resource_items(id,name,item_type,description,expected_outcome,created_by,updated_by) values('00000000-0000-4000-8000-000000000224','Migration Rollback Tool','Tool','Preserved description','Preserved outcome',a,a) returning id into i;
 insert into public.agency_item_assignments(id,agency_id,item_id,data_source,retention_value,retention_unit,created_by,updated_by) values('00000000-0000-4000-8000-000000000324',g,i,'Preserved source',123,'Days',a,a);
end $$;
