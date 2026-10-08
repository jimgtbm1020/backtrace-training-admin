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
