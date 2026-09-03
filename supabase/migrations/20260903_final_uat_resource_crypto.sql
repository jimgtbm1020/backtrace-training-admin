-- Final Production UAT: fix Resource Library secure-link cryptographic calls.
-- pgcrypto functions are installed in the Supabase extensions schema, while these
-- SECURITY DEFINER functions intentionally lock search_path to public.

create or replace function public.create_training_material_share(
  p_request_id uuid,
  p_material_version_ids uuid[],
  p_expires_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare tok text; h text; sid uuid; cnt integer; d integer;
begin
  if auth.uid() is null or not public.can_manage_training_materials() then raise exception 'Not authorized'; end if;
  if p_request_id is not null and not public.can_edit_request(p_request_id) then raise exception 'Not authorized for this training request'; end if;
  if p_material_version_ids is null or cardinality(p_material_version_ids)=0 then raise exception 'Select at least one material'; end if;
  if cardinality(p_material_version_ids)>50 then raise exception 'Too many materials selected'; end if;

  select count(*) into cnt
  from public.training_material_versions v
  join public.training_materials m on m.id=v.material_id
  where v.id=any(p_material_version_ids) and m.active=true and m.audience='student';

  if cnt<>cardinality(p_material_version_ids) then raise exception 'Student share contains an unavailable or internal material'; end if;

  d:=greatest(1,least(coalesce(p_expires_days,30),365));
  tok:=encode(extensions.gen_random_bytes(24),'hex');
  h:=encode(extensions.digest(tok,'sha256'),'hex');

  insert into public.training_material_share_links(token_hash,request_id,expires_at,created_by)
  values(h,p_request_id,now()+make_interval(days=>d),auth.uid()) returning id into sid;

  insert into public.training_material_share_items(share_id,material_version_id,sort_order)
  select sid,x,100+ord from unnest(p_material_version_ids) with ordinality t(x,ord);

  if p_request_id is not null then
    insert into public.training_class_materials(request_id,material_version_id,attached_by)
    select p_request_id,x,auth.uid() from unnest(p_material_version_ids) x on conflict do nothing;
  end if;

  return jsonb_build_object(
    'share_id',sid,
    'token',tok,
    'url','https://wfkvcpclzhxdvknybvyb.supabase.co/functions/v1/training-materials-share?token='||tok,
    'expires_at',now()+make_interval(days=>d)
  );
end;
$function$;

create or replace function public.queue_training_material_distribution(
  p_request_id uuid,
  p_material_version_ids uuid[],
  p_recipient_emails text[] default null::text[],
  p_expires_days integer default 30
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  rec record; tok text; h text; sid uuid; qid bigint; queued integer:=0;
  cnt integer; d integer; req record; html text; plain text; link text;
begin
  if auth.uid() is null or not public.can_manage_training_materials() then raise exception 'Not authorized'; end if;
  if p_request_id is null or not public.can_edit_request(p_request_id) then raise exception 'Not authorized for this training request'; end if;
  if p_material_version_ids is null or cardinality(p_material_version_ids)=0 then raise exception 'Select at least one material'; end if;

  select count(*) into cnt
  from public.training_material_versions v
  join public.training_materials m on m.id=v.material_id
  where v.id=any(p_material_version_ids) and m.active=true and m.audience='student';

  if cnt<>cardinality(p_material_version_ids) then raise exception 'Distribution contains an unavailable or internal material'; end if;

  select request_number,agency_name,confirmed_date into req
  from public.training_requests where id=p_request_id;

  d:=greatest(1,least(coalesce(p_expires_days,30),365));

  insert into public.training_class_materials(request_id,material_version_id,attached_by)
  select p_request_id,x,auth.uid() from unnest(p_material_version_ids) x on conflict do nothing;

  for rec in
    with requested as (
      select distinct lower(trim(e)) email, null::uuid attendee_id
      from unnest(coalesce(p_recipient_emails,'{}'::text[])) e
      where trim(e)<>''
    ), class_emails as (
      select distinct lower(trim(a.email)) email,a.id attendee_id
      from public.training_attendees a
      where a.request_id=p_request_id
        and coalesce(cardinality(p_recipient_emails),0)=0
        and trim(a.email)<>''
    )
    select * from requested union all select * from class_emails
  loop
    if position('@' in rec.email)=0 then continue; end if;

    tok:=encode(extensions.gen_random_bytes(24),'hex');
    h:=encode(extensions.digest(tok,'sha256'),'hex');

    insert into public.training_material_share_links(token_hash,request_id,recipient_email,expires_at,created_by)
    values(h,p_request_id,rec.email,now()+make_interval(days=>d),auth.uid())
    returning id into sid;

    insert into public.training_material_share_items(share_id,material_version_id,sort_order)
    select sid,x,100+ord from unnest(p_material_version_ids) with ordinality t(x,ord);

    link:='https://wfkvcpclzhxdvknybvyb.supabase.co/functions/v1/training-materials-share?token='||tok;
    plain:='Backtrace Training Materials'||E'\n\n'||coalesce(req.agency_name,'')||' — '||coalesce(req.request_number,'')||E'\n\nOpen your secure training materials: '||link||E'\n\nThis link expires in '||d||' days.';
    html:='<div style="font-family:Arial,sans-serif;color:#172033"><h2 style="color:#0d2853">Backtrace Training Materials</h2><p><b>'||replace(coalesce(req.agency_name,''),'&','&amp;')||'</b><br>'||replace(coalesce(req.request_number,''),'&','&amp;')||'</p><p>Your training materials are available through the secure link below.</p><p><a href="'||link||'" style="display:inline-block;background:#2459a9;color:#fff;text-decoration:none;padding:10px 16px;border-radius:7px;font-weight:bold">Open Training Materials</a></p><p style="font-size:12px;color:#667085">This link expires in '||d||' days.</p></div>';

    insert into public.training_email_queue(recipient_email,subject,text_body,html_body,status,attempts,next_attempt_at,queued_at,dedupe_key)
    values(rec.email,'Training Materials — '||coalesce(req.agency_name,req.request_number),plain,html,'pending',0,now(),now(),'training-materials:'||sid::text)
    returning id into qid;

    insert into public.training_material_distributions(request_id,share_id,attendee_id,recipient_email,email_queue_id,created_by)
    values(p_request_id,sid,rec.attendee_id,rec.email,qid,auth.uid());

    queued:=queued+1;
  end loop;

  return jsonb_build_object('ok',true,'queued',queued,'request_id',p_request_id,'expires_days',d);
end;
$function$;
