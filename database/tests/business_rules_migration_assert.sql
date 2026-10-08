do $$
begin
 if not exists(select 1 from public.business_rules_agencies where id='00000000-0000-4000-8000-000000000124' and agency_name='Migration Rollback Agency' and agency_address='Preserved address') then raise exception 'Agency snapshot lost name/address/ID';end if;
 if not exists(select 1 from public.agency_item_assignments where id='00000000-0000-4000-8000-000000000324' and agency_id='00000000-0000-4000-8000-000000000124' and data_source='Preserved source' and retention_value=123 and retention_unit='Days') then raise exception 'Migration changed existing assignment';end if;
 if not exists(select 1 from public.agencies where id='00000000-0000-4000-8000-000000000124' and contact_email='migration@example.invalid') then raise exception 'Migration changed training contacts';end if;
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='business_rules_agencies' and column_name like 'contact_%') then raise exception 'Training contacts copied into business registry';end if;
 delete from public.agencies where id='00000000-0000-4000-8000-000000000124';
 if not exists(select 1 from public.business_rules_agencies where id='00000000-0000-4000-8000-000000000124') or not exists(select 1 from public.agency_item_assignments where id='00000000-0000-4000-8000-000000000324') then raise exception 'Training deletion cascaded into business registry';end if;
end $$;
