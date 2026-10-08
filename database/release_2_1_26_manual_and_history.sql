begin;
lock table public.training_app_versions,public.training_app_version_changes in share row exclusive mode;
update public.training_app_versions set is_current=false where is_current=true;
insert into public.training_app_versions(version,release_date,title,summary,is_current,initial_problem,fix_summary,verification_summary) values('2.1.26','2026-10-08','Bulk Agency Tool Assignments','Assign multiple tools together with a compact agency-specific workspace.',true,'Assigning tools one at a time required repeated form entry and scrolling between agency selection, tool details, and saved assignments.','Added searchable multi-tool selection, a compact table with per-tool data source and retention, an Assigned view for editing existing rules, and sticky agency/save controls. Save up to 100 new and edited assignments together using a security-invoker atomic database function with manager permissions, validation, duplicate protection, and optimistic concurrency. Failed saves retain entered values. Updated guide, manual v4.8, and release history.','TypeScript and production build passed. Actual React component checks verified multi-tool save, retained drafts on failure, agency filtering, existing edits, report isolation, CSV import, retry, and role controls with mocked transport. Database transaction checks verified batch insert/update, unchanged unrelated rows, stale and duplicate rejection, invalid-row rollback, inactive agencies and profiles, Administrator/Coordinator permissions, and Trainer/Viewer/anonymous denial. CSV, PDF, header, and navigation regression checks passed.') on conflict(version) do update set is_current=true,initial_problem=excluded.initial_problem,fix_summary=excluded.fix_summary,verification_summary=excluded.verification_summary;
delete from public.training_app_version_changes where version_id=(select id from public.training_app_versions where version='2.1.26');
insert into public.training_app_version_changes(version_id,component,change_summary,sort_order)
select v.id,c.component,c.summary,c.ordinal from public.training_app_versions v cross join (values
('Agency Item Assignment','Search and select multiple tools; edit per-tool source and retention in one compact table; review and edit existing agency assignments through Assigned.',1),
('Batch Save','Up to 100 assignments saved atomically. Invalid rows or concurrent changes leave the whole batch unchanged; existing role permissions remain enforced.',2),
('Workspace Layout','Sticky agency/save controls, bounded tool list, shaded assignment rows, and responsive layout reduce scrolling.',3),
('User Manual','Guide and manual v4.8 explain bulk selection, edits, save behavior, and conflict recovery.',4)
) c(component,summary,ordinal) where v.version='2.1.26';
update public.training_manual_versions set active=false,updated_at=now() where active=true;
insert into public.training_manual_versions(version,content,active,published_at,updated_at) values('4.8','# Backtrace Training Administration — User Manual

Manual version 4.8 · Application version 2.1.26 · Updated October 8, 2026

Core workflow: Request → assign/schedule → generate class → attendance/check-in → close/finalize → certificates/history.

## 1. Dashboard

Audience: All active users

Use the dashboard as the operational starting point for open requests, upcoming training, agencies, and quick actions.

1. Review Open Requests, Received, Upcoming 30 Days, Unassigned, and Active Agencies.
2. Use Upcoming Training to see confirmed classes in the next 30 days.
3. Use Quick Actions to open Today, Requests, Attendance, Attendees, Agency History, or Completion.
4. Administrators also see read-only System Status, release lineage, and Bug Report summaries.
5. Administrators and Trainers see Notifications Needing Attention above the metrics. Review unread notices, open actions, overdue actions, and the latest five items.
6. Use View notification to open notification history, or Take action to open the corresponding request, calendar, or Trainer Workspace.
7. Reading a notice does not complete its action. Pending assignment responses, declined assignments needing administration, missing assignment/scheduling, and current conflicts clear when the underlying request is resolved.
8. Counts refresh every 30 seconds while visible, when you return to the tab, and after read-status changes. Use Refresh notifications to retry a connection failure. Overdue dates use the request time zone.

Application page: /

## 2. Using Tooltips

Audience: All active users

Use the question-mark icons beside important controls for short, page-specific guidance.

1. Hover over or focus a question-mark icon to read its tooltip.
2. On a touch screen, tap the icon to open the tooltip and tap it again to close it.
3. Press Escape to close an open tooltip when using a keyboard.
4. Use this guide when you need the complete workflow, permissions, or record-protection rules.

Application page: /help

## 3. Training Requests

Audience: All active users; edits depend on role

Review agency requests, open a specific request, and share the public agency request form.

1. Open Training > Requests.
2. Search or filter the request list.
3. Use Agency Request Link & QR to copy the public form URL, open the form, or save its QR code.
4. Select Open on a request to go directly to that request record.
5. Use Download CSV to export the currently filtered request list.

Application page: /requests

## 4. Edit, Assign & Schedule a Request

Audience: Administrator / Coordinator / assigned Trainer

Maintain request details, assign a trainer, confirm the schedule, and add a Teams meeting link for virtual/hybrid training.

1. Open the request from Training Requests or a deep link.
2. Administrators can edit the full agency, contact, training-type, resource, module, and internal-note record.
3. Administrators and Coordinators choose the assigned trainer, confirmed date, and confirmed start time.
4. Select Confirm Schedule. The server checks trainer conflicts before saving.
5. For Virtual or Hybrid training, Administrators and Coordinators can save an approved Microsoft Teams meeting link. The assigned trainer can save it in Trainer Workspace after accepting the request.
6. Trainers can edit only unlocked requests they created or that are assigned to them.

Note: Completed, Closed, Archived, Cancelled, and Finalized records remain locked.

Application page: /requests/edit

## 5. Accept or Decline a Training Assignment

Audience: Assigned Trainer; Administrator / Coordinator review

Respond to an assigned request and provide the meeting link after accepting Virtual or Hybrid training.

1. Open Trainer Workspace and locate the assigned request.
2. Select Accept, or enter a decline reason and select Decline. Only the assigned active trainer can respond.
3. Administration receives an in-app notification, and the response is saved in the request history.
4. After accepting Virtual or Hybrid training, enter the Microsoft Teams Meeting Link and select Save Teams Link. In Person training does not show this field.
5. Administrators and Coordinators can review responses in Trainer Workspace and use Manage Request to change the assignment.
6. Reassigning a request resets its response to Pending. For classes that have not opened registration, the previous Teams link is cleared.

Note: Responses are locked once a class is In Progress, Closed, Completed, or Archived. Contact administration to change an existing response or decline a class with open registration.

Application page: /trainer-workspace

## 6. Training Calendar

Audience: All active users; scheduling is manager-only

Use month, week, or day views to manage the confirmed schedule, unassigned work, conflicts, and trainer workload.

1. Open Training > Calendar.
2. Switch between Month, Week, and Day.
3. Filter by trainer, status, or search text.
4. Select a scheduled event or an unassigned request to review details.
5. Administrators and Coordinators can set the trainer/date/time and select Save Schedule.
6. Resolve any overlap shown by the conflict check before saving.

Application page: /calendar

## 7. Today

Audience: All active users

Run the day-of-training workflow from one screen.

1. Open Training > Today.
2. Trainers see only classes assigned to them; other permitted roles see the scheduled day view.
3. Use Start Class when the class is ready to begin.
4. Open Attendance, the Request record, or Join Teams directly from the class card.
5. Use Close Class when training is finished; the workflow can hand off to Completion.

Application page: /today

## 8. Classes & Attendance

Audience: All active users with workflow permissions

Generate secure class access, manage roster eligibility, print class documents, issue certificates, and work with historical classes.

1. Open Training > Classes and Attendance.
2. Select an active class. Past/closed classes are never kept in the active-class selector.
3. Use Generate Class to create or rotate the secure attendance link. Rotating the link invalidates the previous token.
4. Copy Link, Open Public Page, or Download QR to share the self-service sign-up/check-in page.
5. After the class is generated, use Add Attendee for manual roster entry. Select Check in attendee now when the person is already present.
6. Use Generate Certificate only for an eligible checked-in attendee. Use Ineligible when a roster member should not receive a certificate; an already-issued certificate remains permanent.
7. Use Issue Certificates to Checked-In to process all eligible checked-in attendees that do not already have certificates.
8. Use Print Sign-In Sheet for the roster. Trainer Information PDF includes agency/contact details, Agency Trainer Contact Information, modules, resources, requirements, Teams information when applicable, attendance information, and directions.
9. Use Start Class and Close Class for the day-of-training lifecycle. A Closed class must be finalized in Completion before it becomes Completed.
10. Use Past Training Classes to search historical classes, open full details, print the class roster, export the search results or an individual class CSV, and view stored certificates. Historical documents use the actual training date when a finalized completion record provides one.

Note: The removed paper-sign-in import workflow is intentionally not part of the current application.

Application page: /classes

## 9. Completions & Certificates

Audience: Authorized training staff

Save completion drafts, finalize Closed classes, and review the permanent certificates tied to a completion.

1. Open Training > Completions and Certificates.
2. Closed classes appear under Closed — Awaiting Finalization.
3. Open a class and confirm the actual training date, start/end time, minutes, attendee count, modules completed, notes, follow-up, and optional agency feedback.
4. Use Save Draft when the record is not ready to finalize.
5. Use Finalize Completion only after the record is correct. Finalization marks the request/class Completed and applies the existing checked-in certificate issuance rules.
6. Use View in the Certificates column to list issued certificates for that completion.
7. Open certificates through their protected UUID/public-id record. Existing certificates are not regenerated when a completion is reviewed.

Application page: /completions

## 10. Attendee Directory

Audience: All active users

Search people rather than raw roster rows and review their full class/certificate history.

1. Open People > Attendees.
2. Search by name, email, Badge # / ID #, or agency.
3. Select a person to open their profile history.
4. Review classes, certificates, first seen, and last training metrics.
5. Open a stored certificate from the class-history table.
6. Use Download CSV for the filtered directory.

Application page: /attendees

## 11. Agency Directory

Audience: Administrator / Coordinator

Create, edit, activate, or deactivate agencies used by Requests and Agency Portal.

1. Open People > Agencies.
2. Search or filter Active/Inactive agencies.
3. Use New Agency to create an agency profile.
4. Use Edit to maintain agency and contact information.
5. Use Activate/Deactivate to control whether an agency is operational for manager workflows.
6. Export the filtered agency list to CSV when needed.

Application page: /agencies

## 12. Agency Training History

Audience: All active users

Review each agency’s training history, personnel trained, certificates, upcoming classes, and portal activity.

1. Open People > Agency History.
2. Search for and select an agency.
3. Review agency profile/contact information and summary metrics.
4. Review each historical class, trainer, attendance count, and certificate count.
5. Use Attendee Directory, Past Classes, or Completions when an individual certificate needs to be opened.

Application page: /agency-history

## 13. Agency Portal

Audience: Administrator / Coordinator

Create and revoke secure agency-specific Training Request links.

1. Open People > Agency Portal.
2. Select Create Agency Portal Link.
3. Choose an active agency and enter a label.
4. Optionally set an expiration date/time and maximum submissions; leave maximum blank for Unlimited.
5. Create the link and copy the full URL immediately—the secure token is only returned at creation time.
6. Use Open Portal to test the generated link.
7. Use Revoke to close an active link when necessary.

Application page: /agency-portal/manage

## 14. Management Reports

Audience: Administrator / Coordinator

Use the management analytics dashboard for demand, completion, workload, agency activity, tools, and request detail.

1. Open Training > Reports.
2. Choose This Year, Last 90 Days, Last 30 Days, All Time, or a custom date range.
3. Review completion rate, training hours, attendees, lead time, and Needs Action.
4. Review monthly volume, trainer workload, agency activity, requested tools, and request detail.
5. Use Print Report or Export CSV for the current date range.

Application page: /reports

## 15. Notifications

Audience: All active users

Review in-app notifications, generate reminders, and maintain read/unread state.

1. Open Notifications.
2. Use Check Reminders to generate deduplicated in-app reminders.
3. Filter by Unread/Read, notification type, or search text.
4. Use Open when a notification contains a valid Backtrace action.
5. Use Mark Read, Mark Unread, or Mark All Read as needed.
6. The navigation badge updates when unread state changes.

Application page: /notifications

## 16. Email Settings

Audience: Administrator

Review the live delivery, queue, provider, webhook, tracking, template, and recent-event state.

1. Open Administration > Email Settings.
2. Confirm Delivery and Delivery Cron show the authorized live state.
3. Review Queue Pending and Failed before any distribution.
4. Confirm Webhook Processing and Tracking remain disabled unless separately authorized.
5. Review configured templates and recent provider delivery events.
6. This page is read-only and cannot change communications settings.

Application page: /email-settings

## 17. Resource Library

Audience: All active users; management is Administrator / Coordinator / Trainer

Browse and version training resources, attach exact published versions to classes, create secure student links, and queue resource distributions.

1. Open Resource Library from the main navigation.
2. Search or filter by state, resource type, product, module, or audience. State assignments and audience are separate: Student + Trainer resources may be shared externally; Trainer Only resources remain internal.
3. Use View to open the current published file and Versions to review version history. Authorized training staff can select Make Current to publish a prior version.
4. Administrators, Coordinators, and Trainers can Add Resource, upload a New Version, or Archive a resource. New uploads are published through the version-publishing workflow.
5. Files up to 512 MB are supported. Files over 6 MB use resumable 6 MB upload chunks with retries and upload progress.
6. Select one or more current resource versions and choose a training class. Use Attach to Class to preserve those exact versions with the class record.
7. For Student + Trainer resources, use Copy Secure Link to create a 30-day student link.
8. Email Attendees queues secure distribution messages for all registered attendees or custom addresses. Delivery follows the live Email Settings state, so verify recipients and the queue before submitting.
9. National / General should be used only for resources that apply everywhere; otherwise select the applicable state or states.

Application page: /library

## 18. User Management

Audience: Administrator

Create and administer Training Administration user accounts.

1. Open Administration > Users.
2. Create a Trainer, Coordinator, or Administrator and provide the generated temporary password directly to the user.
3. Edit the user name, role, and active status as needed.
4. Existing users can also be assigned Viewer.
5. Use Reset Password only when a new temporary password is required.
6. Review the Administration Activity list for recent account-management actions.

Application page: /user-management

## 19. Activity & Audit History

Audience: Administrator

Review exact Backtrace Training audit history across requests, users, agencies, attendance, authentication, and administration.

1. Open Administration > Activity.
2. Use the 7 / 30 / 90 Days or All presets, or set a custom range.
3. Filter by user/system actor, category, or search text.
4. Use View Details to inspect changed fields and previous/new values.
5. Export the filtered audit history to CSV.

Application page: /activity

## 20. Bug Reports

Audience: Administrator; submission is public/authenticated

Track each submitted problem with a ticket number, priority, owner, and change history.

1. Select Report a Problem, describe the steps and expected behavior, and optionally provide contact details. Keep the ticket number shown after submission.
2. Signed-in submitters can use My Reports on Report a Problem to see their own statuses and resolution summaries.
3. Administrators open Administration > Bug Reports and search by ticket, summary, or contact; filter by status, priority, or owner.
4. Open a ticket, assign an active administrator or coordinator, set priority, and move it through Open, In Review, Resolved, or Closed.
5. Enter a resolution summary before resolving or closing a ticket. Internal administrator notes remain private; the resolution summary is visible to the signed-in submitter.
6. Review Change history for who changed each field and when. Refresh before saving if another administrator updated the ticket.
7. Reopen an issue by changing its status to Open or In Review, recording the reason in administrator notes, and selecting Save ticket.

Note: Public submitters receive a reference number. My Reports is available for reports submitted while signed in. Assigning a coordinator records responsibility; only administrators can edit tickets.

Application page: /bug-reports

## 21. System Status & Communications Safety

Audience: Administrator

Review production safeguards without changing protected features.

1. Open Administration > System Status.
2. Confirm Training Administration version and the GitHub + Vercel + Supabase architecture.
3. Confirm Release Writes remain OFF.
4. Confirm Email Delivery reflects the authorized live state. Webhooks and Tracking remain OFF unless separately authorized.
5. Review Email Delivery Cron status together with Email Delivery before sending.
6. Confirm the protected email-queue DELETE/TRUNCATE guard is ON.
7. Review the live email queue count before any distribution.
8. Run read-only connectivity checks when needed.

Note: The demo email queue was intentionally cleared. Continue to verify recipients, queue totals, and the live delivery state before sending.

Application page: /health

## Release notes — 2.1.18

- Bug reports receive a unique reference number. Administrators track priority, ownership, status, private notes, public resolution summaries, and change history. Signed-in submitters can review their own reports.
- Trainer Workspace supports acceptance, decline reasons, and approved Microsoft Teams links after acceptance.
- Dashboard communications status reads the live delivery settings.
- Basic Backtrace Search certificates display 4 Hours. Reopening an existing certificate preserves its original attendee details and avoids duplicate delivery.
- Production email delivery was tested and receipt confirmed. Consult live Email Settings for the current queue and delivery state.



## 22. Test Data Cleanup

Audience: Administrator

Remove exact test records and their linked database records through a reviewed cleanup.

1. Open Administration > Test Data Cleanup.
2. Choose a record category, search, and select only records you know are test data. Selections can span categories.
3. Select Preview cleanup and review every linked record. Download the preview CSV if needed.
4. If shared records block deletion, remove the shared parent or add the linked record only if it is also test data.
5. Confirm all listed records are test data and type the exact DELETE count TEST RECORDS phrase shown.
6. Select Delete reviewed test data. Record the cleanup reference; deleted certificates and share links stop working.
7. Create a new preview if records changed or the 15-minute preview expired.

Application page: /test-data-cleanup

Important: Completed test classes and test certificates can be removed through this workflow. Sign-in accounts, uploaded files, system settings, numbering counters, release history, manuals, and audit logs are excluded. A restricted audit snapshot of deleted database rows is retained. Sent emails cannot be recalled.


## Agency Items & Business Rules

Audience: All active users; edits are Administrator / Coordinator

Application page: /business-rules

1. Select Business Rules beside the version badge in the application header.
2. In Agencies, use an existing agency or create one with its name and address. An agency does not need previous training or contact information. These are internal Business Rules agencies in a separate registry from the training Agency Directory, Training Requests, and Agency Portal. Training history is not required.
3. Business Rules agency creation, edits, and imports affect only this internal registry. Public training submissions do not create, update, or match these records. Training agencies remain in their separate Agency Directory. There is no automatic synchronization between the registries. Use established names and review spelling variants to avoid duplicates within the internal registry.
4. In Item catalog, save the item name, type (Tool, Dashboard, Smart Tool, or Misc.), description, and expected outcome once.
5. In Agency Item Assignment, choose the agency once. Search Add tools and select several tools with the checkboxes. Enter a separate data source, retention value, and unit (Days, Months, or Years) for every row in Assignment details.
6. Select Save assignments to save up to 100 new or edited agency/item pairs together. Use Assigned and Edit to load existing rules into the same editable table. Search filters the current agency’s tools. Agency and save controls stay visible while scrolling. Save or clear your selection before switching agencies. If any row is invalid or changed by another user, none of the batch is saved and entered values remain. After a conflict, clear selection, refresh records, and select the affected tools again.
7. In Agency Business Rules Report, choose the agency and review its name/address, assigned items, data sources, retention periods, descriptions, and expected outcomes. Export PDF produces a compact report with alternating section shading and page numbering. Long descriptions continue onto additional pages.
8. Administrators and Coordinators can create and edit agencies, catalog items, and assignments. Trainers and Viewers can review records and export reports. Inactive or signed-out users cannot access registry records.
9. Changes to shared item details appear in every agency report using the item. Data source and retention remain separate for each agency/item assignment. Business rules do not rewrite historical training records. Retention periods are documented rules; this feature does not automatically purge source-system data.
10. If another user changes a record while you are editing it, refresh and review the record before saving again.
11. Administrators can delete known test records through Test Data Cleanup. Select Business Rules agencies for this registry or Training agencies for training records. Review all linked assignments before confirming deletion. Business Rules agency cleanup includes its assignments and preserves training agencies and shared catalog items. Training agency cleanup does not include Business Rules assignments.

## Release notes — 2.1.22

- Original problem: Resource Library had no saved agency/item registry for agency-specific data sources, retention rules, expected outcomes, or an agency business rules PDF.
- Fix: Added Agencies, Item catalog, Agency Item Assignment, and Agency Business Rules Report with reusable shared agencies, saved catalog items, agency-specific assignments, filtered lists, page descriptions, compact PDF export, role permissions, and concurrent-edit protection.
- Added catalog items and assignments to the existing exact-record administrator test-data cleanup workflow.
- Updated the App User Guide and manual to document the registry and its connection to future training requests.

## Agency import

Audience: Administrator / Coordinator

1. Select Business Rules beside the version badge, then Agencies. Select Import Data on the Agency form.
2. Download the CSV template. Columns are Agency Name, Street Address, City, State, ZIP; only Agency Name is required. Save Excel files as CSV first. ZIP is treated as text to preserve leading zeros. No contact details are imported.
3. Upload a CSV up to 1 MB with at most 500 agency rows. Review the preview and exclude names that are alternate spellings or abbreviations of an existing agency. Cancel import saves nothing.
4. Select Import new agencies. Names that match existing agencies or another row, ignoring capitalization and repeated spaces, are skipped. Existing internal agency details, inactive status, and business rules are preserved. Training agencies are not imported or updated by this button. The database rechecks names while saving.
5. All rows save together. Invalid data or a permission error saves no rows. Correct the file and preview again. Trainers and Viewers cannot import.

## Release notes — 2.1.23

- Original problem: Free-text agency submissions could create duplicate agencies and overwrite registered agency details. Agencies also had to be entered one at a time.
- Fix: Public training requests match established names without changing registry data. Unrecognized names wait for Administrator review. Added an internal agency-match selector and a CSV Import Data button with template, preview, row exclusion, duplicate skipping, transactional saves, and database permissions.

## Release notes — 2.1.24

- Original problem: The internal Business Rules workflow shared agency records with training, exposing it to free-text training names and unrelated training agency changes.
- Fix: Added a separate internal Business Rules agency registry. Existing agencies are copied once without contact information, and saved assignment IDs, sources, and retention periods are preserved. Future creation, edits, imports, and deletes are independent of training.
- Agency Form, import, assignments, and PDF reports use the internal registry. Administrator/Coordinator edits and Trainer/Viewer reads remain available only to active signed-in staff.
- Test Data Cleanup distinguishes Business Rules agencies from Training agencies. The training request editor opens the training Agency Directory for agency matching.

## Business Rules navigation

- Business Rules is a separate application module at /business-rules. Select the Business Rules button beside the version badge in the header; the first tab opens Agencies.
- The button appears only after an active Administrator, Coordinator, Trainer, or Viewer profile is verified. Administrators and Coordinators create/import/edit; Trainers and Viewers review and export reports. Signed-out, inactive, or unrecognized profiles do not see the button and cannot access registry records.
- The button marks the current Business Rules page, supports keyboard focus, and wraps with the version badge on smaller screens. Staff profile access is rechecked during header refresh and on window focus.
- Resource Library contains training resources. Its former Business Rules navigation link has been removed. Old /library/business-rules bookmarks redirect to the new page and retain query parameters such as the selected tab.

## Release notes — 2.1.25

- Original problem: The independent Business Rules module was still placed under Resource Library and had no direct header access.
- Fix: Moved forms and reports to /business-rules and added a Business Rules button beside the version badge, visible only to verified active staff with access. Removed Resource Library navigation and retained old-link redirects. Updated the App User Guide, manual v4.7, and release history.

## Release notes — 2.1.26

- Original problem: Assigning tools one at a time required repeated form entry and scrolling between agency selection, tool details, and saved assignments.
- Fix: Added searchable multi-tool selection, a compact editable assignment table, an Assigned view for existing rules, and visible agency/save controls. Each tool retains its own agency data source and retention period.
- Save up to 100 new and edited assignments in one atomic batch. Invalid rows, duplicate pairs, and concurrent changes roll back the entire batch. Entered values remain available after a failed save.
- Updated App User Guide, manual v4.8, and release history. Existing assignments and PDF reports are preserved.
',true,now(),now()) on conflict(version) do update set content=excluded.content,active=true,published_at=now(),updated_at=now();
commit;
