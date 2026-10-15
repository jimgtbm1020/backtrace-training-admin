-- These helpers are server-only. Edge handlers authenticate bearer links before returning data.
create table private.password_reset_requests(email_hash text not null,ip_hash text not null,created_at timestamptz not null default now());
alter table private.password_reset_requests enable row level security;
revoke all on private.password_reset_requests from public,anon,authenticated;
grant select,insert,delete on private.password_reset_requests to service_role;
create index password_reset_created_idx on private.password_reset_requests(created_at);
create function public.claim_password_reset(p_email text,p_ip text) returns boolean language plpgsql set search_path='' as $$declare e text:=encode(extensions.digest(lower(p_email),'sha256'),'hex');i text:=encode(extensions.digest(p_ip,'sha256'),'hex');begin
 perform pg_advisory_xact_lock(7221491);
 delete from private.password_reset_requests where created_at<now()-interval '2 hours';
 if (select count(*) from private.password_reset_requests where created_at>now()-interval '1 hour')>=50 or (select count(*) from private.password_reset_requests where email_hash=e and created_at>now()-interval '1 hour')>=3 or (select count(*) from private.password_reset_requests where ip_hash=i and created_at>now()-interval '1 hour')>=10 then return false;end if;
 insert into private.password_reset_requests(email_hash,ip_hash) values(e,i);return true;end$$;
create function public.agency_portal_action(p_token text,p_action text,p_data jsonb default '{}',p_module_ids bigint[] default '{}') returns jsonb language plpgsql set search_path='' as $$declare l public.agency_portal_links%rowtype;a public.agencies%rowtype;r jsonb;begin
 if not public.is_canonical_training_token(p_token) then raise exception 'Invalid portal link';end if;
 select * into l from public.agency_portal_links where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or not l.active or l.expires_at<=now() or l.submission_count>=l.max_submissions then raise exception 'Portal link expired or unavailable';end if;
 select * into a from public.agencies where id=l.agency_id and active;
 if not found then raise exception 'Agency unavailable';end if;
 if p_action='validate' then return jsonb_build_object('agency',jsonb_build_object('agency_name',a.agency_name,'agency_address',a.agency_address,'city_state_zip',a.city_state_zip),'modules',coalesce((select jsonb_agg(jsonb_build_object('id',id,'module_name',module_name,'category',category,'duration_minutes',duration_minutes)) from public.training_modules where active),'[]'));end if;
 if p_action<>'submit' then raise exception 'Invalid action';end if;
 r:=public.submit_public_training_request(null,p_data||jsonb_build_object('agency_name',a.agency_name,'agency_address',a.agency_address,'city_state_zip',a.city_state_zip),p_module_ids);
 update public.training_requests set agency_id=a.id,agency_portal_link_id=l.id,submission_source='agency_portal',created_by=l.created_by where id=(r->>'id')::uuid;
 update public.agency_portal_links set submission_count=submission_count+1,last_used_at=now() where id=l.id;
 return jsonb_build_object('request',r);end$$;
create function public.public_attendance_action(p_token text,p_data jsonb default null) returns jsonb language plpgsql set search_path='' as $$declare s public.training_attendance_sessions%rowtype;r public.training_requests%rowtype;a public.training_attendees%rowtype;pid uuid;em text:=lower(trim(p_data->>'email'));nm text:=trim(p_data->>'full_name');badge text:=trim(p_data->>'badge_id');begin
 if not public.is_canonical_training_token(p_token) then raise exception 'Invalid attendance link';end if;
 select * into s from public.training_attendance_sessions where token_hash=encode(extensions.digest(p_token,'sha256'),'hex') for update;
 if not found or not s.active then raise exception 'Attendance link is closed or unavailable';end if;
 select * into r from public.training_requests where id=s.request_id for update;
 if r.class_status in ('Closed','Completed','Archived') then raise exception 'Class is closed';end if;
 if p_data is null then return jsonb_build_object('agency_name',r.agency_name,'request_number',r.request_number,'confirmed_date',r.confirmed_date,'class_status',r.class_status,'registration_open',s.registration_open);end if;
 if coalesce(length(nm),0)<2 or coalesce(position('@' in em),0)<2 or nullif(badge,'') is null then raise exception 'Enter your name, email and Badge / ID';end if;
 select * into a from public.training_attendees where request_id=r.id and lower(email)=em for update;
 if not found then
 if not s.registration_open then raise exception 'Registration is closed. Ask your trainer for assistance';end if;
 select id into pid from public.training_people where lower(email)=em and agency_name=r.agency_name limit 1;
 if pid is null then insert into public.training_people(agency_name,full_name,email,badge_id,title_position) values(r.agency_name,nm,em,badge,p_data->>'title_position') returning id into pid;end if;
 insert into public.training_attendees(request_id,session_id,person_id,agency_name,full_name,email,badge_id,title_position) values(r.id,s.id,pid,r.agency_name,nm,em,badge,p_data->>'title_position') returning * into a;
 elsif a.badge_id is distinct from badge then raise exception 'Details do not match your registration';end if;
 if r.class_status='In Progress' and (s.checkin_open_at is null or s.checkin_open_at<=now()) and (s.checkin_close_at is null or s.checkin_close_at>=now()) then
 update public.training_attendees set checked_in_at=coalesce(checked_in_at,now()),attendance_status=case when attendance_status='registered' then 'checked_in' else attendance_status end where id=a.id;
 return jsonb_build_object('message','You are checked in.');end if;
 return jsonb_build_object('message','Your registration is saved. Return to this link when the trainer starts check-in.');end$$;
revoke all on function public.claim_password_reset(text,text),public.agency_portal_action(text,text,jsonb,bigint[]),public.public_attendance_action(text,jsonb) from public,anon,authenticated;
grant execute on function public.claim_password_reset(text,text),public.agency_portal_action(text,text,jsonb,bigint[]),public.public_attendance_action(text,jsonb) to service_role;
-- Private bucket: students receive short-lived signed URLs only after a valid share token.
insert into storage.buckets(id,name,public) values('training-materials','training-materials',false) on conflict(id) do nothing;
create policy training_material_files on storage.objects for all to authenticated using(bucket_id='training-materials' and public.can_manage_training_materials()) with check(bucket_id='training-materials' and public.can_manage_training_materials());
