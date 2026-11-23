-- Allow managers to remove an individual tool assignment from an active agency.
-- Catalog items and other agency assignments are not changed.
grant delete on public.agency_item_assignments to authenticated;
create policy agency_item_assignments_delete on public.agency_item_assignments
 for delete to authenticated using (
  (select public.current_user_role()) in ('admin','coordinator')
  and exists(select 1 from public.business_rules_agencies agency where agency.id=agency_item_assignments.agency_id and agency.active)
 );

create function public.unassign_business_rule_assignment(p_agency_id uuid,p_assignment_id uuid,p_expected_updated_at timestamptz)
returns boolean language plpgsql security invoker set search_path='' as $$
declare saved public.agency_item_assignments%rowtype;
begin
 if auth.uid() is null or public.current_user_role() is null or public.current_user_role() not in ('admin','coordinator') then
  raise exception 'Administrator or Coordinator access is required.';
 end if;
 if p_expected_updated_at is null then raise exception 'Refresh records before unassigning this tool.';end if;
 -- Use the same agency lock as batch saves to avoid competing updates.
 perform id from public.business_rules_agencies where id=p_agency_id and active for update;
 if not found then raise exception 'Choose an active business rules agency.';end if;
 select * into saved from public.agency_item_assignments where id=p_assignment_id and agency_id=p_agency_id for update;
 if not found then raise exception 'This assignment is no longer available. Refresh records.';end if;
 if saved.updated_at<>p_expected_updated_at then raise exception 'This assignment changed. Refresh records before unassigning it.';end if;
 delete from public.agency_item_assignments where id=saved.id and agency_id=p_agency_id;
 if not found then raise exception 'Unable to unassign this tool. Refresh records and try again.';end if;
 return true;
end $$;
revoke all on function public.unassign_business_rule_assignment(uuid,uuid,timestamptz) from public,anon;
grant execute on function public.unassign_business_rule_assignment(uuid,uuid,timestamptz) to authenticated;
