create sequence public.training_bug_ticket_sequence;
alter table public.training_bug_reports
 add column issue_number text not null default ('BT-BUG-'||lpad(nextval('public.training_bug_ticket_sequence')::text,6,'0')) unique,
 add column priority text not null default 'Normal' check(priority in ('Low','Normal','High','Critical')),
 add column assigned_to uuid references public.profiles(id) on delete set null,
 add column resolution_summary text check(resolution_summary is null or length(resolution_summary)<=2000);
grant usage on sequence public.training_bug_ticket_sequence to anon,authenticated;

create table public.training_bug_report_history(
 id uuid primary key default gen_random_uuid(),
 bug_report_id uuid not null references public.training_bug_reports(id) on delete cascade,
 actor_id uuid references public.profiles(id) on delete set null,
 action text not null,
 changes jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
create index training_bug_report_history_report_idx on public.training_bug_report_history(bug_report_id,created_at);
alter table public.training_bug_report_history enable row level security;
grant select on public.training_bug_report_history to authenticated;
create policy bug_history_admin_select on public.training_bug_report_history for select to authenticated
using(exists(select 1 from public.profiles where id=(select auth.uid()) and active and role='admin'));

create or replace function public.prepare_training_bug_report()
returns trigger language plpgsql set search_path = '' as $$
begin
 if tg_op='INSERT' then
 new.status:='Open';new.priority:='Normal';new.assigned_to:=null;new.admin_notes:=null;
 new.resolution_summary:=null;new.resolved_at:=null;new.resolved_by:=null;
 new.issue_number:='BT-BUG-'||lpad(nextval('public.training_bug_ticket_sequence')::text,6,'0');
 new.created_at:=now();new.updated_at:=now();
 else
 if (to_jsonb(new)-array['status','priority','assigned_to','admin_notes','resolution_summary','updated_at','resolved_at','resolved_by'])
 is distinct from (to_jsonb(old)-array['status','priority','assigned_to','admin_notes','resolution_summary','updated_at','resolved_at','resolved_by']) then
 raise exception 'Submitted report details and ticket number cannot be changed.';end if;
 if new.assigned_to is not null and not exists(select 1 from public.profiles where id=new.assigned_to and active and role in ('admin','coordinator')) then
 raise exception 'Choose an active administrator or coordinator as the issue owner.';end if;
 if new.status in ('Resolved','Closed') then
 if nullif(btrim(new.resolution_summary),'') is null then raise exception 'A resolution summary is required to resolve or close an issue.';end if;
 new.resolved_at:=coalesce(old.resolved_at,now());new.resolved_by:=coalesce(old.resolved_by,auth.uid());
 else new.resolved_at:=null;new.resolved_by:=null;end if;
 new.updated_at:=clock_timestamp();
 end if;
 return new;
end $$;
create trigger prepare_training_bug_report before insert or update on public.training_bug_reports
for each row execute function public.prepare_training_bug_report();

create or replace function public.audit_training_bug_report()
returns trigger language plpgsql security definer set search_path = '' as $$
declare delta jsonb:='{}'::jsonb;k text;
begin
 if tg_op='INSERT' then delta:=jsonb_build_object('status',jsonb_build_object('after',new.status));
 else
 foreach k in array array['status','priority','assigned_to','admin_notes','resolution_summary'] loop
 if to_jsonb(new)->k is distinct from to_jsonb(old)->k then
 delta:=delta||jsonb_build_object(k,jsonb_build_object('before',to_jsonb(old)->k,'after',to_jsonb(new)->k));
 end if;end loop;
 end if;
 if tg_op='INSERT' or delta<>'{}'::jsonb then
 insert into public.training_bug_report_history(bug_report_id,actor_id,action,changes)
 values(new.id,auth.uid(),case when tg_op='INSERT' then 'Submitted' else 'Updated' end,delta);
 end if;
 return new;
end $$;
create trigger audit_training_bug_report after insert or update on public.training_bug_reports
for each row execute function public.audit_training_bug_report();

create or replace function public.submit_training_bug_report(p_data jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v public.training_bug_reports%rowtype;v_version text;v_page text:=nullif(btrim(p_data->>'page_url'),'');
begin
 if auth.uid() is not null and not exists(select 1 from public.profiles where id=auth.uid() and active) then
 raise exception 'An active account is required.';end if;
 if v_page is not null and v_page !~ '^https://[a-zA-Z0-9.-]+(/[[:graph:]]*)?$' then raise exception 'Invalid reported page URL.';end if;
 select version into v_version from public.training_app_versions where is_current order by release_date desc limit 1;
 insert into public.training_bug_reports(source,component,summary,details,expected_behavior,contact_name,contact_email,reporter_user_id,page_url,user_agent,app_version)
 values(case when auth.uid() is null then 'request_form' else 'tracker' end,
 coalesce(nullif(btrim(p_data->>'component'),''),'Application problem'),btrim(p_data->>'summary'),btrim(p_data->>'details'),
 nullif(btrim(p_data->>'expected_behavior'),''),nullif(btrim(p_data->>'contact_name'),''),nullif(lower(btrim(p_data->>'contact_email')),''),
 auth.uid(),v_page,nullif(p_data->>'user_agent',''),v_version)
 returning * into v;
 return jsonb_build_object('id',v.id,'issue_number',v.issue_number,'status',v.status,'created_at',v.created_at);
end $$;
revoke all on function public.submit_training_bug_report(jsonb) from public;
grant execute on function public.submit_training_bug_report(jsonb) to anon,authenticated;

create or replace function public.get_my_training_bug_reports()
returns table(id uuid,issue_number text,summary text,status text,priority text,resolution_summary text,created_at timestamptz,updated_at timestamptz,resolved_at timestamptz)
language sql security definer set search_path = '' as $$
 select r.id,r.issue_number,r.summary,r.status,r.priority,r.resolution_summary,r.created_at,r.updated_at,r.resolved_at
 from public.training_bug_reports r where auth.uid() is not null and r.reporter_user_id=auth.uid()
 and exists(select 1 from public.profiles where id=auth.uid() and active)
 order by r.created_at desc;
$$;
revoke all on function public.get_my_training_bug_reports() from public,anon;
grant execute on function public.get_my_training_bug_reports() to authenticated;

create or replace function public.update_training_bug_report(p_id uuid,p_status text,p_priority text,p_assigned_to uuid,p_admin_notes text,p_resolution_summary text,p_expected_updated_at timestamptz)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.training_bug_reports%rowtype;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active and role='admin') then
 raise exception 'Administrator access is required.';end if;
 select * into r from public.training_bug_reports where id=p_id for update;
 if not found then raise exception 'Bug report not found.';end if;
 if p_expected_updated_at is null or r.updated_at is distinct from p_expected_updated_at then
 raise exception 'This report changed since it was opened. Refresh before saving.';end if;
 update public.training_bug_reports set status=p_status,priority=p_priority,assigned_to=p_assigned_to,
 admin_notes=nullif(btrim(p_admin_notes),''),resolution_summary=nullif(btrim(p_resolution_summary),'') where id=p_id
 returning * into r;
 return jsonb_build_object('id',r.id,'issue_number',r.issue_number,'status',r.status,'updated_at',r.updated_at);
end $$;
revoke all on function public.update_training_bug_report(uuid,text,text,uuid,text,text,timestamptz) from public,anon;
grant execute on function public.update_training_bug_report(uuid,text,text,uuid,text,text,timestamptz) to authenticated;
revoke all on function public.prepare_training_bug_report() from public,anon,authenticated;
revoke all on function public.audit_training_bug_report() from public,anon,authenticated;
