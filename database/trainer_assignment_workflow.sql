alter table public.training_requests
 add column trainer_response text not null default 'Pending' check (trainer_response in ('Pending','Accepted','Declined')),
 add column trainer_responded_at timestamptz,
 add column trainer_decline_reason text;

create or replace function public.guard_trainer_response_fields()
returns trigger language plpgsql set search_path = '' as $$
begin
 if current_user='authenticated' and (
 new.trainer_response is distinct from old.trainer_response or
 new.trainer_responded_at is distinct from old.trainer_responded_at or
 new.trainer_decline_reason is distinct from old.trainer_decline_reason) then
 raise exception 'Use the controlled trainer response workflow.';
 end if;
 if new.assigned_trainer_id is distinct from old.assigned_trainer_id then
 new.trainer_response:='Pending';new.trainer_responded_at:=null;new.trainer_decline_reason:=null;
 if old.class_status in ('Draft','Scheduled') then new.teams_meeting_url:=null;end if;
 end if;
 return new;
end $$;
create trigger trg_guard_trainer_response_fields before update on public.training_requests
for each row execute function public.guard_trainer_response_fields();

create or replace function public.respond_to_training_assignment(p_request_id uuid,p_response text,p_reason text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare r public.training_requests%rowtype;v_reason text:=nullif(btrim(p_reason),'');
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active and role='trainer') then
 raise exception 'An active trainer account is required.';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if not found or r.assigned_trainer_id is distinct from auth.uid() then
 raise exception 'Only the assigned trainer can respond to this request.';end if;
 if r.class_status in ('In Progress','Closed','Completed','Archived') or r.archived_at is not null or r.status='Completed' then
 raise exception 'This class is locked for trainer responses.';end if;
 if p_response is null or p_response not in ('Accepted','Declined') then raise exception 'Choose Accepted or Declined.';end if;
 if r.trainer_response=p_response then return jsonb_build_object('trainer_response',r.trainer_response);end if;
 if r.trainer_response<>'Pending' then raise exception 'This assignment has already been answered. Contact administration for reassignment.';end if;
 if p_response='Declined' and r.class_status='Registration Open' then raise exception 'Contact administration to decline a class with open registration.';end if;
 if p_response='Declined' and v_reason is null then raise exception 'A reason is required when declining.';end if;
 if length(coalesce(v_reason,''))>1000 then raise exception 'Keep the decline reason within 1000 characters.';end if;
 update public.training_requests set trainer_response=p_response,trainer_responded_at=now(),
 trainer_decline_reason=case when p_response='Declined' then v_reason else null end,updated_by=auth.uid() where id=r.id;
 insert into public.training_request_activity(request_id,actor_id,action,details)
 values(r.id,auth.uid(),'trainer_assignment_response',jsonb_build_object('response',p_response,'reason',case when p_response='Declined' then v_reason else null end));
 perform public.push_manager_notification(r.id,'assignment','Trainer Assignment '||p_response,
 r.request_number||' — '||r.agency_name||': assigned trainer '||lower(p_response)||' the request.',
 case when p_response='Declined' then 'warning' else 'success' end,
 '/requests/edit','trainer-response:'||r.id::text||':'||auth.uid()::text||':'||extract(epoch from now())::text);
 return jsonb_build_object('trainer_response',p_response);
end $$;

create or replace function public.set_training_request_teams_link(p_request_id uuid,p_url text)
returns void language plpgsql security definer set search_path = '' as $$
declare r public.training_requests%rowtype;v_new text:=nullif(btrim(coalesce(p_url,'')),'');v_host text;
begin
 if auth.uid() is null or not exists(select 1 from public.profiles where id=auth.uid() and active) then
 raise exception 'An active account is required.';end if;
 select * into r from public.training_requests where id=p_request_id for update;
 if not found then raise exception 'Training request not found.';end if;
 if not public.is_manager() and not (
 r.assigned_trainer_id is not distinct from auth.uid() and r.trainer_response='Accepted' and
 exists(select 1 from public.profiles where id=auth.uid() and active and role='trainer')) then
 raise exception 'Only managers or the assigned trainer after acceptance can update the Teams meeting link.';end if;
 if r.class_status in ('In Progress','Closed','Completed','Archived') or r.archived_at is not null or r.status='Completed' then
 raise exception 'This class is locked for Teams link updates.';end if;
 if v_new is not null and r.training_format not in ('Virtual','Hybrid') then
 raise exception 'A Teams meeting link can only be added to Virtual or Hybrid training.';end if;
 if v_new is not null then
 v_host:=lower(substring(v_new from '^https://([^/?#]+)(?:[/?#]|$)'));
 if v_host is null or v_host not in ('teams.microsoft.com','teams.live.com','teams.cloud.microsoft') then
 raise exception 'Enter a valid Microsoft Teams meeting link.';end if;
 if v_new ~ '[[:space:]]' then raise exception 'Enter a valid Microsoft Teams meeting link.';end if;
 end if;
 update public.training_requests set teams_meeting_url=v_new,updated_by=auth.uid() where id=r.id;
 if r.teams_meeting_url is distinct from v_new then
 insert into public.training_request_activity(request_id,actor_id,action,details)
 values(r.id,auth.uid(),case when v_new is null then 'teams_meeting_link_removed' else 'teams_meeting_link_updated' end,
 jsonb_build_object('previous_url',r.teams_meeting_url,'new_url',v_new));end if;
end $$;
revoke all on function public.respond_to_training_assignment(uuid,text,text) from public,anon;
grant execute on function public.respond_to_training_assignment(uuid,text,text) to authenticated;
revoke all on function public.set_training_request_teams_link(uuid,text) from public,anon;
grant execute on function public.set_training_request_teams_link(uuid,text) to authenticated;
revoke all on function public.guard_trainer_response_fields() from public,anon,authenticated;