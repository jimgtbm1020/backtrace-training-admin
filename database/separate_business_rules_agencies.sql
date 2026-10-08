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
