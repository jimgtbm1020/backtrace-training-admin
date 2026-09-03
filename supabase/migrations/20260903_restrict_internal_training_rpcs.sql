-- Remove unnecessary public execution grants from internal Training Administration routines.
-- Public request/check-in/certificate RPCs are intentionally unchanged.

revoke execute on function public.get_training_email_delivery_dashboard() from anon;

revoke execute on function public.enrich_training_email_queue_v217() from anon, authenticated;
grant execute on function public.enrich_training_email_queue_v217() to postgres, service_role;

-- Demo cleanup is a manager-only helper, never a public API.
revoke execute on function public.rename_demo_agencies() from anon;
