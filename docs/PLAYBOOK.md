# Merit Tracker Delivery Playbook

## 1. The Goal

Deliver the invite-only Merit Tracker application for desktop and phone browsers. Flutter Web is hosted on GitHub Pages; Supabase provides Auth, PostgreSQL/RLS and invitation email. Keep the complete score ledger attributable, protect employee data, and make deployments/recovery operationally reviewable.

## 2. The Steps in Order

1. [x] Record requirements, hosted architecture and design direction in the product docs.
2. [x] Implement responsive Flutter sign-in, one-time Owner setup wizard, password setup, MFA, directory, merit workflows, CSV import, reports, account permissions, settings and audit pages.
3. [x] Implement Supabase schema/RLS, private email-allowlisted Owner claim, permission catalog, atomic merit/import functions, invitations and audit operations.
4. [x] Add Flutter Web/Pages and isolated local Supabase migration CI workflows.
5. [x] Write setup, user, permission, security and operations documentation.
6. [ ] Run Flutter analysis/Web build and clean local migration CI against the current Owner wizard changes; fix reported failures before release.
7. [ ] Inspect the owner's existing Supabase migration history/schema. Apply reviewed forward migrations only; never reset an existing hosted database.
8. [ ] Configure Auth signup/MFA/redirects, SMTP and Edge Function settings in the owner's Supabase project.
9. [ ] Set public Pages Actions variables, enable Pages Actions and deploy through the protected production branch.
10. [ ] Verify role isolation, invitations, CSV transactionality, adjustments/corrections, exports, mobile-browser layout and restore procedure in a staging project.
11. [ ] Obtain owner approval for data region, privacy, retention, repository visibility, plan/cost, recovery owner and release risks before production records.

## 3. The Rules

- Requirements live in `BRD.md` and `PRD.md`; architecture in `TECHNICAL-ARCHITECTURE.md`; decisions in `DECISION-LOG.md`; delivery order here.
- Current architecture is Flutter Web + GitHub Pages + Supabase. Do not reintroduce the superseded local Rust/SQLite/React/Tauri plan without a product decision.
- Supabase publishable key and URL are public configuration; they never replace RLS. Secret/service-role keys, SMTP credentials, database passwords and staff records never enter Flutter, Pages, Git, Actions logs or chat.
- Every exposed table has RLS. Client writes to score/ledger, permissions and audit data are revoked. Privileged work validates server-side permission and records state atomically.
- Merit adjustments are integer tenths from 0.1 to 1.0, require a reason and idempotency ID, and respect optional score bounds. Corrections append compensating ledger events.
- CSV import is bounded to 2 MB/500 rows, previewed and revalidated in one transaction. Reports are RLS-scoped; export formula-leading text is neutralized and the export is audited.
- Signup remains disabled. Only Owner invites and manages permissions/accounts. Owner/CEO and users with elevated grants require verified TOTP AAL2.
- The public Pages bundle exposes application code. RLS and trusted functions protect backend data, not source visibility.
- Cloud privacy/region, retention, recovery, backups, quotas/cost and SMTP sender/provider must be approved before real employee data is entered.
- Report actual verification evidence and remaining risks. Never claim migration application, deployment, ASVS certification, uptime or DDoS immunity without evidence.
- `toolbox/README.md` is the index of shared reusable assets/scripts. Keep every registered item listed here with its use and constraints; do not add one-off helpers without a recurring need.

## 4. What Done Looks Like

- App analysis, release build and migration CI pass against the actual release commit.
- Existing Supabase schema/history is reconciled with migrations; no production reset or unreviewed schema rewrite occurs.
- Owner, CEO and Staff access is confirmed by direct API/RLS checks, including denied cross-staff reads and revoked permissions.
- Invitation/password setup, TOTP, staff management, import, reasoned adjustment, correction, reports, audit and account deactivation work in staging.
- Pages/auth redirects work at `/KPI/` on desktop and phone browsers. No native mobile package is promised by this browser release.
- SMTP, backups/restore, owner recovery, privacy/retention and incident ownership have documented evidence and approval.
- Owner accepts costs, operational duties, known limitations and production release.
