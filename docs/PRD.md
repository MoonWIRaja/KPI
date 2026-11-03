# Product Requirements Document — Merit Tracker

**Version:** 0.2 (architecture pivot)
**Status:** Draft for product review
**Owner:** Moon
**Agent:** Kid
**Updated:** 2026-11-03

## 1. Product summary

Merit Tracker is an internal, invite-only application for maintaining one overall merit score per staff member, recording every adjustment with its reason, managing permissions, importing staff by CSV, and producing auditable reports. The product is open-source; employee records remain private runtime data.

**Deployment direction:** Flutter is the application client; GitHub Pages serves the Flutter Web build; Supabase provides hosted authentication and PostgreSQL data services. The previous owner-PC Rust/SQLite/React/Tauri installation design is superseded for the first release. This moves staff data to a cloud service and requires privacy, jurisdiction and cost decisions before production data is entered.

## 2. Goals and non-goals

### Goals
- Maintain a reliable current score and complete, attributable history.
- Let authorized administrators manage staff, accounts, permissions, imports and reports.
- Let invited staff see only their own record unless explicitly granted more.
- Deliver responsive Flutter Web from GitHub Pages, with a path to Flutter mobile clients.
- Enforce authorization server-side and make deployments, migrations, backups and recovery repeatable.

### Not in v1
- Local-only SQLite hosting, Rust API, React/Tauri desktop, automatic host IP changes or a desktop background service.
- Anonymous access, self-registration, public staff directory, payroll/HR integrations or employee surveillance.
- Public write APIs or direct database access from clients.
- Claims of DDoS immunity or ASVS certification.

## 3. Users and permissions

- **Owner:** initial organization administrator; controls access, roles and critical settings.
- **CEO:** manages staff and merit operations; can read all authorized staff records but cannot invite users or grant roles.
- **Staff:** invited account; no access by default, normally self-view only.
- **System maintainer/Owner:** provisions the first account, invites users, controls recovery and maintains deployment.

Permission checks must be enforced in Supabase policies/functions, not only by hiding Flutter controls. The detailed catalog is in `ROLE-PERMISSION-MATRIX.md` and must be translated into database authorization rules before release.

## 4. Functional requirements

| ID | Priority | Requirement |
|---|---:|---|
| FR-STAFF-01 | P0 | Authorized users can add, edit, archive and search staff. Archive preserves history; permanent deletion follows an approved retention policy. |
| FR-MERIT-01 | P0 | Each staff member has one overall score. Organization default is `5`; authorized admins may set an individual starting value. |
| FR-MERIT-02 | P0 | Admin can configure optional floor and ceiling. No hard-coded `0–10`; unset bounds mean no configured bound. Negative/unusually high values remain an open policy decision. |
| FR-MERIT-03 | P0 | Adjustments are exactly `±0.1` through `±1.0` in 0.1 increments. A reason is required. |
| FR-MERIT-04 | P0 | Each change records actor, UTC time, staff, reason, signed delta and before/after values. The ledger is append-only through the application; corrections create compensating entries. |
| FR-MERIT-05 | P0 | Authorization, validation, ledger insert and score update happen atomically in the trusted data layer; clients cannot directly update scores or ledger rows. |
| FR-AUTH-01 | P0 | No public self-registration. An operator allowlists one confirmed Auth email; the first-login wizard can claim Owner once for that identity. Only Owner can invite accounts or assign permissions. |
| FR-AUTH-02 | P0 | Authentication uses Supabase Auth. Expired/revoked sessions return users to sign-in safely. |
| FR-AUTH-03 | P0 | Owner and CEO require TOTP MFA; privileged database policies and functions require an AAL2 session. |
| FR-AUTH-04 | P0 | Staff self-view is scoped to the authenticated account-to-staff link; changing an ID, URL or request body cannot expose another record. |
| FR-AUTH-05 | P0 | Role permissions cover merit, staff, imports, exports, users/roles, settings and audit operations. |
| FR-AUTH-06 | P0 | SMTP is required for production account invitation and password recovery; provider credentials stay in Supabase configuration. |
| FR-CSV-01 | P0 | CSV import validates size, columns, encoding and rows; preview and row errors are shown before commit. Unapproved/invalid data is not partially applied. |
| FR-CSV-02 | P0 | Import commit is permission-checked and transactional; duplicate and update-vs-create behavior is explicit in preview. |
| FR-REPORT-01 | P0 | Authorized users can filter history and export staff, score, changes, reasons, actors and timestamps. Export is permission-checked and audited. |
| FR-SET-01 | P1 | Authorized admins manage default score and optional bounds; changes are audited. |
| FR-OPS-01 | P0 | Development, staging and production environments are isolated; schema changes use reviewed migrations. |
| FR-OPS-02 | P0 | Production data can be backed up and restored using a documented, exercised process with owner-approved recovery objectives. |
| FR-OPS-03 | P0 | GitHub Actions builds and deploys Flutter Web to Pages with least privilege and protected production deployment. |
| FR-OPS-04 | P0 | App handles network errors, timeouts, expired sessions, retries and backend outage without duplicate merit changes or false success states. |

