-- Assignment metadata is optional; existing values, RLS, and concurrency checks are preserved.
alter table public.agency_item_assignments
 alter column data_source drop not null,
 alter column retention_value drop not null,
 alter column retention_unit drop not null;

CREATE OR REPLACE FUNCTION public.save_business_rule_assignments(p_agency_id uuid, p_rows jsonb)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare r jsonb; old public.agency_item_assignments%rowtype; tool uuid; n integer:=0; source_value text; retention_text text; unit_value text;
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
  if jsonb_typeof(r)<>'object' then raise exception 'Each assignment must be an object.';end if;
  source_value:=nullif(btrim(r->>'data_source'),'');
  retention_text:=nullif(btrim(r->>'retention_value'),'');
  unit_value:=nullif(btrim(r->>'retention_unit'),'');
  if length(source_value)>250 then raise exception 'Data source must be 250 characters or fewer.';end if;
  if retention_text is not null then
   if retention_text !~ '^[0-9]+$' then raise exception 'Retention must be a whole number from 1 to 9999 when provided.';end if;
   if retention_text::numeric not between 1 and 9999 then raise exception 'Retention must be a whole number from 1 to 9999 when provided.';end if;
  end if;
  if unit_value is not null and unit_value not in ('Days','Months','Years') then raise exception 'Unit must be Days, Months, or Years when provided.';end if;
  perform id from public.resource_items where id=tool for key share;
  if not found then raise exception 'A selected tool is unavailable. Refresh records.';end if;
  select * into old from public.agency_item_assignments where agency_id=p_agency_id and item_id=tool for update;
  if found then
   if nullif(r->>'expected_updated_at','') is null or old.updated_at<>(r->>'expected_updated_at')::timestamptz then raise exception 'An assignment changed. No assignments saved. Clear selection, refresh records, and review again.';end if;
   update public.agency_item_assignments set data_source=source_value,retention_value=retention_text::integer,retention_unit=unit_value,updated_by=auth.uid() where id=old.id;
  else
   if nullif(r->>'expected_updated_at','') is not null then raise exception 'An assignment was removed. No assignments saved. Clear selection and refresh records.';end if;
   insert into public.agency_item_assignments(agency_id,item_id,data_source,retention_value,retention_unit) values(p_agency_id,tool,source_value,retention_text::integer,unit_value);
  end if;
  n:=n+1;
 end loop;
 return n;
exception when unique_violation then raise exception 'An assignment was added by another user. No assignments saved. Clear selection and refresh records.';
end $function$;
revoke all on function public.save_business_rule_assignments(uuid,jsonb) from public,anon;
grant execute on function public.save_business_rule_assignments(uuid,jsonb) to authenticated;
