-- Extend the authenticated active-user read-only directory payload with attendance session summaries.
-- Direct session/attendee table RLS remains restricted; operational writes are unchanged.
create or replace function public.get_training_attendee_directory()
returns jsonb
language plpgsql
security definer
set search_path='public'
as $function$
begin
  if not public.is_active_user() then
    raise exception 'Active Backtrace account required.';
  end if;

  return jsonb_build_object(
    'people', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',p.id,'agency_name',p.agency_name,'badge_id',p.badge_id,'full_name',p.full_name,
        'email',p.email,'title_position',p.title_position,'first_seen_at',p.first_seen_at,'last_seen_at',p.last_seen_at
      ) order by lower(p.full_name),lower(p.email))
      from public.training_people p
    ),'[]'::jsonb),
    'attendance', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',a.id,'person_id',a.person_id,'request_id',a.request_id,'full_name',a.full_name,'email',a.email,
        'title_position',a.title_position,'badge_id',a.badge_id,'attendance_status',a.attendance_status,
        'certificate_number',a.certificate_number,'certificate_public_id',a.certificate_public_id,
        'registered_at',a.registered_at,'checked_in_at',a.checked_in_at
      ) order by a.registered_at,a.id)
      from public.training_attendees a
    ),'[]'::jsonb),
    'sessions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id',s.request_id,'active',s.active,'registration_open',s.registration_open,
        'checkin_open_at',s.checkin_open_at,'checkin_close_at',s.checkin_close_at
      ))
      from public.training_attendance_sessions s
    ),'[]'::jsonb),
    'requests', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',r.id,'request_number',r.request_number,'confirmed_date',r.confirmed_date,'status',r.status,
        'class_status',r.class_status,'basic_training',r.basic_training,'train_the_trainer',r.train_the_trainer,
        'refresher_course',r.refresher_course,'advanced_training',r.advanced_training
      ))
      from public.training_requests r
    ),'[]'::jsonb),
    'completions', coalesce((
      select jsonb_agg(jsonb_build_object(
        'request_id',c.request_id,'actual_training_date',c.actual_training_date,'record_status',c.record_status
      ))
      from public.training_completion_records c
    ),'[]'::jsonb)
  );
end;
$function$;

revoke all on function public.get_training_attendee_directory() from public, anon;
grant execute on function public.get_training_attendee_directory() to authenticated;
