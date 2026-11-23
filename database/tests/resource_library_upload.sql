-- Resource Library schema and upload metadata regression checks.
-- File bytes use the Storage API in the app; this test covers database operations.
-- All test records and temporary role simulations are rolled back.
begin;
do $test$
declare
  admin_id uuid;
  test_role text;
  product uuid;
  general uuid;
  nj uuid;
  material uuid;
  first_version uuid;
  next_version uuid;
begin
  select id into admin_id from public.profiles where active and role = 'admin' limit 1;
  if admin_id is null then raise exception 'An active administrator is required.'; end if;
  perform set_config('request.jwt.claims', jsonb_build_object('sub', admin_id, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', admin_id::text, true);
  execute 'set local role authenticated';

  -- Use the same fields, filters, and sort columns as library initialization.
  perform id, code, name from public.training_jurisdictions where active = true order by sort_order;
  select id into general from public.training_jurisdictions where code = 'GENERAL' and active;
  select id into nj from public.training_jurisdictions where code = 'NJ' and active;
  if general is null or nj is null then raise exception 'Default or state jurisdiction is missing.'; end if;
  if (select count(*) from public.training_jurisdictions where active) < 52 then
    raise exception 'The national, 50 state, and DC options are incomplete.';
  end if;
  select id into product from public.training_products where active = true order by name limit 1;
  if product is null then raise exception 'An active product is required for uploads.'; end if;
  perform id, product_id, code, name, active, sort_order from public.training_product_modules where active = true order by sort_order;
  perform id, product_id, module_id, title, description, material_type, audience, active from public.training_materials where active = true order by title;
  perform id, material_id, version_label, effective_date, status, is_current, storage_path, original_filename, mime_type, file_size, media_kind, download_allowed, notes, created_at from public.training_material_versions order by created_at desc;
  perform material_id, jurisdiction_id from public.training_material_jurisdictions;
  perform id, request_number, agency_name, confirmed_date, status, class_status, assigned_trainer_id, created_by
    from public.training_requests where class_status <> 'Archived' and archived_at is null order by confirmed_date desc nulls last;

  for test_role in select unnest(array['admin', 'coordinator', 'trainer']) loop
    execute 'reset role';
    update public.profiles set role = test_role where id = admin_id;
    execute 'set local role authenticated';
    if not public.can_manage_training_materials() then raise exception 'Allowed upload role rejected: %', test_role; end if;
    insert into public.training_materials (product_id, module_id, title, description, material_type, audience, active, created_by)
      values (product, null, 'Resource Library rollback QA ' || gen_random_uuid(), 'Upload metadata verification', 'manual', 'student', true, admin_id)
      returning id into material;
    insert into public.training_material_jurisdictions (material_id, jurisdiction_id) values (material, general), (material, nj);
    insert into public.training_material_versions (material_id, version_label, effective_date, status, is_current, storage_path, original_filename, mime_type, file_size, media_kind, notes, download_allowed, created_by)
      values (material, '1.0', current_date, 'draft', false, admin_id || '/' || material || '/qa.pdf', 'qa.pdf', 'application/pdf', 32, 'document', null, true, admin_id)
      returning id into first_version;
    perform public.publish_training_material_version(first_version);
    if not exists (select 1 from public.training_material_versions where id = first_version and status = 'published' and is_current) then
      raise exception 'First version was not published for %', test_role;
    end if;
    insert into public.training_material_versions (material_id, version_label, status, is_current, storage_path, original_filename, mime_type, file_size, media_kind, download_allowed)
      values (material, '2.0', 'draft', false, admin_id || '/' || material || '/qa-v2.pdf', 'qa-v2.pdf', 'application/pdf', 64, 'document', true)
      returning id into next_version;
    perform public.publish_training_material_version(next_version);
    if (select count(*) from public.training_material_versions where material_id = material and is_current) <> 1
      or not exists (select 1 from public.training_material_versions where id = next_version and is_current and status = 'published')
      or not exists (select 1 from public.training_material_versions where id = first_version and not is_current) then
      raise exception 'Current version replacement failed for %', test_role;
    end if;
    -- This is the cleanup path used if publication fails in the upload form.
    delete from public.training_material_versions where id = next_version;
    delete from public.training_materials where id = material;
    if exists (select 1 from public.training_material_versions where material_id = material)
      or exists (select 1 from public.training_material_jurisdictions where material_id = material) then
      raise exception 'Upload cleanup left related records behind.';
    end if;
  end loop;

  for test_role in select unnest(array['viewer', 'inactive']) loop
    execute 'reset role';
    update public.profiles set role = case when test_role = 'inactive' then 'admin' else 'viewer' end,
      active = test_role <> 'inactive' where id = admin_id;
    execute 'set local role authenticated';
    if public.can_manage_training_materials() then raise exception 'Unauthorized upload role accepted: %', test_role; end if;
    begin
      insert into public.training_materials (product_id, title) values (product, 'Unauthorized QA');
      raise exception 'Unauthorized insert succeeded.';
    exception when insufficient_privilege then null;
    end;
    begin
      perform public.publish_training_material_version(gen_random_uuid());
      raise exception 'Unauthorized publication succeeded.';
    exception when raise_exception then
      if sqlerrm <> 'Not authorized' then raise; end if;
    end;
  end loop;
  execute 'reset role';
  execute 'set local role anon';
  begin
    perform id, code, name from public.training_jurisdictions where active order by sort_order;
    raise exception 'Anonymous jurisdiction access succeeded.';
  exception when insufficient_privilege then null;
  end;
  execute 'reset role';
end $test$;
rollback;
select 'PASS: Resource Library initialization queries, national/state choices, admin/coordinator/trainer upload metadata and publication, version replacement, cleanup, and viewer/inactive/anonymous access. All test data rolled back; file transfer was not exercised.' as result;
