-- Keep Past Training Classes aligned with timezone-aware class closure.
-- Archive membership is based on actual workflow state rather than UTC current_date.
create or replace function public.search_training_class_archive(
  p_search text default null::text,
  p_start_date date default null::date,
  p_end_date date default null::date,
  p_limit integer default 500
)
returns table(
  request_id uuid,
  request_number text,
  agency_name text,
  confirmed_date date,
  confirmed_start_time time without time zone,
  training_location text,
  training_format text,
  status text,
  total_minutes integer,
  trainer_name text,
  attendee_count bigint,
  checked_in_count bigint,
  completed_count bigint,
  certificate_count bigint,
  completion_number text,
  actual_training_date date,
  actual_minutes integer,
  actual_attendees integer
)
language sql
security definer
set search_path to 'public'
as $function$
  select
    r.id,r.request_number,r.agency_name,r.confirmed_date,r.confirmed_start_time,
    r.training_location,r.training_format,r.status,r.total_minutes,
    coalesce(p.full_name,p.email),
    count(a.id),
    count(a.id) filter(where a.checked_in_at is not null),
    count(a.id) filter(where a.attendance_status='completed'),
    count(a.id) filter(where a.certificate_public_id is not null),
    c.completion_number,c.actual_training_date,c.actual_minutes,c.actual_attendees
  from public.training_requests r
  left join public.profiles p on p.id=r.assigned_trainer_id
  left join public.training_attendees a on a.request_id=r.id
  left join public.training_completion_records c on c.request_id=r.id
  where public.is_active_user()
    and public.can_edit_request(r.id)
    and r.confirmed_date is not null
    and (
      r.status='Completed'
      or r.class_status in ('Closed','Completed','Archived')
      or c.record_status='Finalized'
    )
    and (p_start_date is null or coalesce(c.actual_training_date,r.confirmed_date) >= p_start_date)
    and (p_end_date is null or coalesce(c.actual_training_date,r.confirmed_date) <= p_end_date)
    and (
      coalesce(trim(p_search),'')=''
      or r.request_number ilike '%'||trim(p_search)||'%'
      or r.agency_name ilike '%'||trim(p_search)||'%'
      or coalesce(r.training_location,'') ilike '%'||trim(p_search)||'%'
      or coalesce(p.full_name,p.email,'') ilike '%'||trim(p_search)||'%'
      or exists(
        select 1
        from public.training_attendees ax
        where ax.request_id=r.id
          and (
            ax.full_name ilike '%'||trim(p_search)||'%'
            or ax.email ilike '%'||trim(p_search)||'%'
            or coalesce(ax.badge_id,'') ilike '%'||trim(p_search)||'%'
          )
      )
    )
  group by r.id,p.full_name,p.email,c.completion_number,c.actual_training_date,c.actual_minutes,c.actual_attendees
  order by coalesce(c.actual_training_date,r.confirmed_date) desc,r.confirmed_start_time desc nulls last
  limit greatest(1,least(coalesce(p_limit,500),2000));
$function$;
