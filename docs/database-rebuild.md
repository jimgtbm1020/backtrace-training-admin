# Backtrace fresh database reconstruction

Target: `dzqsmqispdixwmklpwdf`. The former project and its operational records were unavailable.

Apply only to a fresh database, in this order:

1. `database/rebuild_baseline.sql`
2. `database/rebuild_saved_workflows.sql`
3. `database/rebuild_core_workflows.sql`
4. `database/rebuild_support_workflows.sql`
5. `database/rebuild_security.sql`
6. `database/rebuild_configuration.sql`
7. `database/rebuild_public_services.sql`

The saved-workflow bundle preserves existing SQL and fixes an invalid cleanup alias, missing statement separators, and references to the former project. Demo-only deletion exemptions are disabled. All tables use RLS. Server-only tables intentionally have no API policies. Function grants are explicitly reset because hosted Supabase defaults may include API roles.

The baseline creates inactive viewer profiles for Auth users. Staff account creation activates the requested role through the authenticated administrator Edge Function. Secrets are configured separately and are never stored in this repository.

Deploy the Edge Functions in `supabase/functions`. The public services authenticate opaque, hashed bearer links. The password reset service is intentionally public, rate limited, and does not disclose account existence. `manage-training-users` validates its bearer token with Auth getUser. These handlers use custom authorization with gateway verify_jwt=false.

Validation: `database/tests/rebuild_workflows.sql` is transactional and rolls back its users and records. Run it on a fresh test database or the new project before adding real records. It exercises roles, duplicate tool names, scheduling, attendance, finalization, certificates, and rejection of anonymous internal RPCs. Existing password Edge tests also apply.

Configuration restores 59 training modules from the public form and the saved 2.1.30 manual/release. Historical records, uploaded files, certificate artwork, prior users, and prior audit events are not recovered.

Background delivery and scheduler jobs are tracked separately from direct account/password emails; System Status reports their actual configuration.
