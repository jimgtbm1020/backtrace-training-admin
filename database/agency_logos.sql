alter table public.business_rules_agencies add column logo_path text check(logo_path is null or (length(logo_path)<=200 and logo_path ~ '^[0-9a-f-]+/[0-9a-f-]+\.(png|jpg)$'));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('agency-logos','agency-logos',false,2097152,array['image/png','image/jpeg']);
create policy agency_logos_read on storage.objects for select to authenticated using(bucket_id='agency-logos' and public.current_user_role() in ('admin','coordinator','trainer','viewer'));
create policy agency_logos_insert on storage.objects for insert to authenticated with check(bucket_id='agency-logos' and public.current_user_role() in ('admin','coordinator') and (storage.foldername(name))[1]=auth.uid()::text);
create policy agency_logos_delete on storage.objects for delete to authenticated using(bucket_id='agency-logos' and public.current_user_role() in ('admin','coordinator') and (storage.foldername(name))[1]=auth.uid()::text);