## 5. Business rules

1. Store scores in integer tenths (e.g. `5.0` as `50`) or equivalent exact decimals; avoid binary floating-point arithmetic.
2. A change must use one of the approved magnitudes and a non-empty reason.
3. The trusted operation calculates before/after and applies configured bounds atomically.
4. Never overwrite a ledger event; corrections are new events linked to the original.
5. Reports reconcile to the ledger and honor caller scope.
6. Staff accounts are invite-only and default to self-only access.
7. Never commit staff data to Git, Pages artifacts, test fixtures, issue text or build logs.

## 6. Stability, security and quality

- Enable PostgreSQL Row Level Security (RLS) on every exposed data table. Use default-deny policies and test allowed and forbidden cases.
- Only narrowly scoped SQL functions or authenticated Supabase Edge Functions perform privileged operations. Service-role/secret keys never enter Flutter, GitHub, Pages, browser storage or logs.
- Require HTTPS, least privilege, session revocation, dependency review, secret scanning, audit logging and a retention policy.
- Use duplicate-submit protection for mutations; bounded retries/backoff only for safe operations; clear error/offline states and a schema recovery plan.
- Responsive and accessible UI: keyboard operation, visible focus, semantic labels, readable contrast and reduced-motion support.
- Require TOTP MFA for Owner and CEO, default-deny RLS, scoped server-side functions, invite-only account creation, generic login errors and no privileged keys in the client.
- Map agreed controls to OWASP ASVS v5 Level 3 as a proposed high-assurance target. This is not certification or a claim of immunity to attack/DDoS.
- Set availability, RPO/RTO, expected staff count, import size and report latency before production sizing.

## 7. Core user journeys

### Owner setup
1. Maintainer configures isolated Supabase environments and stores secrets outside source control.
2. Owner account is created through the approved one-time bootstrap procedure; public sign-up remains disabled.
3. Owner reviews roles, assigns self-view permissions and sets score defaults/bounds.
4. Owner provisions staff using the selected account-delivery flow.

### Merit adjustment
1. Authorized admin selects a staff member, a positive/negative 0.1–1.0 step and a reason.
2. App shows the proposed outcome and any bound issue.
3. Trusted operation validates permission, updates score and appends the event in one transaction.
4. UI confirms only after commit; duplicate submissions do not create duplicate changes.

### CSV and report
1. Admin previews CSV, errors and duplicates; can cancel without changing data.
2. On confirmation, trusted code revalidates permission/data and commits atomically.
3. Authorized report is generated within caller scope and recorded in audit history.

## 8. V1 acceptance criteria

- Self-only/unauthorized users cannot access another staff record by manipulating client input.
- Every merit mutation is atomic, attributable, reasoned, exact and duplicate-safe.
- Invalid CSV is shown before commit; cancel makes no data changes.
- Production build works at the GitHub Pages project subpath, including refresh/deep links.
- Flutter bundle contains no service-role key, SMTP credential, staff data or source maps.
- RLS, trusted functions, role matrix and migrations have automated positive and negative verification.
- Deployment is repeatable; production cannot deploy from an unprotected branch.
- Backup can be restored to non-production and reconciled against known records.
- Browser/device matrix, performance limits, backup policy and recovery objectives are documented.

## 9. Open decisions and release gates

1. Approve cloud processing of employee merit data; define privacy notice/legal basis, retention, export/deletion and incident contact.
2. Choose Supabase region and plan after review of jurisdiction, backup/restore, quotas, cost and support. Singapore is a candidate, not confirmed.
3. Decide repository visibility and license. Pages content and Flutter bundle are downloadable; authentication protects data, not client source. Confirm desired Pages visibility and plan.
4. Choose URL/custom domain and configure Auth redirect allowlists for local, staging and production.
5. Choose production SMTP provider and secure bootstrap/recovery procedure; SMTP is required before live user invitations and resets.
6. Confirm Android/iOS targets, distribution and whether mobile ships in v1.
7. Confirm score bounds, report formats, language, retention, expected scale, RPO/RTO and support owner.

## 10. Primary technical references

- [Flutter web deployment](https://docs.flutter.dev/deployment/web)
- [Flutter URL strategies](https://docs.flutter.dev/ui/navigation/url-strategies)
- [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Supabase Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase Edge Function authentication](https://supabase.com/docs/guides/functions/auth)
- [Supabase SMTP configuration](https://supabase.com/docs/guides/auth/auth-smtp)
