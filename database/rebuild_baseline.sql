-- Reconstructed from the application contracts and saved SQL on 2026-10-15.
-- Fresh database only. Operational records and credentials are intentionally not seeded.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated,service_role;
create extension if not exists pgcrypto with schema extensions;
alter default privileges in schema public revoke execute on functions from public;
alter default privileges in schema private revoke execute on functions from public;
create sequence public.training_request_number_seq;
create sequence public.training_completion_number_seq;
create sequence public.training_certificate_number_seq;


create table public.profiles (
id uuid primary key references auth.users(id) on delete cascade,email text not null,full_name text,role text not null default 'viewer' check(role in ('admin','coordinator','trainer','viewer')),active boolean not null default false,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.profiles enable row level security;
revoke all on public.profiles from public,anon,authenticated;
grant all on public.profiles to service_role;

create table public.agencies (
id uuid primary key default gen_random_uuid(),agency_name text not null,agency_address text,city_state_zip text,contact_person text,contact_phone text,contact_email text,notes text,active boolean not null default true,created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.agencies enable row level security;
revoke all on public.agencies from public,anon,authenticated;
grant all on public.agencies to service_role;

create table public.public_training_request_links (
id uuid primary key default gen_random_uuid(),token_hash text not null unique,token_hint text,label text,active boolean not null default true,expires_at timestamptz,max_submissions integer,submission_count integer not null default 0,last_used_at timestamptz,created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.public_training_request_links enable row level security;
revoke all on public.public_training_request_links from public,anon,authenticated;
grant all on public.public_training_request_links to service_role;

create table public.agency_portal_links (
id uuid primary key default gen_random_uuid(),agency_id uuid references public.agencies(id),token_hash text not null unique,token_hint text,label text,active boolean not null default true,expires_at timestamptz,max_submissions integer,submission_count integer not null default 0,last_used_at timestamptz,created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.agency_portal_links enable row level security;
revoke all on public.agency_portal_links from public,anon,authenticated;
grant all on public.agency_portal_links to service_role;

create table public.training_requests (
id uuid primary key default gen_random_uuid(),
request_number text not null unique default ('BT-'||lpad(nextval('public.training_request_number_seq')::text,6,'0')),
agency_id uuid references public.agencies(id),
public_request_link_id uuid references public.public_training_request_links(id),
agency_portal_link_id uuid references public.agency_portal_links(id),
agency_name text,
agency_address text,
city_state_zip text,
contact_person text,
contact_phone text,
contact_email text,
trainer_contact_name text,
trainer_contact_email text,
trainer_contact_phone text,
requested_by text,
training_location text,
teams_meeting_url text,
objectives text,
topics text,
experience_level text,
outcomes text,
additional_requirements text,
internal_notes text,
training_format text not null default 'In Person' check(training_format in ('In Person','Virtual','Hybrid')),
status text not null default 'Received',
class_status text not null default 'Draft' check(class_status in ('Draft','Scheduled','Registration Open','In Progress','Closed','Completed','Archived')),
time_zone text default 'Eastern',
submission_source text not null default 'internal',
training_resources text[] not null default '{}',
estimated_attendees integer check(estimated_attendees>=0),
total_minutes integer not null default 0 check(total_minutes>=0),
assigned_trainer_id uuid references public.profiles(id),
basic_training boolean not null default false,
train_the_trainer boolean not null default false,
refresher_course boolean not null default false,
advanced_training boolean not null default false,
preferred_date date,
alternate_date date,
confirmed_date date,
preferred_start_time time,
preferred_end_time time,
confirmed_start_time time,
archived_at timestamptz,
completed_at timestamptz,
scheduled_at timestamptz,
class_started_at timestamptz,
class_closed_at timestamptz,
archived_by uuid references public.profiles(id),
scheduled_by uuid references public.profiles(id),
class_started_by uuid references public.profiles(id),
class_closed_by uuid references public.profiles(id),
created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),
created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_requests enable row level security;
revoke all on public.training_requests from public,anon,authenticated;
grant all on public.training_requests to service_role;

create table public.training_modules (
id bigint generated by default as identity primary key,category text not null,module_name text not null,duration_minutes integer not null check(duration_minutes>0),sort_order integer not null default 0,active boolean not null default true,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_modules enable row level security;
revoke all on public.training_modules from public,anon,authenticated;
grant all on public.training_modules to service_role;

create table public.request_modules (
request_id uuid references public.training_requests(id) on delete cascade,module_id bigint references public.training_modules(id),primary key(request_id,module_id)
);
alter table public.request_modules enable row level security;
revoke all on public.request_modules from public,anon,authenticated;
grant all on public.request_modules to service_role;

create table public.training_request_activity (
id uuid primary key default gen_random_uuid(),request_id uuid references public.training_requests(id) on delete cascade,actor_id uuid references public.profiles(id) on delete set null,action text not null,details jsonb not null default '{}',created_at timestamptz not null default now()
);
alter table public.training_request_activity enable row level security;
revoke all on public.training_request_activity from public,anon,authenticated;
grant all on public.training_request_activity to service_role;

create table public.user_management_activity (
id uuid primary key default gen_random_uuid(),target_user_id uuid references public.profiles(id) on delete set null,actor_id uuid references public.profiles(id) on delete set null,action text not null,details jsonb not null default '{}',created_at timestamptz not null default now()
);
alter table public.user_management_activity enable row level security;
revoke all on public.user_management_activity from public,anon,authenticated;
grant all on public.user_management_activity to service_role;

create table public.administration_activity (
id uuid primary key default gen_random_uuid(),category text,entity_type text,entity_id text,subject text,actor_id uuid references public.profiles(id) on delete set null,action text not null,details jsonb not null default '{}',created_at timestamptz not null default now()
);
alter table public.administration_activity enable row level security;
revoke all on public.administration_activity from public,anon,authenticated;
grant all on public.administration_activity to service_role;

create table public.training_notifications (
id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id) on delete cascade,request_id uuid references public.training_requests(id) on delete cascade,notification_type text,title text not null,message text,severity text default 'info',action_url text,dedupe_key text,read_at timestamptz,created_at timestamptz not null default now(),unique(user_id,dedupe_key)
);
alter table public.training_notifications enable row level security;
revoke all on public.training_notifications from public,anon,authenticated;
grant all on public.training_notifications to service_role;

create table public.training_people (
id uuid primary key default gen_random_uuid(),agency_name text,badge_id text,full_name text not null,email text not null,title_position text,first_seen_at timestamptz not null default now(),last_seen_at timestamptz not null default now()
);
alter table public.training_people enable row level security;
revoke all on public.training_people from public,anon,authenticated;
grant all on public.training_people to service_role;

create table public.training_attendance_sessions (
id uuid primary key default gen_random_uuid(),request_id uuid not null unique references public.training_requests(id) on delete cascade,token_hash text unique,token_hint text,active boolean not null default true,registration_open boolean not null default true,checkin_open_at timestamptz,checkin_close_at timestamptz,created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now(),check(checkin_close_at is null or checkin_open_at is null or checkin_close_at>=checkin_open_at)
);
alter table public.training_attendance_sessions enable row level security;
revoke all on public.training_attendance_sessions from public,anon,authenticated;
grant all on public.training_attendance_sessions to service_role;

create table public.training_attendees (
id uuid primary key default gen_random_uuid(),request_id uuid not null references public.training_requests(id) on delete cascade,session_id uuid references public.training_attendance_sessions(id) on delete cascade,person_id uuid references public.training_people(id),agency_name text,full_name text not null,email text not null,badge_id text,title_position text,registered_at timestamptz not null default now(),checked_in_at timestamptz,attendance_status text not null default 'registered' check(attendance_status in ('registered','checked_in','completed','ineligible')),completion_confirmed_at timestamptz,completion_confirmed_by uuid references public.profiles(id),certificate_number text unique,certificate_public_id uuid unique,certificate_issued_at timestamptz,certificate_attendee_name_snapshot text,certificate_agency_name_snapshot text,certificate_training_type_snapshot text,certificate_training_date_snapshot date,certificate_trainer_name_snapshot text,certificate_request_number_snapshot text,certificate_total_minutes_snapshot integer,created_at timestamptz not null default now(), updated_at timestamptz not null default now(),unique(request_id,email)
);
alter table public.training_attendees enable row level security;
revoke all on public.training_attendees from public,anon,authenticated;
grant all on public.training_attendees to service_role;

create table public.training_completion_records (
id uuid primary key default gen_random_uuid(),request_id uuid not null unique references public.training_requests(id) on delete cascade,completion_number text not null unique default ('BT-COMP-'||lpad(nextval('public.training_completion_number_seq')::text,6,'0')),record_status text not null default 'Draft' check(record_status in ('Draft','Finalized')),actual_training_date date,actual_start_time time,actual_end_time time,actual_minutes integer,actual_attendees integer,basic_training_completed boolean default false,trainer_notes text,follow_up_required boolean default false,follow_up_notes text,agency_feedback_score integer,agency_feedback_notes text,finalized_at timestamptz,finalized_by uuid references public.profiles(id),created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_completion_records enable row level security;
revoke all on public.training_completion_records from public,anon,authenticated;
grant all on public.training_completion_records to service_role;

create table public.training_completion_modules (
request_id uuid references public.training_requests(id) on delete cascade,module_id bigint references public.training_modules(id),primary key(request_id,module_id)
);
alter table public.training_completion_modules enable row level security;
revoke all on public.training_completion_modules from public,anon,authenticated;
grant all on public.training_completion_modules to service_role;

create table public.training_email_provider_settings (
id integer primary key check(id=1),provider text not null default 'resend',enabled boolean not null default false,api_key text,from_email text default 'no-reply@training.gtbm.com',from_name text default 'Backtrace Training',enabled_at timestamptz,webhook_enabled boolean not null default false,webhook_secret text,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_email_provider_settings enable row level security;
revoke all on public.training_email_provider_settings from public,anon,authenticated;
grant all on public.training_email_provider_settings to service_role;

create table public.training_email_tracking_state (
id integer primary key check(id=1),enabled boolean not null default false
);
alter table public.training_email_tracking_state enable row level security;
revoke all on public.training_email_tracking_state from public,anon,authenticated;
grant all on public.training_email_tracking_state to service_role;

create table public.training_email_queue (
id bigint generated by default as identity primary key,notification_id uuid references public.training_notifications(id) on delete set null,recipient_email text not null,subject text not null,text_body text,html_body text,status text not null default 'pending',attempts integer not null default 0,next_attempt_at timestamptz,queued_at timestamptz not null default now(),sent_at timestamptz,last_error text,provider_message_id text,dedupe_key text unique,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_email_queue enable row level security;
revoke all on public.training_email_queue from public,anon,authenticated;
grant all on public.training_email_queue to service_role;

create table public.training_email_delivery_events (
id uuid primary key default gen_random_uuid(),queue_id bigint references public.training_email_queue(id),event_type text,recipient_email text,event_at timestamptz not null default now(),payload jsonb
);
alter table public.training_email_delivery_events enable row level security;
revoke all on public.training_email_delivery_events from public,anon,authenticated;
grant all on public.training_email_delivery_events to service_role;

create table public.training_certificate_email_deliveries (
id uuid primary key default gen_random_uuid(),attendee_id uuid references public.training_attendees(id) on delete cascade,email_queue_id bigint references public.training_email_queue(id),created_at timestamptz not null default now()
);
alter table public.training_certificate_email_deliveries enable row level security;
revoke all on public.training_certificate_email_deliveries from public,anon,authenticated;
grant all on public.training_certificate_email_deliveries to service_role;

create table public.training_app_versions (
id uuid primary key default gen_random_uuid(),version text unique not null,release_date date,title text,summary text,is_current boolean default false,initial_problem text,fix_summary text,verification_summary text,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_app_versions enable row level security;
revoke all on public.training_app_versions from public,anon,authenticated;
grant all on public.training_app_versions to service_role;

create table public.training_app_version_changes (
id uuid primary key default gen_random_uuid(),version_id uuid references public.training_app_versions(id) on delete cascade,component text,change_summary text,sort_order integer default 0
);
alter table public.training_app_version_changes enable row level security;
revoke all on public.training_app_version_changes from public,anon,authenticated;
grant all on public.training_app_version_changes to service_role;

create table public.training_manual_versions (
id uuid primary key default gen_random_uuid(),version text unique,content text,active boolean default false,published_at timestamptz,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_manual_versions enable row level security;
revoke all on public.training_manual_versions from public,anon,authenticated;
grant all on public.training_manual_versions to service_role;

create table public.training_bug_reports (
id uuid primary key default gen_random_uuid(),source text,component text,summary text not null check(length(btrim(summary)) between 3 and 250),details text not null check(length(details) between 3 and 10000),expected_behavior text,contact_name text,contact_email text,reporter_user_id uuid references public.profiles(id),page_url text,user_agent text,app_version text,status text not null default 'Open' check(status in ('Open','In Progress','Resolved','Closed')),admin_notes text,resolved_at timestamptz,resolved_by uuid references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_bug_reports enable row level security;
revoke all on public.training_bug_reports from public,anon,authenticated;
grant all on public.training_bug_reports to service_role;

create table public.training_products (
id uuid primary key default gen_random_uuid(),name text not null,active boolean default true,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_products enable row level security;
revoke all on public.training_products from public,anon,authenticated;
grant all on public.training_products to service_role;

create table public.training_product_modules (
id uuid primary key default gen_random_uuid(),product_id uuid references public.training_products(id),code text,name text not null,active boolean default true,sort_order integer default 0,created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_product_modules enable row level security;
revoke all on public.training_product_modules from public,anon,authenticated;
grant all on public.training_product_modules to service_role;

create table public.training_jurisdictions (
id uuid primary key default gen_random_uuid(),code text unique,name text not null
);
alter table public.training_jurisdictions enable row level security;
revoke all on public.training_jurisdictions from public,anon,authenticated;
grant all on public.training_jurisdictions to service_role;

create table public.training_materials (
id uuid primary key default gen_random_uuid(),product_id uuid references public.training_products(id),module_id uuid references public.training_product_modules(id),title text not null,description text,material_type text,audience text not null default 'student' check(audience in ('student','trainer','internal')),active boolean default true,created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_materials enable row level security;
revoke all on public.training_materials from public,anon,authenticated;
grant all on public.training_materials to service_role;

create table public.training_material_versions (
id uuid primary key default gen_random_uuid(),material_id uuid references public.training_materials(id) on delete cascade,version_label text,effective_date date,status text not null default 'draft',is_current boolean default false,storage_path text,original_filename text,mime_type text,file_size bigint,media_kind text,download_allowed boolean default true,notes text,created_by uuid default auth.uid() references public.profiles(id), updated_by uuid default auth.uid() references public.profiles(id),created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.training_material_versions enable row level security;
revoke all on public.training_material_versions from public,anon,authenticated;
grant all on public.training_material_versions to service_role;

create table public.training_material_jurisdictions (
material_id uuid references public.training_materials(id) on delete cascade,jurisdiction_id uuid references public.training_jurisdictions(id),primary key(material_id,jurisdiction_id)
);
alter table public.training_material_jurisdictions enable row level security;
revoke all on public.training_material_jurisdictions from public,anon,authenticated;
grant all on public.training_material_jurisdictions to service_role;

create table public.training_class_materials (
request_id uuid references public.training_requests(id) on delete cascade,material_version_id uuid references public.training_material_versions(id),attached_by uuid references public.profiles(id),created_at timestamptz default now(),primary key(request_id,material_version_id)
);
alter table public.training_class_materials enable row level security;
revoke all on public.training_class_materials from public,anon,authenticated;
grant all on public.training_class_materials to service_role;

create table public.training_material_share_links (
id uuid primary key default gen_random_uuid(),token_hash text not null unique,request_id uuid references public.training_requests(id) on delete cascade,recipient_email text,expires_at timestamptz,active boolean default true,created_by uuid references public.profiles(id),created_at timestamptz default now()
);
alter table public.training_material_share_links enable row level security;
revoke all on public.training_material_share_links from public,anon,authenticated;
grant all on public.training_material_share_links to service_role;

create table public.training_material_share_items (
share_id uuid references public.training_material_share_links(id) on delete cascade,material_version_id uuid references public.training_material_versions(id),sort_order integer default 0,primary key(share_id,material_version_id)
);
alter table public.training_material_share_items enable row level security;
revoke all on public.training_material_share_items from public,anon,authenticated;
grant all on public.training_material_share_items to service_role;

create table public.training_material_access_events (
id uuid primary key default gen_random_uuid(),share_id uuid references public.training_material_share_links(id) on delete cascade,material_version_id uuid references public.training_material_versions(id),event_type text,created_at timestamptz default now()
);
alter table public.training_material_access_events enable row level security;
revoke all on public.training_material_access_events from public,anon,authenticated;
grant all on public.training_material_access_events to service_role;

create table public.training_material_distributions (
id uuid primary key default gen_random_uuid(),request_id uuid references public.training_requests(id) on delete cascade,share_id uuid references public.training_material_share_links(id) on delete cascade,attendee_id uuid references public.training_attendees(id),recipient_email text,email_queue_id bigint references public.training_email_queue(id),created_by uuid references public.profiles(id),created_at timestamptz default now()
);
alter table public.training_material_distributions enable row level security;
revoke all on public.training_material_distributions from public,anon,authenticated;
grant all on public.training_material_distributions to service_role;

create table public.training_signin_ingests (
id uuid primary key default gen_random_uuid(),request_id uuid references public.training_requests(id) on delete cascade,payload jsonb,created_by uuid references public.profiles(id),created_at timestamptz default now()
);
alter table public.training_signin_ingests enable row level security;
revoke all on public.training_signin_ingests from public,anon,authenticated;
grant all on public.training_signin_ingests to service_role;


-- Role lookup is kept outside the exposed API schema. No self-service role updates.
create function private.current_role() returns text language sql stable security definer set search_path='' as $$
 select role from public.profiles where id=auth.uid() and active $$;
revoke all on function private.current_role() from public,anon;
grant execute on function private.current_role() to authenticated,service_role;
create function public.current_user_role() returns text language sql stable set search_path='' as $$select private.current_role()$$;
create function public.is_active_user() returns boolean language sql stable set search_path='' as $$select coalesce(private.current_role() in ('admin','coordinator','trainer','viewer'),false)$$;
create function public.is_manager() returns boolean language sql stable set search_path='' as $$select coalesce(private.current_role() in ('admin','coordinator'),false)$$;
create function public.can_manage_training_materials() returns boolean language sql stable set search_path='' as $$select coalesce(private.current_role() in ('admin','coordinator','trainer'),false)$$;
create function public.can_edit_request(p_request_id uuid) returns boolean language sql stable set search_path='' as $$select public.is_manager() or exists(select 1 from public.training_requests where id=p_request_id and public.current_user_role()='trainer' and (created_by=auth.uid() or assigned_trainer_id=auth.uid()))$$;
grant execute on function public.current_user_role(),public.is_active_user(),public.is_manager(),public.can_manage_training_materials(),public.can_edit_request(uuid) to authenticated,service_role;
grant select on public.profiles to authenticated;
create policy profiles_read on public.profiles for select to authenticated using (id=(select auth.uid()) or (select public.is_active_user()));
create function private.create_profile() returns trigger language plpgsql security definer set search_path='' as $$begin
 insert into public.profiles(id,email,full_name,role,active) values(new.id,new.email,new.raw_user_meta_data->>'full_name','viewer',false);return new;end$$;
create trigger backtrace_auth_profile after insert on auth.users for each row execute function private.create_profile();


grant select on public.agencies to authenticated;
create policy active_read on public.agencies for select to authenticated using ((select public.is_active_user()));

grant select on public.training_requests to authenticated;
create policy active_read on public.training_requests for select to authenticated using ((select public.is_active_user()));

grant select on public.training_modules to authenticated;
create policy active_read on public.training_modules for select to authenticated using ((select public.is_active_user()));

grant select on public.request_modules to authenticated;
create policy active_read on public.request_modules for select to authenticated using ((select public.is_active_user()));

grant select on public.training_products to authenticated;
create policy active_read on public.training_products for select to authenticated using ((select public.is_active_user()));

grant select on public.training_product_modules to authenticated;
create policy active_read on public.training_product_modules for select to authenticated using ((select public.is_active_user()));

grant select on public.training_jurisdictions to authenticated;
create policy active_read on public.training_jurisdictions for select to authenticated using ((select public.is_active_user()));

grant select on public.training_app_versions to authenticated;
create policy active_read on public.training_app_versions for select to authenticated using ((select public.is_active_user()));

grant select on public.training_app_version_changes to authenticated;
create policy active_read on public.training_app_version_changes for select to authenticated using ((select public.is_active_user()));

grant select on public.training_manual_versions to authenticated;
create policy active_read on public.training_manual_versions for select to authenticated using ((select public.is_active_user()));

grant select on public.training_completion_records to authenticated;
create policy active_read on public.training_completion_records for select to authenticated using ((select public.is_active_user()));

grant insert,update on public.agencies to authenticated;create policy manager_insert on public.agencies for insert to authenticated with check((select public.is_manager()));create policy manager_update on public.agencies for update to authenticated using((select public.is_manager())) with check((select public.is_manager()));

grant insert,update on public.training_modules to authenticated;create policy manager_insert on public.training_modules for insert to authenticated with check((select public.is_manager()));create policy manager_update on public.training_modules for update to authenticated using((select public.is_manager())) with check((select public.is_manager()));

grant insert,update on public.training_products to authenticated;create policy manager_insert on public.training_products for insert to authenticated with check((select public.is_manager()));create policy manager_update on public.training_products for update to authenticated using((select public.is_manager())) with check((select public.is_manager()));

grant insert,update on public.training_product_modules to authenticated;create policy manager_insert on public.training_product_modules for insert to authenticated with check((select public.is_manager()));create policy manager_update on public.training_product_modules for update to authenticated using((select public.is_manager())) with check((select public.is_manager()));

grant insert,update on public.training_jurisdictions to authenticated;create policy manager_insert on public.training_jurisdictions for insert to authenticated with check((select public.is_manager()));create policy manager_update on public.training_jurisdictions for update to authenticated using((select public.is_manager())) with check((select public.is_manager()));

grant insert,update,delete on public.training_requests to authenticated;

grant insert,update,delete on public.request_modules to authenticated;

create policy request_insert on public.training_requests for insert to authenticated with check(public.current_user_role() in ('admin','coordinator','trainer') and created_by=auth.uid());
create policy request_update on public.training_requests for update to authenticated using(public.can_edit_request(id)) with check(public.can_edit_request(id));
create policy modules_write on public.request_modules for all to authenticated using(public.can_edit_request(request_id)) with check(public.can_edit_request(request_id));
grant select,update(read_at) on public.training_notifications to authenticated;
create policy notification_read on public.training_notifications for select to authenticated using(user_id=auth.uid() and public.is_active_user());
create policy notification_update on public.training_notifications for update to authenticated using(user_id=auth.uid() and public.is_active_user()) with check(user_id=auth.uid() and public.is_active_user());


grant select on public.user_management_activity to authenticated;create policy admin_read on public.user_management_activity for select to authenticated using((select public.current_user_role())='admin');

grant select on public.administration_activity to authenticated;create policy admin_read on public.administration_activity for select to authenticated using((select public.current_user_role())='admin');

grant select on public.training_bug_reports to authenticated;create policy admin_read on public.training_bug_reports for select to authenticated using((select public.current_user_role())='admin');

grant select,insert on public.training_request_activity to authenticated;create policy request_activity_read on public.training_request_activity for select to authenticated using(public.is_active_user());create policy request_activity_insert on public.training_request_activity for insert to authenticated with check(actor_id=auth.uid() and public.can_edit_request(request_id));

grant select,insert,update,delete on public.training_materials to authenticated;create policy materials_read on public.training_materials for select to authenticated using((select public.can_manage_training_materials()));create policy materials_write on public.training_materials for all to authenticated using((select public.can_manage_training_materials())) with check((select public.can_manage_training_materials()));

grant select,insert,update,delete on public.training_material_versions to authenticated;create policy materials_read on public.training_material_versions for select to authenticated using((select public.can_manage_training_materials()));create policy materials_write on public.training_material_versions for all to authenticated using((select public.can_manage_training_materials())) with check((select public.can_manage_training_materials()));

grant select,insert,update,delete on public.training_material_jurisdictions to authenticated;create policy materials_read on public.training_material_jurisdictions for select to authenticated using((select public.can_manage_training_materials()));create policy materials_write on public.training_material_jurisdictions for all to authenticated using((select public.can_manage_training_materials())) with check((select public.can_manage_training_materials()));

grant select,insert,update,delete on public.training_class_materials to authenticated;create policy materials_read on public.training_class_materials for select to authenticated using((select public.can_manage_training_materials()));create policy materials_write on public.training_class_materials for all to authenticated using((select public.can_manage_training_materials())) with check((select public.can_manage_training_materials()));

grant usage,select on all sequences in schema public to authenticated,service_role;
insert into public.training_email_provider_settings(id) values(1);
insert into public.training_email_tracking_state(id) values(1);
-- All emails remain disabled until the provider credentials are restored.
notify pgrst,'reload schema';
