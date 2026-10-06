CREATE OR REPLACE FUNCTION public.issue_training_certificate(p_attendee_id uuid, p_actor uuid DEFAULT auth.uid())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  a public.training_attendees%rowtype;
  r public.training_requests%rowtype;
  c public.training_completion_records%rowtype;
  v_public uuid;
  v_num text;
  v_new boolean := false;
  v_trainer text;
  v_type text;
  v_date date;
begin
  select * into a from public.training_attendees where id=p_attendee_id for update;
  if a.id is null then raise exception 'Attendee not found.'; end if;
  if a.checked_in_at is null then raise exception 'Attendee must be checked in before a certificate can be issued.'; end if;
  if a.attendance_status='ineligible' then raise exception 'Attendee is not eligible for a certificate.'; end if;

  if a.certificate_public_id is null then
    select * into r from public.training_requests where id=a.request_id;
    select * into c from public.training_completion_records where request_id=a.request_id;
    select coalesce(full_name,email) into v_trainer from public.profiles where id=r.assigned_trainer_id;
    v_type := case when r.train_the_trainer then 'Train the Trainer Course (8 Hours)'
                   when r.refresher_course then 'Refresher Course'
                   when r.advanced_training then 'Advanced Training'
                   when r.basic_training then 'Basic Backtrace Search Techniques (4 Hours)'
                   else 'Backtrace Training' end;
    v_date := coalesce(c.actual_training_date,r.confirmed_date,r.preferred_date,current_date);

    v_new := true;
    v_public := gen_random_uuid();
    v_num := public.next_training_certificate_number();
    update public.training_attendees
      set attendance_status='completed',
          completion_confirmed_at=coalesce(completion_confirmed_at,now()),
          completion_confirmed_by=coalesce(completion_confirmed_by,p_actor),
          certificate_number=v_num,
          certificate_public_id=v_public,
          certificate_issued_at=now(),
          certificate_attendee_name_snapshot=a.full_name,
          certificate_agency_name_snapshot=coalesce(r.agency_name,a.agency_name),
          certificate_training_type_snapshot=v_type,
          certificate_training_date_snapshot=v_date,
          certificate_trainer_name_snapshot=coalesce(v_trainer,'Backtrace Trainer'),
          certificate_request_number_snapshot=r.request_number,
          certificate_total_minutes_snapshot=r.total_minutes,
          updated_at=now()
    where id=a.id;
  else
    return a.certificate_public_id;
  end if;
  if v_new then perform public.queue_training_certificate_email(a.id); end if;
  return v_public;
end;
$function$
