-- Final Production UAT fixes: general public intake and notification action compatibility.
-- The general /request-training form intentionally works without a secure token.
create or replace function public.enforce_public_training_request_payload()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if new.submission_source <> 'public_request' then
    return new;
  end if;

  if length(coalesce(new.agency_name,'')) > 200
     or length(coalesce(new.agency_address,'')) > 500
     or length(coalesce(new.city_state_zip,'')) > 200
     or length(coalesce(new.contact_person,'')) > 180
     or length(coalesce(new.contact_phone,'')) > 80
     or length(coalesce(new.contact_email,'')) > 254
     or length(coalesce(new.trainer_contact_name,'')) > 180
     or length(coalesce(new.trainer_contact_phone,'')) > 80
     or length(coalesce(new.trainer_contact_email,'')) > 254
     or length(coalesce(new.training_location,'')) > 300
     or length(coalesce(new.requested_by,'')) > 180
     or length(coalesce(new.additional_requirements,'')) > 4000
  then
    raise exception 'One or more public training request fields exceed the allowed length.';
  end if;

  if new.contact_email is null
     or new.contact_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'A valid Contact Email is required.';
  end if;

  if new.trainer_contact_email is null
     or new.trainer_contact_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
    raise exception 'A valid Trainer Email is required.';
  end if;

  if new.estimated_attendees is not null
     and (new.estimated_attendees < 1 or new.estimated_attendees > 2000) then
    raise exception 'Estimated attendees must be between 1 and 2000.';
  end if;

  if cardinality(coalesce(new.training_resources,array[]::text[])) > 12 then
    raise exception 'Too many training resource selections.';
  end if;

  if exists (
    select 1
    from unnest(coalesce(new.training_resources,array[]::text[])) r
    where length(r) > 80
       or r not in (
         'Projector (No Cables)','Projector (With Cables)',
         'TV (HDMI Cable Needed)','TV (HDMI Cable Available)',
         'Wi-Fi','No Wi-Fi','Wi‑Fi','No Wi‑Fi',
         'Computer with Wi-Fi','Computer with Wi‑Fi'
       )
  ) then
    raise exception 'Invalid training resource selection.';
  end if;

  return new;
end;
$function$;

alter table public.training_notifications
drop constraint if exists training_notifications_action_url_integrity_check;

alter table public.training_notifications
add constraint training_notifications_action_url_integrity_check
check (
  action_url is null
  or action_url ~ '^/(requests(?:/edit)?|calendar|completions|classes|today|notifications|reports|agencies|agency-history|attendees|user-management|email-settings|version-history|health|activity|bug-reports)(\?.*)?$'
  or action_url ~ '^https://backtrace-training-admin\.vercel\.app/(requests(?:/edit)?|calendar|completions|classes|today|notifications|reports|agencies|agency-history|attendees|user-management|email-settings|version-history|health|activity|bug-reports)(\?.*)?$'
  or action_url ~ '^https://backtrace-training-tracker\.vercel\.app/(requests|calendar|completion|attendance|today|notifications|reports|agencies|agency-history|attendee-directory|users|email-settings|version-history|certificate)(\?.*)?$'
);
