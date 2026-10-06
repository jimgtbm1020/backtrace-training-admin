begin;
update public.training_app_versions set is_current=false where is_current=true;
insert into public.training_app_versions(version,release_date,title,summary,is_current)
values('2.1.18','2026-10-06','Bug Tracking and Training Workflow Updates','Adds ticket references, priority, assigned ownership, status tracking, resolution summaries, and change history. Includes trainer acceptance and Teams links, live communications status, and certificate preservation fixes. The user guide and manual now document the current workflow.',true)
on conflict(version) do update set release_date=excluded.release_date,title=excluded.title,summary=excluded.summary,is_current=true;
delete from public.training_app_version_changes where version_id=(select id from public.training_app_versions where version='2.1.18');
insert into public.training_app_version_changes(version_id,component,change_summary,sort_order)
select id,c.component,c.summary,c.ordinal from public.training_app_versions v cross join (values
('Bug Reports','Every submission receives a BT-BUG reference. Administrators can assign an active administrator or coordinator, set priority, filter tickets, and record internal notes and change history.',1),
('Reporter Follow-Up','Signed-in submitters see their own reports, current status, priority, and resolution summary. Internal notes remain private. Public submitters retain their reference for follow-up.',2),
('Resolution Safeguards','Closing or resolving requires a resolution summary. Reopening clears resolution metadata. Stale updates are rejected and submitted problem details remain unchanged.',3),
('Trainer Workspace','Assigned active trainers can accept or decline with a reason and save approved Teams meeting links after acceptance. Reassignment resets the response.',4),
('Dashboard and Email','Dashboard communications status reflects live settings. Production email delivery was tested and receipt confirmed.',5),
('Certificates','Basic Backtrace Search certificates display 4 Hours. Repeat access preserves existing certificate details and avoids duplicate certificate emails.',6),
('User Manual','App User Guide updated to application v2.1.18. Manual v4.1 documents ticket submission, assignment, resolution, reopening, privacy, and the operational training workflow.',7)
) as c(component,summary,ordinal) where v.version='2.1.18';
update public.training_manual_versions set active=false,updated_at=now() where active=true;
insert into public.training_manual_versions(version,content,active,published_at,updated_at)
values('4.1','# Backtrace Training Administration — User Manual

Manual version 4.1 · Application version 2.1.18 · Updated October 6, 2026

Core workflow: Request → assign/schedule → generate class → attendance/check-in → close/finalize → certificates/history.

## 1. Dashboard

Audience: All active users

Use the dashboard as the operational starting point for open requests, upcoming training, agencies, and quick actions.

1. Review Open Requests, Received, Upcoming 30 Days, Unassigned, and Active Agencies.
2. Use Upcoming Training to see confirmed classes in the next 30 days.
3. Use Quick Actions to open Today, Requests, Attendance, Attendees, Agency History, or Completion.
4. Administrators also see read-only System Status, release lineage, and Bug Report summaries.

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

',true,now(),now())
on conflict(version) do update set content=excluded.content,active=true,published_at=excluded.published_at,updated_at=excluded.updated_at;
commit;