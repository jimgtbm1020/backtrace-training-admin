-- Restore 47 missing historical releases from version-controlled notes, manuals,
-- merged PRs, and saved history screenshots. Recovery provenance is recorded in
-- database/release-history-recovery.json. Unknown dates remain NULL.
-- Existing releases, current flags, and change rows are never overwritten.
begin;
lock table public.training_app_versions, public.training_app_version_changes in share row exclusive mode;

with recovered as (
  select * from jsonb_to_recordset($release_history$
[
  {
    "version": "1.0.0",
    "initial_problem": "Initial application baseline; no earlier production defect is documented.",
    "fix_summary": "Established the authenticated administration shell, public training-request intake, and agency/request directory workflow.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Initial Training Administration",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "1.1.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: agency intake needed automatic directory creation, agency trainer contacts, resource selection, and revised training choices.",
    "fix_summary": "Expanded request intake, agency auto-add, trainer contact capture, resource fields, Train the Trainer, single-choice selection, and Computer with Wi-Fi. Removed Training Objectives.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Agency Intake and Training Requests",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "1.2.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: the course catalog and request validation needed the complete four-course model and tool-based durations.",
    "fix_summary": "Added Basic, Train the Trainer, Refresher, and Advanced courses, tool selection, duration calculations, and single-choice validation.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Four-Course Training Catalog",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "1.3.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: class signup, check-in, rosters, certificates, completion, and past-class records were needed.",
    "fix_summary": "Introduced secure attendance links/QR codes, attendee registration/check-in, certificates, completion finalization, and searchable historical class records.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Attendance, Certificates, and Class History",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "1.4.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: staff needed audited request corrections, Teams links, certificate-email controls, and clearer manual illustrations.",
    "fix_summary": "Added administrator corrections with before/after audit, Teams links on requests and trainer output, certificate email/resend controls, and scalable manual references.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Administrator Corrections and Certificate Email",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "1.5.0",
    "initial_problem": "The Agency Portal lacked parity across the four training types, and configuration-fetch/Base64 wrappers caused Unable to Fetch / atob errors.",
    "fix_summary": "Added Portal training-type/tool/duration parity, removed the brittle wrappers, clarified agency trainer terminology, and renamed the attendance action Generate Class.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Agency Portal and Generate Class",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "1.6.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: attendee identification needed persistent Badge/ID records and releases needed formal version tracking.",
    "fix_summary": "Added Badge/ID to registration, rosters, historical records, print/CSV output, and dated application version history.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Badge / ID and Version History",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: training operations needed formal lifecycle controls, longitudinal attendee/agency history, readiness data, and public certificate verification.",
    "fix_summary": "Added class states, Start/Close controls, closed-before-finalization rules, persistent attendee identity, duplicate protection, agency history, trainer readiness, and verification.",
    "verification_summary": "Recorded verification: Added public certificate verification by certificate number or public certificate ID.",
    "release_date": null,
    "title": "Class Lifecycle and Attendee Identity",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.1",
    "initial_problem": "Generated Calendar/Completion links used legacy routes, public verification disclosed Badge/ID, and class lifecycle/privacy safeguards needed strengthening.",
    "fix_summary": "Corrected direct routes, removed public Badge/ID display, and strengthened finalization, scheduling, token, permission, email, and record integrity controls.",
    "verification_summary": "Recorded verification: Public certificate verification no longer discloses Badge # / ID #; the identifier remains retained in internal attendee records. Revalidated Attendance and Completion production endpoints and isolated the remaining legacy Completion compressed-wrapper cleanup as a frontend deployment item.",
    "release_date": null,
    "title": "Routing and Workflow Integrity",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.2",
    "initial_problem": "The Attendance parser exposed JavaScript/template code as page text. Related recorded fixes addressed redirect loops, legacy notification links, and production integrity/security gaps.",
    "fix_summary": "Sanitized malformed nested script boundaries and restored Attendance rendering/routing. Added the recorded authorization, payload, lifecycle, certificate, audit, scheduling, and retention safeguards detailed below.",
    "verification_summary": "Recorded verification: Validated the repaired Attendance /base endpoint with HTTP 200 and preserved the existing attendance, Badge/ID, class lifecycle, archive, print, Trainer Information, and certificate controls. Removed the obsolete public Badge # / ID # display while preserving certificate validity, participant, agency, training type/date, trainer, certificate number, request number, and issued date. Added database-level prevention of overlapping active classes for the same trainer. Rollback-only QA confirmed conflicting schedules are rejected, current production schedules remain conflict-free, and no QA data remains.",
    "release_date": null,
    "title": "Attendance Rendering and Workflow Safeguards",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.3",
    "initial_problem": "Certificate delivery used protected routes, sequential certificate numbers could expose full PDFs, and internal RPC, email, and dependency safeguards needed hardening.",
    "fix_summary": "Moved PDFs to UUID-only public retrieval, corrected email links, reduced RPC exposure, preserved activation-cutoff backlog safeguards, pinned the email processor dependency, and optimized request-insert RLS.",
    "verification_summary": "Recorded verification: Revalidated certificate verification by public UUID and certificate number, confirmed invalid identifiers return valid=false, and preserved the dedicated public verification site as the certificate verification destination referenced by issued PDFs. Hardened public certificate PDF retrieval so the full certificate document can be opened only with the high-entropy certificate_public_id UUID. Sequential BTC-CERT certificate numbers remain usable for the dedicated verification workflow but can no longer directly retrieve the PDF. Production QA confirmed UUID retrieval returns HTTP 200 application/pdf and sequential-number retrieval returns HTTP 400.",
    "release_date": null,
    "title": "Certificate Access and Email Safeguards",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.4",
    "initial_problem": "Three remaining Attendance and Attendee Directory certificate links opened protected Vercel routes instead of the public certificate PDF.",
    "fix_summary": "Replaced the remaining links with the UUID-only Supabase certificate PDF endpoint.",
    "verification_summary": "Recorded verification: Deployed new production builds for Training Attendance and Attendee Directory, confirmed both deployments reached READY, verified the live pages retain required current functionality and contain the public certificate endpoint with no remaining protected certificate links, and confirmed no runtime errors were reported after deployment. Revalidated production certificate delivery after the frontend hotfix: UUID certificate retrieval returns HTTP 200 application/pdf with inline disposition and no-store headers, while sequential BTC-CERT numbers remain blocked from direct PDF retrieval with HTTP 400.",
    "release_date": null,
    "title": "Certificate Link Corrections",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.5",
    "initial_problem": "Closed classes awaiting finalization were not clearly identified and needed direct navigation to their completion record.",
    "fix_summary": "Added the Class Closed — Completion Required banner and a request-specific Finalize Training Record action.",
    "verification_summary": "Recorded verification: Preserved root / and /base routes, existing public certificate links, and verified the main tracker /attendance wrapper after production deployment.",
    "release_date": null,
    "title": "Class Finalization Workflow",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.6",
    "initial_problem": "Enhancement need inferred from the recorded changes: navigation needed a per-user unread count, zero-count hiding, and reliable refresh. The original source-clone deployment method also failed.",
    "fix_summary": "Added authenticated unread counts and refresh safeguards, then used a corrected preview/staged deployment workflow.",
    "verification_summary": "Recorded verification: Promoted the qualified staged Production artifact without rebuilding. Verified production HTTP 200 for /, /notifications, and /attendance; confirmed the live main shell contains all v2.0.6 notification markers; preserved Attendance certificate links and class-finalization workflow; and found no production runtime errors after release.",
    "release_date": null,
    "title": "Notification Unread Counts",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.7",
    "initial_problem": "Unread badge updates could wait for the 30-second refresh after a notification was marked read or unread.",
    "fix_summary": "Added immediate synchronization from the Notifications unread metric while retaining periodic, focus, visibility, and navigation refreshes.",
    "verification_summary": "Recorded verification: Verified production HTTP 200 for /, /notifications, /attendance, and /version-history; confirmed the live root serves all v2.0.7 observer markers; preserved Attendance class finalization and public certificate integration; and found no runtime errors after promotion.",
    "release_date": null,
    "title": "Instant Notification Synchronization",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.8",
    "initial_problem": "Enhancement need inferred from the recorded changes: notification status, count-change feedback, keyboard focus, and current-page cues needed accessibility improvements.",
    "fix_summary": "Added live status semantics, dynamic unread labels, reduced-motion-aware count feedback, visible keyboard focus, and aria-current.",
    "verification_summary": "Recorded verification: Promoted deployment dpl_FLn9UkYU8yPpmnAj9ghMiUcFb71M and verified HTTP 200 for /, /notifications, /attendance, and /version-history. Confirmed the live production hostname resolves to the promoted deployment and found no runtime errors or warning/error logs after release.",
    "release_date": null,
    "title": "Notification UX and Accessibility",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.0.9",
    "initial_problem": "Enhancement need inferred from the recorded changes: paper sign-in sheets needed a reviewed, auditable attendance reconciliation workflow.",
    "fix_summary": "Added photo/image/PDF capture, private source retention, authenticated OCR, identity matching, and reviewed atomic attendance reconciliation. OCR did not issue certificates.",
    "verification_summary": "Recorded verification: Qualified Preview dpl_6aX1MoBsh7AfFjwZmMqyyS6fJs3q and staged Production dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ. Promoted the exact staged artifact with rollback protection to dpl_Fo9qLCHDvo4kL49m61uHpJ5JW7xz. Verified HTTP 200 and paper-ingest markers on the live Attendance alias and main /attendance route, preserved main deployment dpl_FLn9UkYU8yPpmnAj9ghMiUcFb71M, and found no runtime errors after release.",
    "release_date": null,
    "title": "Paper Sign-In Reconciliation",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.0",
    "initial_problem": "Enhancement need inferred from the recorded changes: staff needed a product/jurisdiction-aware training library with version retention and secure student distribution. An initial routing candidate also failed the materials smoke test.",
    "fix_summary": "Added private, versioned training resources, class attachments, expiring student packets, large uploads, and distribution. Corrected trailing-slash materials routing after rollback.",
    "verification_summary": "Recorded verification: Qualified corrected Preview dpl_GYsfs9ybS7qjNxZot6cBuhh6XPxf and staged Production dpl_5ffFooFqtZirk2HximatDbjWUMLD. An earlier routing candidate failed the /materials smoke test and was automatically restored to v2.0.8; the corrected trailing-slash routing was then requalified. Promoted the exact corrected staged artifact without rebuilding, verified /materials, /, /notifications, /attendance, and /version-history at HTTP 200, preserved Attendance on dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ, and found no post-release runtime errors.",
    "release_date": null,
    "title": "Versioned Training Materials",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.1",
    "initial_problem": "Enhancement need inferred from the recorded changes: flat navigation needed clearer role-aware groups and mobile navigation.",
    "fix_summary": "Grouped Training, People, and Administration, retained direct Dashboard/Notifications access, and added responsive navigation and active-route accessibility.",
    "verification_summary": "Recorded verification: Qualified Preview dpl_G2V9MhGqG72eBxkQTw9PWr5gXuuF, staged dpl_9vdhKgdERHspJwbFZ3wmCiXkd6Sd without live traffic, then promoted that exact artifact without rebuilding. Post-promotion smoke tests passed for the main artifact, /, /materials, /notifications, /attendance, and /version-history; Attendance remained on dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ and no runtime errors were observed after release.",
    "release_date": null,
    "title": "Grouped Navigation",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.2",
    "initial_problem": "Version Tracker used an invalid publishable-key Bearer flow and failed to load authenticated release history.",
    "fix_summary": "Changed Version Tracker to use the normal Supabase session and authenticated history RPC, preserving private history access.",
    "verification_summary": "Recorded verification: Functionally verified the exact Preview dpl_JBVZ1snFVSXqngkNyR2zB64TXcSU while signed in. Version Tracker loaded the protected release history successfully with no HTTP 401 and retained the Back to Training Administration navigation. Created staged Production artifact dpl_EfcX6YA58PCo1L9tnivVmVqKqd1R from the exact approved Preview with autoAssignCustomDomains disabled, validated exact Preview byte equivalence and preserved routing, then promoted that exact artifact without rebuilding. Post-promotion smoke tests passed for the main artifact, /version-history, /version-history/, /materials, /, /notifications, and /attendance. Independently verified the live Production Version Tracker while signed in after promotion. Main Production remains dpl_EfcX6YA58PCo1L9tnivVmVqKqd1R; Attendance remains exact v2.0.9 on dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ. No automatic rollback, database schema change, or Resend/email configuration change was required.",
    "release_date": null,
    "title": "Authenticated Version History",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.3",
    "initial_problem": "The recorded changes addressed inconsistent whitespace, email casing, agency terminology, and a canonical agency spelling while protecting historical certificate details.",
    "fix_summary": "Added field-aware input normalization in the interface and database, corrected the canonical agency and mutable directory record, and hardened internal helper access.",
    "verification_summary": "Recorded verification: Functionally verified exact Preview dpl_Bp2fmUAxRF7XgNr4ozkgxGE5uZZ4, then created exact staged Production artifact dpl_AKcBvt7CgrLr1ixAq6cSoagTdvk1 with autoAssignCustomDomains disabled. Staged validation confirmed exact Preview main bytes, exact Preview routing bytes, preserved v2.1.2 routing, all input-quality markers, Version Tracker health, and Attendance preservation. The exact staged artifact was promoted without rebuilding; Vercel returned 201 and all guarded smoke tests passed. Signed-in live Production verification passed after promotion. Main Production is exact v2.1.3 deployment dpl_AKcBvt7CgrLr1ixAq6cSoagTdvk1; Attendance remains exact v2.0.9 deployment dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ. Automatic rollback was not triggered.",
    "release_date": null,
    "title": "Input Normalization and Data Quality",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.4",
    "initial_problem": "The Training Manual menu label confused application instructions with Backtrace training content.",
    "fix_summary": "Renamed it App User Guide and moved it into Help, keeping the existing guide route and training resources separate.",
    "verification_summary": "Recorded verification: Promoted exact staged artifact dpl_49KrFsVnjDm47UWBkDh1jrXxoHUG without rebuilding. All guarded smoke tests passed, signed-in live Production verification passed, automatic rollback was not triggered, Attendance remains exact v2.0.9 deployment dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ, and no database/schema changes were required.",
    "release_date": null,
    "title": "App User Guide Navigation",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.5",
    "initial_problem": "Enhancement need inferred from the recorded changes: trainers needed a dedicated resource workflow with upload-driven organization and clear state/audience classification.",
    "fix_summary": "Expanded Training Materials into a top-level Resource Library with resource types, searchable state selection, audience classification, versioning, and optional metadata.",
    "verification_summary": "Recorded verification: Exact user-approved Preview dpl_HZmyenaFAyWkfZBo9bhCjLLU82Xr passed functional validation and was staged as exact Production artifact dpl_7VuRXgCLPKw4tNPcM1ooeAkfrDL7. The artifact was promoted without rebuilding; Resource Library, legacy /materials, Version Tracker, main shell, Notifications and Attendance smoke tests passed, automatic rollback was not triggered, and final signed-in Production verification passed.",
    "release_date": null,
    "title": "Resource Library",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.6",
    "initial_problem": "Enhancement need inferred from the recorded changes: Resource Library placement and the unused More navigation group needed cleanup.",
    "fix_summary": "Moved Resource Library to the final primary-menu position and removed More while preserving routes and permissions.",
    "verification_summary": "Recorded verification: Exact approved Preview dpl_8p8UPGgHFFfpMRzgSnKrXg8SLTdb was staged as exact Production artifact dpl_DGcg7S1ULLF4DQdSpNc8mNaZGR5X. Staged validation confirmed exact Preview main bytes, exact routing bytes, all navigation-cleanup markers, required module health, and unchanged main/Attendance live aliases before promotion. Promoted exact staged artifact dpl_DGcg7S1ULLF4DQdSpNc8mNaZGR5X without rebuilding. Vercel promotion returned status 201. Resource Library, legacy Materials, Version Tracker, /version-history, /version-history/, main shell, /resources/, /materials/, Notifications, and Attendance smoke tests all passed; automatic rollback was not triggered. Signed-in live Production verification passed. Main Production is exact v2.1.6 deployment dpl_DGcg7S1ULLF4DQdSpNc8mNaZGR5X. Attendance remains exact v2.0.9 deployment dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ. No database schema changes were made.",
    "release_date": null,
    "title": "Resource Library Navigation Cleanup",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.7",
    "initial_problem": "Enhancement need inferred from the recorded changes: controlled email templates, certificate delivery, and delivery-event infrastructure were needed.",
    "fix_summary": "Configured the verified sender, published ten email templates, added administrator test controls and certificate-email integration, and introduced delivery tracking infrastructure. Automatic delivery remained disabled at that release.",
    "verification_summary": "Recorded verification: Configured Backtrace Training <no-reply@training.gtbm.com> on the verified training.gtbm.com Resend domain. Credential testing passed. Automatic email delivery remains OFF with enabled_at null, preserving the historical backlog. Promoted v2.1.7 to exact Production deployment dpl_EQCvMj8RhafuSiAdoapk7Z6ga6iR. Post-promotion verification confirmed main Production READY, Attendance preserved at dpl_GZj6JHKmZX1tZntc3ex8fXMmEXHQ, sender unchanged, automatic email delivery OFF, delivery tracking disabled, and the historical email backlog unchanged at 26 pending with 0 sent, 0 failed, and 0 historical rows rewritten/tagged.",
    "release_date": null,
    "title": "Email Templates and Delivery Infrastructure",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.8",
    "initial_problem": "Release tooling and routed modules still depended on AppDeploy; Email Settings needed its administrator-session bootstrap to run correctly through the application rewrite.",
    "fix_summary": "Moved release tooling, Version Tracker, resource modules, and Email Settings to GitHub/Vercel/Supabase and restored the Email Settings session bootstrap.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "GitHub, Vercel, and Supabase Migration",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.9",
    "initial_problem": "Enhancement need inferred from the recorded changes: administrators needed one screen to inspect release version, communications state, queue, and production protections.",
    "fix_summary": "Added administrator-only System Status with version, architecture, communications, cron, queue, and protection visibility.",
    "verification_summary": "Recorded verification: Qualified Preview dpl_4gzo84cvjhyKv1tTH6PXn3zLi9cd and staging dpl_HmvrhgFX8NoFL5KqPhGZZ5NnUktq as READY, zero-alias artifacts with exact main and routing byte equality and zero AppDeploy dependencies.",
    "release_date": null,
    "title": "Administrator System Status",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.10",
    "initial_problem": "Enhancement need inferred from the recorded changes: System Status lacked a consolidated view of current, prior, and next releases and deployment lineage.",
    "fix_summary": "Added a read-only release lineage panel with current release, prior release, next development version, environment, and recent history.",
    "verification_summary": "Recorded verification: Qualified Preview dpl_55WKrf2kKgi2geowfzSjHtagrAWF and staging dpl_7yjSSbX2A5Ndcipq9Xz38AkBysQ3 as READY zero-alias artifacts with exact main/routing byte equality and zero AppDeploy dependencies.",
    "release_date": null,
    "title": "Release History and Deployment Lineage",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.11",
    "initial_problem": "The stored release record identifies accumulated administration/attendance stabilization issues and a final attendance close-window ordering correction; it does not describe every original symptom.",
    "fix_summary": "Completed the recorded stabilization work and close-window ordering correction, then locked the UAT-approved deployment and commit.",
    "verification_summary": "Recorded Final UAT verified attendance lifecycle, completion/archive behavior, certificate identity mapping, Resource Library share integrity, role gating, scheduled maintenance jobs, and production runtime health.",
    "release_date": null,
    "title": "Final Production UAT and Stabilization",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.12",
    "initial_problem": "Enhancement need inferred from the recorded changes: grouped navigation needed clearer spacing, active-page cues, and a consistent presentation.",
    "fix_summary": "Refreshed grouped navigation popovers, spacing, rounded cards, active-page highlighting, and labels across the application.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Navigation Presentation",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.13",
    "initial_problem": "The retired standalone Attendance interface and paper import entry point were still served. A stale page-level version label and old routes caused inconsistent entry points.",
    "fix_summary": "Redirected retired Attendance and Tracker routes into the unified application, preserved query parameters, and removed the stale Attendance version label.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Unified Attendance Routes",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.14",
    "initial_problem": "The Add Resource and Export CSV buttons were too close together.",
    "fix_summary": "Added a consistent 10-pixel gap, wrapping action layout, and full-width action group on narrow screens.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Resource Library Action Spacing",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.15",
    "initial_problem": "Enhancement need inferred from the recorded changes: users needed contextual application guidance and accessible tooltip controls.",
    "fix_summary": "Added contextual tooltips, keyboard and Escape controls, guide instructions, and viewport-safe tooltip positioning.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": null,
    "title": "Contextual Help and Accessible Tooltips",
    "summary": "Recovery note: The problem, fix, and verification text below is preserved verbatim from saved release notes. This title describes those notes; the original title, release date, summary, and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql"
  },
  {
    "version": "2.1.16",
    "initial_problem": "Basic Backtrace Search still displayed 1 Hour 30 Minutes and used a 90-minute base duration instead of the requested 4 Hours.",
    "fix_summary": "Updated the form and request duration calculations to 4 Hours / 240 minutes. Preserved completed 90-minute records as historical data.",
    "verification_summary": "Recorded verification: Promoted the verified v2.1.16 application build, kept the standalone Attendance deployment unchanged, and restored the staged-deployment auto-alias guard after postflight verification.",
    "release_date": "2026-09-15",
    "title": "Basic Backtrace Search — 4-Hour Duration",
    "summary": "Recovery note: The title and release date were recovered from a saved Version History screenshot. Problem, fix, and verification text is preserved verbatim from saved release notes; the original summary and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql; collapsible-release-history-20261006.jpg (libfile_fd1b4f04c43881918dc16f2775423fa3)"
  },
  {
    "version": "2.1.17",
    "initial_problem": "The public form heading said Agency Trainer Contact Information rather than Agency Training Coordinator.",
    "fix_summary": "Renamed the section heading to Agency Training Coordinator while preserving its fields and submission behavior.",
    "verification_summary": "Separate test results were not recorded for this release. See the original release summary for any deployment qualification details.",
    "release_date": "2026-09-15",
    "title": "Agency Training Coordinator Terminology",
    "summary": "Recovery note: The title and release date were recovered from a saved Version History screenshot. Problem, fix, and verification text is preserved verbatim from saved release notes; the original summary and per-component change list were not retained.",
    "changes": [],
    "source": "database/release_history_problem_fix_verification.sql; collapsible-release-history-20261006.jpg (libfile_fd1b4f04c43881918dc16f2775423fa3)"
  },
  {
    "version": "2.1.18",
    "initial_problem": "Problem reports lacked reference numbers, assigned ownership, priority, and change history. Submitters needed status follow-up. Trainer response controls, live dashboard communications status, and certificate duration/preservation also needed updates.",
    "fix_summary": "Added ticket receipts, priority, ownership, status, required resolution summaries, history, stale-save protection, and My Reports. Added trainer acceptance/decline and Teams links. Dashboard reads live settings. Basic certificates show 4 Hours; existing certificates preserve their details without duplicate delivery. Updated the user manual.",
    "verification_summary": "TypeScript and production builds passed. Rollback database tests covered ticket creation, permissions, assignment, history, stale-save rejection, resolution, reopening, and reporter isolation. Live QA ticket BT-BUG-000012 was submitted, assigned, closed, and its resolution checked in My Reports. Trainer/database lifecycle and certificate tests passed; a separate trainer browser session was not exercised. Email receipt was confirmed. The guide and history were verified live.",
    "release_date": "2026-10-06",
    "title": "Bug Tracking and Training Workflow Updates",
    "summary": "Adds ticket references, priority, assigned ownership, status tracking, resolution summaries, and change history. Includes trainer acceptance and Teams links, live communications status, and certificate preservation fixes. The user guide and manual now document the current workflow.",
    "changes": [
      {
        "component": "Bug Reports",
        "change_summary": "Every submission receives a BT-BUG reference. Administrators can assign an active administrator or coordinator, set priority, filter tickets, and record internal notes and change history.",
        "sort_order": 1
      },
      {
        "component": "Reporter Follow-Up",
        "change_summary": "Signed-in submitters see their own reports, current status, priority, and resolution summary. Internal notes remain private. Public submitters retain their reference for follow-up.",
        "sort_order": 2
      },
      {
        "component": "Resolution Safeguards",
        "change_summary": "Closing or resolving requires a resolution summary. Reopening clears resolution metadata. Stale updates are rejected and submitted problem details remain unchanged.",
        "sort_order": 3
      },
      {
        "component": "Trainer Workspace",
        "change_summary": "Assigned active trainers can accept or decline with a reason and save approved Teams meeting links after acceptance. Reassignment resets the response.",
        "sort_order": 4
      },
      {
        "component": "Dashboard and Email",
        "change_summary": "Dashboard communications status reflects live settings. Production email delivery was tested and receipt confirmed.",
        "sort_order": 5
      },
      {
        "component": "Certificates",
        "change_summary": "Basic Backtrace Search certificates display 4 Hours. Repeat access preserves existing certificate details and avoids duplicate certificate emails.",
        "sort_order": 6
      },
      {
        "component": "User Manual",
        "change_summary": "App User Guide updated to application v2.1.18. Manual v4.1 documents ticket submission, assignment, resolution, reopening, privacy, and the operational training workflow.",
        "sort_order": 7
      }
    ],
    "source": "database/release_2_1_18_manual_and_history.sql"
  },
  {
    "version": "2.1.19",
    "release_date": "2026-10-06",
    "title": "Reviewed Administrator Test-Data Cleanup",
    "summary": "Recovered from the v4.2 application manual and merged PRs #197 and #199. The original release summary was not retained.",
    "initial_problem": "Administrators needed a reviewed way to remove exact test records, including completed test classes and certificates, while preserving ordinary historical-record protections.",
    "fix_summary": "Administrators can select exact test records across 30 application record categories, preview all dependent rows, and delete the reviewed set with a typed confirmation. This allows cleanup of completed test classes and test certificates without changing ordinary historical-record protections. Shared rows outside the preview block deletion; previews expire after 15 minutes and are revalidated under locks before atomic deletion. Restricted snapshots and an administration audit retain the cleanup reference.\n\nSign-in accounts, storage objects and system configuration/history are explicitly outside this database-record cleanup.\n\nThe dashboard now includes a Test Data Cleanup card inside its existing active-administrator overview. Coordinators, trainers and viewers do not see the card. The direct cleanup URL now shows an access gate until its database-enforced active-admin catalog check succeeds, so unauthorized users cannot see cleanup controls or record details.",
    "verification_summary": "Recorded in PR #197: rollback database tests passed for dependency deletion, wrong confirmations, repeated plans, shared references, authorization, stale and expired previews, protected-secret table rejection, and normal historical deletion guards. Authenticated-role preview passed. The original release verification summary was not retained; no additional historical browser results are claimed.",
    "changes": [],
    "source": "docs/training-administration-user-manual-v4.2.md; GitHub PRs #197, #199"
  },
  {
    "version": "2.1.20",
    "release_date": "2026-10-06",
    "title": "Reliable Database Connection",
    "summary": "Recovered from the October 6, 2026 release screenshot and merged PR #200. The original complete summary and change list were not retained.",
    "initial_problem": "The live browser reported Failed to fetch on release history and cleanup, and the dashboard could not load the active administrator role. Direct endpoint navigation reproduced net::ERR_BLOCKED_BY_CLIENT before requests reached the healthy Supabase database.",
    "fix_summary": "Application HTTP requests now use a fixed-upstream same-origin handler. Existing API keys, user tokens and sign-in sessions are preserved; database row-level security and administrator checks remain enforced. The handler restricts paths and headers, strips browser cookies, disables caching, and provides a readable upstream failure response. Dashboard failures now show a retry control and unavailable metrics instead of misleading zero counts.",
    "verification_summary": "The merged implementation and original release screenshot were recovered. Separate completed verification results were not retained; the PR lists planned TypeScript, production-build, and browser checks.",
    "changes": [],
    "source": "GitHub PR #200; database-fetch-fixed-20261006.jpg (libfile_52cbfc5d6c588191be385cb96617d198)"
  },
  {
    "version": "2.1.21",
    "release_date": "2026-10-06",
    "title": "Dashboard Notification Alerts",
    "summary": "Recovered from the v4.3 application manual and merged PR #201. The original release summary was not retained.",
    "initial_problem": "Admins and trainers had to open Notifications to discover unread notices, and reading an assignment notice could hide an unresolved task.",
    "fix_summary": "Admins and trainers currently have to open Notifications to discover unread notices, and reading an assignment notice can hide an unresolved task. Add a dashboard attention card with exact own-user counts for unread notices, unresolved actions and overdue actions, plus the latest five items and safe View/Take action links. Pending assignment responses, declined assignments requiring administration, missing assignment/scheduling and current schedule conflicts remain independent of read status and clear when the underlying request changes.\n\nThe summary RPC is read-only SECURITY INVOKER, requires an active admin/trainer, scopes notifications to auth.uid(), and respects existing table RLS. No reminder generation or outbound email is triggered by opening the card. Refresh every 30 seconds while visible, on focus/visibility return and read-state changes. Includes loading, empty/error states, keyboard focus, responsive layout and an aria-live count. Dashboard notification links open all read statuses.",
    "verification_summary": "The merged implementation includes database tests for recipient isolation and action lifecycle. The original release verification summary was not retained; the PR lists planned TypeScript, production-build, safe-link, and browser checks.",
    "changes": [],
    "source": "docs/training-administration-user-manual-v4.3.md; GitHub PR #201"
  },
  {
    "version": "2.1.22",
    "release_date": "2026-10-08",
    "title": "Agency Items and Business Rules",
    "summary": "Resource Library now saves reusable items and agency-specific data sources and retention periods, with agency business rules reports and PDF export.",
    "initial_problem": "Resource Library had no saved agency/item registry for agency-specific data sources, retention rules, expected outcomes, or an agency business rules PDF.",
    "fix_summary": "Added Agencies, Item catalog, Agency Item Assignment, and Agency Business Rules Report. Reuses shared agencies, including agencies created before their first training request. Saves each item once, keeps data sources and retention separate for each agency/item pair, filters assignments by agency, and exports compact shaded PDFs with long-content continuation. Administrators and Coordinators edit; active Trainers and Viewers review/export. Includes stale-edit protection, page descriptions, administrator test-data cleanup categories, the App User Guide, and manual v4.4.",
    "verification_summary": "TypeScript and production build passed. Rollback database tests verified later training reuses a preregistered agency without changing its address or rules, duplicate item/pair constraints, foreign keys, retention validation, administrator/coordinator writes, trainer/viewer reads with denied edits, inactive/anonymous denial, stale updates, legacy address synchronization, and exact reviewed cleanup of both linked assignments. Actual React component tests verified create/edit, filtered agency assignments, selected-agency report isolation, legacy address/contact preservation, network-error retry, and role controls. Actual PDF tests verified two items fit one page, selected-agency isolation, empty reports, and all long description/outcome text preserved across pages. No test records retained.",
    "changes": [
      {
        "component": "Agencies",
        "change_summary": "Reuse existing Agency Directory records. Create agencies without training history or contact information; later training reuses the same agency when linked by ID or matching name.",
        "sort_order": 1
      },
      {
        "component": "Item Catalog",
        "change_summary": "Save Tool, Dashboard, Smart Tool, or Misc. items with description and expected outcome once.",
        "sort_order": 2
      },
      {
        "component": "Agency Item Assignment",
        "change_summary": "Select agency first, assign a saved item, and store the agency-specific data source and retention period. Lists filter to the selected agency; duplicate pairs and stale edits are rejected.",
        "sort_order": 3
      },
      {
        "component": "Agency Business Rules Report",
        "change_summary": "Selected-agency report with agency information, compact alternating shading, data source/retention before description/outcome, and PDF export with page numbers and long-text continuation.",
        "sort_order": 4
      },
      {
        "component": "Access and Cleanup",
        "change_summary": "Database-enforced manager edits and active-user reads. New item and assignment categories use the existing reviewed administrator test-data cleanup.",
        "sort_order": 5
      },
      {
        "component": "User Manual",
        "change_summary": "App User Guide and manual v4.4 document each page, role permissions, agency reuse for future training, and PDF export.",
        "sort_order": 6
      }
    ],
    "source": "database/release_2_1_22_manual_and_history.sql"
  },
  {
    "version": "2.1.23",
    "release_date": "2026-10-08",
    "title": "Agency Import and Duplicate Prevention",
    "summary": "Import agency CSV files and review unfamiliar training-request agency names.",
    "initial_problem": "Free-text public submissions could create duplicate agencies and overwrite registered details; agencies required individual entry.",
    "fix_summary": "Public submissions only link established matching names. Unknown names remain on requests for Administrator review. Added the internal agency-match selector and manager-only CSV import with template, preview, row exclusion, duplicate skipping, and atomic database saves. Existing records and business rules are preserved.",
    "verification_summary": "Rollback database tests exercised the actual anonymous submission RPC, known-name matching, repeated unknown names without agency creation, registry preservation, Administrator linking without losing submitted details, repeated and within-file import duplicates, ZIP zeros, atomic invalid-import rollback, and denied anonymous/trainer imports. CSV parser tests, TypeScript, production build, component checks, and existing PDF checks passed. No test records retained.",
    "changes": [
      {
        "component": "Agency Import",
        "change_summary": "Import Data button, CSV template, preview, row exclusion, name duplicate skipping, and atomic save. Administrator and Coordinator access only.",
        "sort_order": 1
      },
      {
        "component": "Public Training Requests",
        "change_summary": "Match existing agency names ignoring case and repeated spaces; unfamiliar names require review. Public submissions do not create agencies or change their saved details.",
        "sort_order": 2
      },
      {
        "component": "Agency Match",
        "change_summary": "Administrators select the registered agency in Edit Training Requests. Original submitted agency name, address, and contacts remain on the request.",
        "sort_order": 3
      },
      {
        "component": "User Manual",
        "change_summary": "App User Guide and manual v4.5 explain CSV import and agency duplicate review.",
        "sort_order": 4
      }
    ],
    "source": "database/release_2_1_23_manual_and_history.sql"
  },
  {
    "version": "2.1.24",
    "release_date": "2026-10-08",
    "title": "Independent Business Rules Agencies",
    "summary": "Business Rules now uses a separate internal agency registry for forms, imports, assignments, and reports.",
    "initial_problem": "Internal Business Rules agencies shared the training Agency table, coupling business rules to unrelated training agency names, edits, and deletion.",
    "fix_summary": "Created a dedicated internal Business Rules agency table with a one-time name/address snapshot preserving agency IDs and existing assignment IDs, data sources, and retention periods. No contacts, training links, or ongoing synchronization. Agency forms, imports, assignments, and PDF reports now use the internal registry. Cleanup distinguishes Business Rules and Training agencies. Training request matching opens the training Agency Directory. Updated App User Guide and manual v4.6.",
    "verification_summary": "Rollback migration tests preserved a preexisting agency and assignment without modifying training contacts. Database tests verified separate identities for matching names, bidirectional edit isolation, training deletion isolation, actual anonymous submission isolation, transactional imports and duplicate checks, stale edit protection, manager imports, staff read permissions, inactive/anonymous denial, and reviewed Business Rules cleanup without touching training or shared catalog items. Existing training and registry database regressions, TypeScript, production build, CSV parser, actual React component, and PDF checks passed. Test records rolled back.",
    "changes": [
      {
        "component": "Business Rules Agencies",
        "change_summary": "Dedicated internal registry with preserved migrated names, addresses, IDs, and existing assignments. Training contacts are excluded; future changes are independent.",
        "sort_order": 1
      },
      {
        "component": "Agency Form and Import",
        "change_summary": "Create/edit and CSV imports use the internal agency registry with duplicate skipping, atomic saves, preview, and existing staff permissions.",
        "sort_order": 2
      },
      {
        "component": "Assignments and Reports",
        "change_summary": "Assignments reference internal agencies. Data sources, retention periods, item details, and PDF reports are preserved.",
        "sort_order": 3
      },
      {
        "component": "Test Data Cleanup",
        "change_summary": "Separate Business Rules agencies and Training agencies categories. Reviewed internal agency cleanup includes its assignments and preserves training records and shared catalog items.",
        "sort_order": 4
      },
      {
        "component": "User Manual",
        "change_summary": "App User Guide and manual v4.6 explain the independent registry. Training agency matching opens the training Agency Directory.",
        "sort_order": 5
      }
    ],
    "source": "database/release_2_1_24_manual_and_history.sql"
  },
  {
    "version": "2.1.25",
    "release_date": "2026-10-08",
    "title": "Business Rules Header Access",
    "summary": "Business Rules is now a standalone module with permission-aware access beside the version badge.",
    "initial_problem": "Business Rules had an independent agency registry but remained under Resource Library without direct header navigation.",
    "fix_summary": "Moved forms, import, assignments, and PDF reports to /business-rules. Added a Business Rules header button beside the version badge for verified active Administrators, Coordinators, Trainers, and Viewers; signed-out, inactive, and unknown profiles do not see it. Rechecks profile status on header refresh, guards stale profile responses, supports keyboard focus and smaller-screen wrapping, removes the Resource Library link, and redirects old bookmarks with query parameters intact. Guide, manual v4.7, and release history updated.",
    "verification_summary": "TypeScript and production build passed. Actual React header tests verified all four staff roles, beside-version placement, hidden controls for inactive/unknown/error/signed-out/pending profiles, late sign-out response protection, current-page marker, and deactivation refresh. Actual Business Rules component checks, CSV import tests, and PDF regressions passed after the move. Legacy redirect tests verified tab preservation, repeated/encoded parameters, and a fixed internal destination. No database registry schema or records changed by this release.",
    "changes": [
      {
        "component": "Header Access",
        "change_summary": "Business Rules button beside the version badge, shown only for a verified active staff profile with access. Profile refresh and stale-response protection keep visibility accurate.",
        "sort_order": 1
      },
      {
        "component": "Business Rules Module",
        "change_summary": "Standalone /business-rules page with Agencies, Item catalog, Agency Item Assignment, and Agency Business Rules Report; existing registry and staff permissions retained.",
        "sort_order": 2
      },
      {
        "component": "Navigation and Bookmarks",
        "change_summary": "Removed the Business Rules link from Resource Library. Old /library/business-rules bookmarks redirect to the new route with query parameters preserved.",
        "sort_order": 3
      },
      {
        "component": "User Manual",
        "change_summary": "App User Guide and manual v4.7 explain the header button, permissions, standalone page, and old-link redirects.",
        "sort_order": 4
      }
    ],
    "source": "database/release_2_1_25_manual_and_history.sql"
  },
  {
    "version": "2.1.26",
    "release_date": "2026-10-08",
    "title": "Bulk Agency Tool Assignments",
    "summary": "Assign multiple tools together with a compact agency-specific workspace.",
    "initial_problem": "Assigning tools one at a time required repeated form entry and scrolling between agency selection, tool details, and saved assignments.",
    "fix_summary": "Added searchable multi-tool selection, a compact table with per-tool data source and retention, an Assigned view for editing existing rules, and sticky agency/save controls. Save up to 100 new and edited assignments together using a security-invoker atomic database function with manager permissions, validation, duplicate protection, and optimistic concurrency. Failed saves retain entered values. Updated guide, manual v4.8, and release history.",
    "verification_summary": "TypeScript and production build passed. Actual React component checks verified multi-tool save, retained drafts on failure, agency filtering, existing edits, report isolation, CSV import, retry, and role controls with mocked transport. Database transaction checks verified batch insert/update, unchanged unrelated rows, stale and duplicate rejection, invalid-row rollback, inactive agencies and profiles, Administrator/Coordinator permissions, and Trainer/Viewer/anonymous denial. CSV, PDF, header, and navigation regression checks passed.",
    "changes": [
      {
        "component": "Agency Item Assignment",
        "change_summary": "Search and select multiple tools; edit per-tool source and retention in one compact table; review and edit existing agency assignments through Assigned.",
        "sort_order": 1
      },
      {
        "component": "Batch Save",
        "change_summary": "Up to 100 assignments saved atomically. Invalid rows or concurrent changes leave the whole batch unchanged; existing role permissions remain enforced.",
        "sort_order": 2
      },
      {
        "component": "Workspace Layout",
        "change_summary": "Sticky agency/save controls, bounded tool list, shaded assignment rows, and responsive layout reduce scrolling.",
        "sort_order": 3
      },
      {
        "component": "User Manual",
        "change_summary": "Guide and manual v4.8 explain bulk selection, edits, save behavior, and conflict recovery.",
        "sort_order": 4
      }
    ],
    "source": "database/release_2_1_26_manual_and_history.sql"
  },
  {
    "version": "2.1.27",
    "release_date": "2026-10-08",
    "title": "Agency CSV Upload Button",
    "summary": "The Agency form CSV button now opens file upload instead of downloading a template.",
    "initial_problem": "The visible agency CSV button downloaded a template instead of opening a CSV upload.",
    "fix_summary": "Replaced Download template with Upload CSV in the same position on the Agency form. The button opens the existing CSV file picker, previews rows, and imports only after review. Removed the separate import button and template download; required CSV column names are displayed beside the upload action. Updated guide, manual v4.9, and release history.",
    "verification_summary": "TypeScript, production build, and agency CSV parser checks passed. Actual React component checks with mocked transport verified the Upload CSV button invokes the file input in the expected location, the template button is absent, and preview/import, duplicate skipping, and role restrictions remain functional. Live page and deployed JavaScript checked after release.",
    "changes": [
      {
        "component": "Agency CSV Upload",
        "change_summary": "Upload CSV replaces Download template in the same location and opens the file picker, followed by the existing preview and import workflow.",
        "sort_order": 1
      },
      {
        "component": "User Manual",
        "change_summary": "Guide and manual v4.9 explain uploading an existing CSV and list required columns.",
        "sort_order": 2
      }
    ],
    "source": "database/release_2_1_27_manual_and_history.sql"
  },
  {
    "version": "2.1.28",
    "release_date": "2026-10-08",
    "title": "Prominent Agency CSV Upload",
    "summary": "Upload CSV now stands out beside the Agency form heading.",
    "initial_problem": "Upload CSV blended into instructional text and was difficult to find.",
    "fix_summary": "Moved Upload CSV to the right of Create/Edit agency with a blue primary style, upload icon, hover and keyboard focus states, and a full-width mobile layout. Existing file picker, preview, and import behavior retained. Guide, manual v4.10, and release history updated.",
    "verification_summary": "TypeScript and production build passed. Existing React component checks with mocked transport verified header placement, decorative icon, file-picker activation, preview/import, and role controls. Live page and deployed JavaScript checked after release.",
    "changes": [
      {
        "component": "Agency CSV Upload",
        "change_summary": "Prominent blue Upload CSV button beside the Create/Edit agency heading, with upload icon, keyboard focus styling, and responsive full-width mobile placement.",
        "sort_order": 1
      },
      {
        "component": "User Manual",
        "change_summary": "Guide and manual v4.10 explain the prominent upload button and existing CSV workflow.",
        "sort_order": 2
      }
    ],
    "source": "database/release_2_1_28_manual_and_history.sql"
  },
  {
    "version": "2.1.29",
    "release_date": "2026-10-08",
    "title": "Gold Dashboard Return Buttons",
    "summary": "Dashboard return links now use consistent prominent gold buttons.",
    "initial_problem": "Dashboard return actions appeared as plain text links with inconsistent visibility across screens.",
    "fix_summary": "Applied a shared gold button style with dark navy text to all 27 dashboard return actions across 23 screens, including error pages. Added consistent spacing, hover and active states, clear keyboard focus, and 44-pixel touch targets. The global error screen loads the shared stylesheet; conditional public-form navigation retains its original destination. Guide, manual v4.11, and release history updated.",
    "verification_summary": "TypeScript and production build passed. Reviewed all dashboard return anchors for consistent shared classes and unchanged destinations. Existing React component checks passed with mocked transport. Verified the production page, deployed JavaScript and gold styling stylesheet after release.",
    "changes": [
      {
        "component": "Dashboard Navigation",
        "change_summary": "Gold dashboard return buttons across 23 screens, sharing consistent contrast, spacing, hover, keyboard focus, and touch-target styling.",
        "sort_order": 1
      },
      {
        "component": "User Manual",
        "change_summary": "Guide and manual v4.11 explain the consistent gold dashboard return action.",
        "sort_order": 2
      }
    ],
    "source": "database/release_2_1_29_manual_and_history.sql"
  }
]
$release_history$::jsonb) as r(
    version text, release_date date, title text, summary text,
    initial_problem text, fix_summary text, verification_summary text, changes jsonb
  )
), inserted as (
  insert into public.training_app_versions (
    version, release_date, title, summary, is_current,
    initial_problem, fix_summary, verification_summary
  )
  select version, release_date, title, summary, false,
    initial_problem, fix_summary, verification_summary
  from recovered
  on conflict (version) do nothing
  returning id, version
)
insert into public.training_app_version_changes (version_id, component, change_summary, sort_order)
select i.id, c.component, c.change_summary, c.sort_order
from inserted i
join recovered r on r.version = i.version
cross join lateral jsonb_to_recordset(r.changes) as c(component text, change_summary text, sort_order integer);

commit;
