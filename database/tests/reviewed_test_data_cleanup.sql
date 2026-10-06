begin;
select set_config('request.jwt.claim.sub',(select id::text from public.profiles where role='admin' and active order by created_at limit 1),true);
do $$
declare p jsonb;result jsonb;roots jsonb;v_admin text:=auth.uid()::text;failed boolean;v_count bigint;
begin
 -- Preview and deletion of the existing explicitly labelled QA ticket, fully rolled back.
 select jsonb_build_array(jsonb_build_object('table','training_bug_reports','key',jsonb_build_object('id',id))) into roots from public.training_bug_reports where issue_number='BT-BUG-000012';
 p:=public.preview_test_cleanup(roots);
 if (p->>'count')::int<>4 or p->'blockers'<>'[]'::jsonb then raise exception 'Bug/history preview failed';end if;
 failed:=false;begin perform public.delete_test_cleanup((p->>'id')::uuid,'DELETE ALL');exception when others then failed:=true;end;
 if not failed then raise exception 'Wrong confirmation accepted';end if;
 result:=public.delete_test_cleanup((p->>'id')::uuid,'DELETE 4 TEST RECORDS');
 if result->>'deleted'<>'4' or exists(select 1 from public.training_bug_reports where issue_number='BT-BUG-000012') then raise exception 'Bug delete failed';end if;
 if not exists(select 1 from private.training_cleanup_plans where id=(p->>'id')::uuid and status='deleted' and jsonb_array_length(records)=4) then raise exception 'Audit snapshot missing';end if;
 failed:=false;begin perform public.delete_test_cleanup((p->>'id')::uuid,'DELETE 4 TEST RECORDS');exception when others then failed:=true;end;
 if not failed then raise exception 'Repeated plan accepted';end if;
 -- Archived class exercises historical deletion guards and its entire dependency tree.
 roots:=jsonb_build_array(jsonb_build_object('table','training_requests','key',jsonb_build_object('id','fb50792d-a3a8-4379-a634-893203d4d94d')));
 p:=public.preview_test_cleanup(roots);
 if p->'blockers'<>'[]'::jsonb then raise exception 'Class blockers: %',p->'blockers';end if;
 result:=public.delete_test_cleanup((p->>'id')::uuid,'DELETE '||(p->>'count')||' TEST RECORDS');
 if result->>'deleted'<>p->>'count' then raise exception 'Class count mismatch';end if;
 if exists(select 1 from public.training_requests where id='fb50792d-a3a8-4379-a634-893203d4d94d') or exists(select 1 from public.training_attendees where request_id='fb50792d-a3a8-4379-a634-893203d4d94d') or exists(select 1 from public.training_completion_records where request_id='fb50792d-a3a8-4379-a634-893203d4d94d') then raise exception 'Class descendants remain';end if;
 -- Shared agency: linked training request cannot be silently removed.
 select jsonb_build_array(jsonb_build_object('table','agencies','key',jsonb_build_object('id',agency_id))) into roots from public.training_requests where agency_id is not null limit 1;
 if roots is not null then
 p:=public.preview_test_cleanup(roots);
 if jsonb_array_length(p->'blockers')=0 then raise exception 'Shared agency was not blocked';end if;
 failed:=false;begin perform public.delete_test_cleanup((p->>'id')::uuid,'DELETE '||(p->>'count')||' TEST RECORDS');exception when others then failed:=true;end;
 if not failed then raise exception 'Shared agency deleted';end if;
 end if;
 -- Scope rejects secrets and arbitrary SQL identifiers.
 failed:=false;begin perform public.search_test_cleanup_records('training_email_provider_settings','',0);exception when others then failed:=true;end;
 if not failed then raise exception 'Provider secrets exposed';end if;
 failed:=false;begin perform public.search_test_cleanup_records('agencies; drop table profiles','',0);exception when others then failed:=true;end;
 if not failed then raise exception 'Unsupported identifier accepted';end if;
 -- Anonymous/non-administrators cannot use any API.
 perform set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000000',true);
 failed:=false;begin perform public.get_test_cleanup_catalog();exception when others then failed:=true;end;
 if not failed then raise exception 'Non-admin accepted';end if;
 perform set_config('request.jwt.claim.sub','',true);
 failed:=false;begin perform public.get_test_cleanup_catalog();exception when others then failed:=true;end;
 if not failed then raise exception 'Anonymous accepted';end if;
 perform set_config('request.jwt.claim.sub',v_admin,true);
 -- Direct ordinary deletion guards continue protecting the other completed classes.
 failed:=false;begin delete from public.training_requests where id='f41f57a2-235e-4a58-b025-fa0fe4896b7e';exception when others then failed:=true;end;
 if not failed then raise exception 'Ordinary historical deletion guard bypassed';end if;
end $$;
set constraints all immediate;
select 'PASS: exact preview, confirmation, linked deletion, audit, replay rejection, shared-record blocking, scope, authorization, historical safeguards; transaction rolled back' result;
rollback;
