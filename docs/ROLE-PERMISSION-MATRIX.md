# Roles and Permissions

The current schema enforces permissions through Supabase RLS and trusted functions. The Owner has full application authority (except immutable audit/ledger history); CEO defaults to staff and merit management; Staff defaults to self-only merit access. The Owner can grant eligible permissions individually. Owner invitation, user management and protected permissions stay Owner-only.

## Default access

| Capability | Owner | CEO default | Staff default |
|---|---:|---:|---:|
| Read self profile | Yes | Yes | Yes |
| Read staff directory and all merit history | Yes | Yes | No |
| Add/edit/archive staff and import CSV | Yes | Yes | No |
| Delete staff without history/account link | Yes | No | No |
| Adjust or correct merit | Yes | Yes | No |
| Read/export reports | Yes | Yes | No |
| Change score settings | Yes | Yes | No |
| Read audit events | Yes | Yes | No |
| Invite users; manage accounts and permissions | Yes | No | No |
| Read own merit/history | Yes | Not applicable by default | Yes |

The Owner may assign role-assignable permissions to active CEO or Staff accounts. Any management permission beyond the two self permissions requires TOTP MFA/AAL2. Database functions also enforce each required permission, so hiding a page is not the security boundary.

## Permission catalog

| Permission | Default grant | Enforcement |
|---|---|---|
| `account.read.self` | CEO, Staff | Own profile/permission view |
| `merit.read.self` | Staff | Merit rows linked to own profile only |
| `staff.read.all` | CEO | Directory and staff profile read |
| `staff.create` | CEO | Create a staff record |
| `staff.update` | CEO | Edit staff identity fields |
| `staff.archive` | CEO | Archive or restore while retaining history |
| `staff.delete` | None | Delete only with no linked account and no merit events |
| `staff.import` | CEO | Transactional CSV import, up to 500 records |
| `merit.read.all` | CEO | Read all authorized merit events |
| `merit.adjust` | CEO | Reason-required adjustment of 0.1–1.0 |
| `merit.correct` | CEO | Append a compensating correction event |
| `reports.read` | CEO | Read report events within RLS scope |
| `reports.export` | CEO | Export visible report rows and write audit event |
| `settings.manage` | CEO | Configure default score and optional bounds |
| `audit.read` | CEO | Read audit events |
| `users.manage` | Owner only | Grant permissions and activate/deactivate non-Owner users |
| `users.invite` | Owner only | Invite CEO/Staff through authenticated Edge Function |

Owner permissions are implicit in database policy and do not rely on client-supplied permission rows. Default grants for new CEO/Staff profiles are created by a database trigger.

## Rules and limits

- No permission means deny. Role and actor identity are derived from the authenticated profile, never request parameters.
- Staff self access resolves through the account-to-staff link; manipulating IDs does not grant cross-staff reads.
- Profiles, permissions, reports and audit data have row-level policies. Direct client writes to staff scores, merit events, permissions and audit events are revoked.
- The two baseline self permissions do not require an elevated MFA session. Owner/CEO access and any additional granted permission requires TOTP AAL2.
- Only the Owner may invite users, modify permissions, or activate/deactivate an account. Deactivation does not delete merit/audit history.
- A staff record with history or a linked login cannot be permanently deleted; archive it instead.
- No user can delete or rewrite a historical merit event through the application. Correction appends a new event.
