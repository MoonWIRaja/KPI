# Security and Privacy Plan — Hosted Merit Tracker

**Status:** Requirements and verification plan; not a completed security assessment.

## 1. Security objective

Protect employee identity and merit records, user sessions, role configuration, audit history, exports and deployment credentials. The requested “security level three” is proposed to mean a verification plan mapped to OWASP ASVS v5 Level 3. It is not certification and does not make the app immune to attack or DDoS.

## 2. Data and trust boundaries

### Sensitive assets
- Staff identity and merit scores/reasons/history.
- Auth accounts, session tokens and account recovery links.
- Role/permission configuration and audit records.
- Supabase secret/service-role key, SMTP credential and GitHub deployment credentials.
- CSV imports and exported reports.

### Boundaries
1. Browser/mobile Flutter client and the public GitHub Pages bundle.
2. Authenticated client requests and Supabase Auth/API.
3. PostgreSQL RLS and trusted SQL/Edge Function operations.
4. GitHub repository and Actions deployment environment.
5. Maintainer/admin operators and Supabase project settings/backups.

## 3. Primary threats and controls

| Threat | Required control |
|---|---|
| User reads another person's merit by changing an identifier | RLS default-deny policies bind `auth.uid()` to an authorized profile/staff link; negative cross-user tests. |
| Client forges role/admin flag | Ignore client-supplied privilege claims; derive identity and permissions from trusted database relations/JWT validation. |
| Service key is extracted from public Flutter bundle | Never include secret/service-role key in app, Pages, Git or browser configuration. Rotate immediately if exposed. |
| Direct score or ledger tampering | Revoke direct client writes; trusted atomic operation validates scope, step, reason, bounds and idempotency. |
| Duplicate submissions or concurrent updates corrupt score | Transaction/locking, constraints and idempotency key; exercise concurrent and retry cases. |
| Public account creation or account takeover | Disable public signup; invite-only provisioning; strong password/session policy, rate controls, recovery review and account revocation. |
| Malicious/oversized CSV or formula injection in export | File/row/field limits, strict parser and validation; no automatic execution; neutralize spreadsheet formula-leading values on export. |
| Sensitive data leaks through logs, analytics, issues or artifacts | Redact tokens/secrets; avoid full CSV rows/reasons in logs; scan builds and repository; synthetic fixtures only. |
| Compromised workflow deploys malicious client | Least-privilege permissions, protected branches/environments, reviewed pinned Actions, secret isolation and deployment audit. |
| Backend outage, quota exhaustion or abuse | Rate/resource limits, monitored quotas, controlled error handling, retry limits and recovery/runbook. DDoS protection depends on provider/service plan and is not guaranteed. |
| Cloud jurisdiction/retention is unsuitable | Product owner approves processing basis, region, retention, deletion and access process before real employee data. |

## 4. Authorization and data rules

- Enable RLS on every API-exposed table, including newly added tables. Policies default to deny.
- Disable public Auth signup. The operator creates the first Auth user in Dashboard, allowlists exactly one verified email in the private `initial_owner_setup` row, and the first-login wizard claims Owner atomically. The client cannot set or change the allowlisted email, and the claim RPC fails after an Owner exists.
- Only Owner may invite users or assign CEO/Staff roles. Invitation is performed by a JWT-verified Edge Function that checks the Owner role, sends through Supabase Auth SMTP and writes an audit event.
- Require TOTP MFA for Owner and CEO and verify AAL2 in database policy/function checks. Store a second factor on a separate protected device before production; the in-app recovery UX is not complete yet.
- Role permissions are server-enforced. Self-view policy checks account-to-staff identity, not a client-selected staff ID. Default CEO grants and Staff self-only grants are inserted by a database trigger; Owner-managed permission changes use a trusted function.
- Separate read, adjust, import, export, user/role management, settings, audit and backup permissions.
- Direct client insert/update/delete of scores and merit events is denied. Trusted operations append events and update score atomically.
- Service-role operations run only in trusted Supabase environments with the narrowest practical interface; never expose admin APIs to anonymous callers.
- Use database constraints for organization scope, valid delta, non-empty reason, valid event shape and referential integrity.
- A local Supabase migration-application workflow is included in CI. Positive/negative RLS/function tests are still required before production; the workflow alone does not verify authorization behavior.

## 5. Secrets, sessions and deployment

- Supabase project URL and publishable key are public bundle settings; they do not grant access without valid RLS. Service-role/secret keys are privileged and remain only in restricted server-side secrets.
- SMTP credentials live in Supabase secret storage/configuration, never database plaintext or Flutter settings.
- GitHub Actions uses minimal `contents:read`, Pages deployment and identity permissions as required; production secrets are environment-scoped and unavailable to untrusted pull requests.
- Use HTTPS. Flutter Web is configured not to persist the Supabase session across page reloads; the user must sign in again. The current access token still exists in browser memory and is exposed to same-origin script execution, so prevent XSS through safe text rendering, dependency review and restrictive inputs. Clear UI state on sign-out/account change.
- Configure narrow Auth redirect allowlists. Review custom domain, password/recovery flow and session lifetime before launch.
- Public Pages artifacts are inspectable. They contain no privileged logic or secrets; access controls protect backend data, not app source.

## 6. Privacy and employee data

Cloud deployment changes the previous local-only privacy boundary. Before production:
- identify the organization controlling the records and lawful/approved purpose for merit scoring;
- select region and evaluate provider processing, subprocessors, cross-border transfer and applicable obligations;
- publish an internal privacy notice covering fields, access, reasons, reports, retention and correction requests;
- set retention/archive/deletion rules for staff, ledger, imports, exports and backups;
- limit collection to business-required data and prohibit covert behavioral/location monitoring;
- define who can export, investigate incidents and fulfill access/correction/deletion requests.

A selected Supabase region describes core project data location, not a blanket guarantee about all provider processing or legal compliance. Obtain the organization's privacy/legal review.

## 7. Backup, availability and incident response

- Select a Supabase plan only after confirming backup schedule/retention, point-in-time recovery needs, quotas, support and cost.
- Document RPO/RTO and recovery owner. Periodically restore to a clean non-production project and reconcile staff/ledger counts and representative balances.
- Preserve migration history and implement reviewed forward fixes; never experiment against production data.
- Incident runbook covers key/session revocation, secret rotation, user suspension, export/audit preservation, provider escalation, recovery and affected-person notification as required.
- A static GitHub Pages deployment does not itself provide backend availability. Monitor Pages and Supabase separately.

## 8. Verification plan

Before release, review applicable OWASP ASVS v5 L3 requirements and record evidence/limitations. Verify:
1. RLS behavior for each role, organization and self-only access, including forged IDs and unauthenticated requests.
2. Privileged functions, invitation/admin boundaries, input/CSV limits, exports and concurrent/idempotent merit changes.
3. Secrets in Git history, Flutter assets, Pages artifacts, logs and GitHub workflow permissions.
4. Dependency vulnerabilities, authentication/recovery, session revocation, accessibility and error states.
5. Backup restoration, migration recovery, monitoring and incident procedure.

Do not claim compliance, certification, zero vulnerabilities or DDoS protection without scoped independent evidence and a defined verification process.
