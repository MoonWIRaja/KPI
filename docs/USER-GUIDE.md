# Merit Tracker User Guide

The same Flutter Web application is responsive for desktop and phone browsers. Accounts are invitation-only. Available pages and actions depend on the permissions assigned by the Owner.

## Sign in

1. Open the approved Merit Tracker URL and sign in with the invited account.
2. On first use, set a password using the invitation link.
3. Owner, CEO and users with elevated permissions must enroll and verify an authenticator TOTP code before using protected operations.
4. Staff accounts open their own merit page by default. Ask the Owner if an expected page is unavailable.

On the first visit before an Owner exists, the app opens the Sediakan sistem anda screen instead of normal sign-in. The operator first creates a confirmed Auth user in Supabase and allowlists that exact email in the private setup row. The Owner signs in from the first-run screen, sets a display name and new password in the one-time wizard, then enrolls TOTP. The database locks the claim atomically. After setup completes, first-run is permanently hidden and normal sign-in is shown. Public account creation stays disabled.

## Owner and management workflows

### Staff records

- Add a staff member with a unique staff code, name, optional department and initial merit. The organization default is `5.0` unless changed in Settings.
- Edit staff details or archive/restore a record. Archive preserves history.
- Permanent deletion is available only when the staff record has neither a linked user account nor merit history.
- Score floor and ceiling are optional. Once configured, a setting cannot be saved if existing scores fall outside the proposed bounds.

### Import a CSV

1. Open the staff page and choose **Import CSV**.
2. Upload a UTF-8 CSV, up to 2 MB and 500 data rows. Required columns are `staff_code`, `full_name`, and `starting_merit`; `department` is optional. Common aliases for code/name/score are accepted and shown in the dialog.
3. Review the preview and row errors. Duplicate codes, invalid scores and malformed rows must be resolved before commit.
4. Confirm import to add all rows in one transaction. If validation fails, no partial import is committed.

### Adjust or correct merit

1. Select a staff member and choose **Adjust merit**.
2. Select an increase or decrease from `0.1` to `1.0` in `0.1` steps, enter the reason, review the resulting score and confirm.
3. The database records the actor, reason, before/after score and timestamp with the score update atomically.
4. If an existing entry needs correction, use the correction workflow. It appends a compensating event; it does not erase the original history.

### Users and permissions

- The Owner can invite a CEO or Staff account. Staff invitations must be linked to an unassigned staff record.
- The Owner can grant or revoke individual permissions and activate/deactivate accounts. Deactivation removes application access; it does not delete the audit or merit history.
- Elevated users are required to use TOTP MFA. Grant permissions sparingly.
- Public self-registration is disabled. Invitation and recovery emails require the project's configured SMTP provider.

### Reports and audit

- Filter the permitted merit history by month and direction. Scope is enforced by Supabase, not just by UI filters.
- Export a CSV only when `reports.export` is granted. The export includes the visible audit fields and records an export audit event.
- Store downloaded reports in the organization's approved private location. CSV exports may contain employee information.
- The Audit page is visible only to accounts with `audit.read`.

## Email and account recovery

Supabase Auth sends invitation and recovery links through the SMTP service configured by the project owner. If delivery fails, contact the Owner to check Auth SMTP, sender verification, redirect allowlist and Supabase function logs. Do not share invitation or reset links.

## Phone use

Open the same HTTPS URL in a phone browser while online. The app uses the same account, permissions and data as desktop. There is no separate native Android/iOS package in this repository; access from outside the office depends on the Owner's hosting and network policy.

## Privacy

Merit history and reasons are sensitive employee records. Use only for the approved internal purpose. Do not put real staff data in GitHub, issue reports, screenshots or unapproved exports. Follow the organization's retention, correction and deletion policy.
