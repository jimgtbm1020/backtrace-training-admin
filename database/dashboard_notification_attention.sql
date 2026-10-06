create or replace function public.get_dashboard_notification_attention()
returns jsonb language plpgsql stable security invoker set search_path='' as $function$
declare v_role text;
begin
  v_role := public.current_user_role();
  if auth.uid() is null or v_role is null or v_role not in ('admin','trainer') then
    raise exception 'An active administrator or trainer account is required.';
  end if;
  return (
    with owned as materialized (
      select n.*, r.assigned_trainer_id,r.trainer_response,r.confirmed_date,r.confirmed_start_time,
        r.created_at as request_created_at,r.total_minutes,
        r.id is not null and r.archived_at is null
          and lower(coalesce(r.status,'')) not in ('completed','closed','archived','cancelled','finalized')
          and lower(coalesce(r.class_status,'')) not in ('closed','completed','archived','cancelled','finalized') as live_request,
        r.class_status,
        coalesce((select name from pg_catalog.pg_timezone_names where name=r.time_zone limit 1),'America/New_York') as zone
      from public.training_notifications n
      left join public.training_requests r on r.id=n.request_id
      where n.user_id=auth.uid()
    ), classified as materialized (
      select o.*,
        coalesce(o.live_request and case
          when o.notification_type='assignment' then
            (v_role='trainer' and o.assigned_trainer_id=auth.uid() and o.trainer_response='Pending' and o.class_status<>'In Progress')
            or (v_role='admin' and o.trainer_response='Declined')
          when o.notification_type='unassigned' then v_role='admin' and o.assigned_trainer_id is null
          when o.notification_type='unscheduled' then v_role='admin' and o.confirmed_date is null
          when o.notification_type='schedule_conflict' then exists (
            select 1 from public.training_requests other
            where other.id<>o.request_id and other.assigned_trainer_id=o.assigned_trainer_id
              and other.confirmed_date=o.confirmed_date and other.archived_at is null
              and lower(other.status) not in ('completed','closed','archived','cancelled','finalized')
              and lower(other.class_status) not in ('closed','completed','archived','cancelled','finalized')
              and other.confirmed_start_time is not null and o.confirmed_start_time is not null
              and other.total_minutes>0 and o.total_minutes>0
              and (o.confirmed_date+o.confirmed_start_time)<(other.confirmed_date+other.confirmed_start_time)+pg_catalog.make_interval(mins=>other.total_minutes)
              and (other.confirmed_date+other.confirmed_start_time)<(o.confirmed_date+o.confirmed_start_time)+pg_catalog.make_interval(mins=>o.total_minutes)
          )
          else false end,false) as action_pending,
        case
          when o.notification_type='unassigned' then o.request_created_at+interval '24 hours'
          when o.notification_type='unscheduled' then o.request_created_at+interval '72 hours'
          when o.notification_type in ('assignment','schedule_conflict') and o.confirmed_date is not null
            then (o.confirmed_date+coalesce(o.confirmed_start_time,time '23:59:59')) at time zone o.zone
          else null end as due_at
      from owned o
    ), attention as materialized (
      select c.*,coalesce(c.action_pending and c.due_at<now(),false) as overdue,
        case when c.action_pending and c.notification_type='assignment' and v_role='trainer' then '/trainer-workspace'
          when c.action_pending and c.notification_type='schedule_conflict' then '/calendar?request='||c.request_id::text
          when c.action_pending then '/requests/edit?request='||c.request_id::text
          else c.action_url end as dashboard_action_url
      from classified c where c.read_at is null or c.action_pending
    ), latest as (
      select id,request_id,notification_type,title,message,severity,read_at,created_at,action_pending,overdue,due_at,dashboard_action_url as action_url
      from attention order by created_at desc,id desc limit 5
    )
    select pg_catalog.jsonb_build_object(
      'attention_count',(select count(*) from attention),
      'unread_count',(select count(*) from classified where read_at is null),
      'open_action_count',(select count(*) from classified where action_pending),
      'overdue_count',(select count(*) from attention where overdue),
      'items',coalesce((select pg_catalog.jsonb_agg(pg_catalog.to_jsonb(l) order by l.created_at desc,l.id desc) from latest l),'[]'::jsonb)
    )
  );
end $function$;
revoke all on function public.get_dashboard_notification_attention() from public,anon;
grant execute on function public.get_dashboard_notification_attention() to authenticated;
comment on function public.get_dashboard_notification_attention() is 'Own notifications for active administrators/trainers under RLS; unresolved workflow actions remain independent of read status. Read-only, no reminders or outgoing email generated.';
