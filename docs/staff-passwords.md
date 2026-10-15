# Staff passwords and account recovery

## New accounts and administrator password resets
1. An Administrator creates the account or generates a temporary password in User Management.
2. Create User automatically emails the user their sign-in email, temporary password, production sign-in link, and replacement instructions. Email Settings must be enabled and configured before creating an account.
3. The user signs in with their email and temporary password.
4. Before the application dashboard is shown, Account Setup asks for Temporary password, New password, and Confirm new password.
5. Save password verifies the temporary password on the server, updates only that user's password, and clears the replacement requirement.
6. The user continues to the dashboard and uses their new password for later sign-ins.

Existing accounts are not automatically marked as temporary. To require replacement for an existing account, an Administrator can issue a new temporary password using Reset Password.

## Account email status
Create User reports whether Resend accepted the account email. Temporary passwords are not written to audit records; audit entries contain only the recipient, provider message ID, and success/failure state. Transient provider errors are retried using the same idempotency key.

If delivery cannot be confirmed, the account remains created and the administrator sees a clear warning and the temporary password to provide directly. Do not create the user again. An administrator Reset Password still displays the new temporary password for direct sharing.

## Changing an existing password
Open My Account and enter the current password, new password, and confirmation. Passwords must contain 8–128 characters and differ from the current password.

## Forgotten passwords
Enter the registered email on the sign-in page and choose Forgot password?. Check the inbox and spam folder. Open the secure recovery link and choose a new password without entering the forgotten password. An invalid or expired link requires a fresh request. The interface waits 60 seconds before permitting another request; the server also limits requests per email, IP address, and application.

The server requires a verified, recent recovery authentication method before accepting a reset without the current password. Reset requests show a generic response to avoid revealing whether an email has an account.

## Permissions and implementation
Only active Administrators, Coordinators, Trainers, and Viewers can save a password. The server obtains the target identity from the validated user token rather than accepting a target user ID. The replacement flag is held in administrator-controlled app metadata, not user-editable metadata. The application shell blocks dashboard rendering during required setup and recovery.

Password values are handled by Supabase Auth. They are not stored in application tables, local storage, audit records, or logs. Fields clear after saving. All existing role and database permissions remain in effect.

## Validation and rollout
TypeScript, production build, actual React form/gate tests, and server-function tests passed. Tests cover incorrect current passwords, mismatched confirmation, replacement flags on create/reset, self-only updates, spoofed and expired recovery claims, and inactive/anonymous access denial. No real passwords or reset emails were used in these tests.

Deploy manage-training-users and request-password-reset with the matching application release. The public reset handler generates a Supabase recovery token, sends it through the configured Resend sender, and returns the same response for unknown accounts. The token is carried in the URL fragment, removed before verification, and consumed using Supabase verifyOtp. The manage-training-users handler validates each bearer token with Auth getUser, allowing current asymmetric signing keys without relying on the gateway legacy-JWT check. Confirm password recovery delivery using an authorized test mailbox after deployment; actual mailbox delivery remains unverified.
