# Role and Permission Matrix

**Status:** MVP role defaults implemented in the initial Supabase migration; custom role editor remains future work.

Permissions are assigned to roles and roles to accounts. Enforcement runs in Supabase RLS and trusted functions. `Self` means the staff record linked to the authenticated account; `All` means records within the authorized organization.

## 1. Proposed built-in roles

| Capability | Owner | CEO | Invited Staff |
|---|---:|---:|---:|
| Read own account | Yes | Yes | Yes |
| Read own merit/history | Yes | Yes | Yes |
| Read all staff/merit | Yes | Yes | No |
| Add/edit/archive staff | Yes | Add staff only | No |
| Set starting merit | Yes | When adding staff | No |
| Adjust merit | Yes | Yes | No |
| Correct merit | Yes | Yes | No |
| Import CSV | Yes | Yes | No |
| Read/export reports | Yes | Yes | No |
| Invite/disable/reset accounts | Yes | No | No |
| Manage roles/permissions | Yes | No | No |
| Configure score defaults/bounds | Yes | No | No |
| Manage email delivery | Supabase Dashboard only | No | No |
| Read audit/operational status | Yes | Service status only | No |

Protect the Owner from accidental removal/demotion. Only Owner invites users or assigns CEO/Staff roles in the MVP. TOTP MFA and AAL2 are required for Owner/CEO privileged access.

## 2. Permission catalog

| Permission key | Scope | Description |
|---|---|---|
| `account.read.self` | Self | Read own account/profile |
| `account.update.self` | Self | Change permitted account settings |
| `staff.read.self` | Self | Read linked staff profile only |
| `staff.read.all` | All | Read staff directory/profiles |
| `staff.create` | All | Create staff record |
| `staff.update` | All | Edit staff attributes |
| `staff.archive` | All | Archive staff while preserving history |
| `staff.delete` | All | Request permanent deletion/anonymization under retention policy |
| `merit.read.self` | Self | Read linked staff merit/history |
| `merit.read.all` | All | Read all authorized merit/history |
| `merit.initial-score.set` | All | Set starting score during creation/approved correction |
| `merit.adjust` | All | Add an allowed reasoned adjustment |
| `merit.correct` | All | Append a compensating correction entry |
| `csv.import` | All | Preview and commit staff/starting-score CSV imports |
| `reports.read` | Self or All | Read reports within assigned scope |
| `reports.export` | Self or All | Export reports within assigned scope |
| `users.invite` | All | Owner-only trusted invitation workflow |
| `users.disable` | All | Planned: disable account and revoke sessions |
| `users.reset` | All | User requests email reset; session revocation/owner recovery are operational tasks |
| `roles.read` | All | View role definitions and assignments |
| `roles.manage` | All | Manage roles subject to safeguards |
| `settings.score.manage` | All | Change default score and optional bounds |
| `settings.email.manage` | All | Manage email delivery; credentials remain server-side |
| `audit.read` | All | Read authorized audit/security events |
| `backup.status.read` | All | Read backup/restore status where supported by plan |
| `system.health.read` | All | Read non-sensitive Pages/Supabase status |

## 3. Authorization rules

1. No permission means deny; new operations are private until explicitly granted.
2. RLS/trusted functions derive actor and scope from the authenticated identity; never trust client-supplied user IDs or `isAdmin` flags.
3. Self permissions resolve through the authenticated account's linked staff ID.
4. Self-scoped report/export filters are applied before data is returned or serialized.
5. Hiding a UI control is not authorization; Supabase enforces each request.
6. Role changes, account-role assignments, grants, exports and resets are audited.
7. Show effective permissions before saving; require re-authentication for high-risk changes where supported.
8. Protect the last Owner account from lockout and prevent unauthorized role escalation.
9. Never log activation tokens, reset links, credentials or sensitive merit reasons unnecessarily.

## 4. Product-owner decisions

- Can Admin grant `roles.manage`, or is that Owner-only?
- Can managers view all staff or should team/department scope be designed later?
- Can staff update profile fields beyond account credentials?
- Should staff see the actor name for each change?
- Should exports include staff email?
- What retention period and deletion/anonymization rule applies to merit/audit history?
