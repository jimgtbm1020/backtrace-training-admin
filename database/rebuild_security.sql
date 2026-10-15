-- Supabase may grant schema-wide function EXECUTE to API roles by default.
-- Reset those grants explicitly, then expose only the application's intended API.
revoke all on all functions in schema public from public,anon,authenticated;
grant execute on all functions in schema public to service_role;
do $$declare f record;begin
 for f in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace and proname=any(array[
 'current_user_role','is_active_user','is_manager','can_edit_request','can_manage_training_materials','save_training_request',
 'add_training_attendee','admin_save_training_request','auto_close_expired_training_classes','close_training_class','create_agency_portal_link','create_training_material_share','create_training_attendance_link','delete_test_cleanup','generate_training_reminders','get_dashboard_notification_attention','get_my_training_bug_reports','get_test_cleanup_catalog','get_training_attendance_classes','get_training_attendee_directory','get_training_certificate','get_training_certificate_background_asset','get_training_class_archive_detail','get_training_email_delivery_dashboard','get_training_management_analytics','get_training_system_status','get_user_activity_history','import_business_rules_agencies','preview_test_cleanup','publish_training_material_version','queue_training_material_distribution','resolve_public_training_request_token','respond_to_training_assignment','revoke_agency_portal_link','save_business_rule_assignments','save_training_completion','search_test_cleanup_records','search_training_class_archive','set_training_attendee_completion','set_training_request_teams_link','set_training_schedule','start_training_class','submit_public_training_request','submit_training_bug_report','training_schedule_conflicts','update_training_bug_report']) loop
 execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end$$;
-- Only the public intake, public link validation, and public bug form accept anonymous callers.
do $$declare f record;begin
 for f in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace and proname=any(array['submit_public_training_request','resolve_public_training_request_token','submit_training_bug_report']) loop
 execute format('grant execute on function %s to anon',f.signature);
 end loop;
end$$;
notify pgrst,'reload schema';
