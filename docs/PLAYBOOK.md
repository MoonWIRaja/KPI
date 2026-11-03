# Merit Tracker Delivery Playbook

## 1. The Goal

Deliver a stable, invite-only Merit Tracker with one attributable merit score per staff member, roles, CSV import and auditable reports. Flutter is the client, GitHub Pages hosts Flutter Web, and Supabase supplies authentication and PostgreSQL. Owner and CEO require TOTP MFA; Owner-only invitation uses Supabase SMTP. Production use is gated on decisions about cloud privacy, region, retention, recovery and cost.

## 2. The Steps in Order

1. [x] Capture business requirements and Flutter/GitHub Pages/Supabase direction.
2. [x] Replace local Rust/SQLite/React/Tauri assumptions in PRD and planning; mark unresolved choices.
3. [ ] **Product/privacy gate:** approve cloud processing; decide jurisdiction/region, repo visibility, domain, retention, MFA recovery/secondary factor, SMTP provider, mobile scope, RPO/RTO and service owner.
4. [ ] **Repository foundation:** decide monorepo layout. Proposed: `apps/` Flutter app, `supabase/` migrations/functions/config, `docs/`, `.github/workflows/`. Add a JS workspace only if it serves real shared tooling; do not add Turborepo for appearance alone.
5. [ ] **Environment foundation:** create isolated Supabase dev/staging/prod projects; restrict Dashboard access; store secrets outside source control; never commit `.env` or service-role keys.
6. [ ] **Threat model and authorization:** map roles to schema/RLS; default deny; link auth identity to staff record; define owner bootstrap, revocation and recovery.
7. [ ] **Database foundation:** version migrations for organization settings, profiles, roles/permissions, staff, merit ledger and audit events. Define constraints, indexes, archive and retention semantics.
8. [ ] **Secure vertical slice:** sign-in → staff self-view → authorized adjustment through atomic trusted operation → ledger/history. Add positive and negative authorization and transaction checks before expanding scope.
9. [ ] **Admin workflows:** staff management, roles, bounds and account lifecycle. Keep public signup disabled. Use authenticated Edge Functions or narrowly scoped SQL functions for privileged actions.
10. [ ] **CSV and reports:** preview, cap file size/rows, validate and deduplicate, then commit atomically. Permission-check and audit exports; do not log raw personal data.
11. [ ] **Flutter UI:** responsive web and mobile layouts from the approved design. Include accessible controls and loading, empty, error and offline states; confirm high-impact changes and respect reduced motion.
12. [ ] **CI quality gates:** pin GitHub Actions to immutable SHAs before production; least-privilege permissions; format/analyze, unit/widget tests, migration checks, RLS tests, secret/dependency scanning and build checks.
13. [ ] **Pages deployment:** build Flutter Web with repository subpath `base-href`. Prefer Flutter hash URLs for stable refresh/deep links on Pages unless a tested 404 rewrite is intentionally adopted. Test production URL and auth redirects.
14. [ ] **Resilience and operations:** set quotas/rate limits/CAPTCHA as appropriate; use safe timeouts, retries and idempotency; measure performance; define backup/restore drills, migration recovery and incident response.
15. [ ] **Security and release review:** map agreed ASVS target; review RLS, privileged functions, secrets/artifacts, dependencies, logs, exports and recovery. Fix release-blocking findings and state limitations honestly.
16. [ ] **Release:** require owner acceptance, verified restore, separated production environment, protected deployment, privacy notice and named support/incident owner.

## 3. The Rules

- Requirements live in `BRD.md` and `PRD.md`; architecture in `TECHNICAL-ARCHITECTURE.md`; decisions in `DECISION-LOG.md`; delivery order here.
- D-011/D-012/D-014 local architecture is superseded. Do not reintroduce SQLite, Rust API or React/Tauri without a new decision.
- Supabase publishable key is public client configuration, not authorization. Every exposed table needs correct RLS. Never place service-role/secret key, SMTP credential or personal data in Flutter assets, Pages, source control or logs.
- No direct score/ledger writes from clients. Validate permission, delta, reason, bounds and idempotency in the trusted layer; score and ledger commit atomically.
- Use separate Supabase environments and reviewed migrations. No production keys in pull-request jobs. Protect production deployments with branch/environment controls.
- GitHub Pages is static hosting; Flutter bundle is downloadable. Enforce authorization and business rules on Supabase. Configure correct base path and Auth redirects.
- Do not enter staff data until cloud-processing, jurisdiction, retention and restore decisions are approved.
- Invite-only means public signup stays disabled. Owner invitations run only through the authenticated Edge Function; CEO cannot invite or assign roles. Configure/test Supabase SMTP before production invitations and resets.
- Owner and CEO use verified TOTP MFA. Their database operations require AAL2; recovery and backup factor instructions must exist before production.
- Create the first Owner in Supabase Dashboard, then link its Auth UUID through the trusted SQL Editor. Do not add a public/client-callable bootstrap endpoint.
- Do not claim ASVS compliance, uptime, DDoS immunity, successful restore or deployment without evidence.
- Recheck provider plans, quotas, backup behavior and technical docs before launch.

## 4. What Done Looks Like

- PRD, architecture, security, operations, traceability, role matrix, README and user guide agree on hosted stack and scope.
- Staff cannot access another staff member's data via direct requests or manipulated IDs.
- Merit history reconciles exactly; mutations are reasoned, attributed, atomic and duplicate-safe.
- CSV preview/cancel/commit and exports honor permissions, privacy and audit requirements.
- Flutter Web deploys repeatably to the configured Pages URL, including refresh, assets, login redirects and error states.
- Mobile targets ship only if explicitly included in supported scope.
- RLS/function tests, migrations, build, accessibility/security review and restore drill pass on the release candidate.
- Owner accepts remaining risks, cloud handling, costs, operating duties and support path.
