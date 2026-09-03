-- Restrict attendance auto-close invocation to authenticated users.
-- The pg_cron system invocation continues to run as the database scheduler.
revoke execute on function public.auto_close_expired_training_classes() from anon;
grant execute on function public.auto_close_expired_training_classes() to authenticated;
