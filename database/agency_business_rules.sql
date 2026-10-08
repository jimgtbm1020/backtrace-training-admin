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
