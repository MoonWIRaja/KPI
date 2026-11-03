# Deployment and Operations Guide

**Scope:** Flutter Web on GitHub Pages with Supabase backend. Desktop installer and always-on owner-PC service are out of scope for v1; revisit only with a product decision.

## Environments

Maintain separate Supabase projects for development, staging and production. Restrict Supabase Dashboard and GitHub repository access to named maintainers. Production staff data is never used for development; use synthetic fixtures.

## Initial setup

1. Create the Supabase project in the owner-approved region and plan after privacy, backup, cost and jurisdiction review.
2. Configure Auth site URL, redirect allowlist and disable public user sign-up.
3. Apply reviewed database migrations to development, verify RLS and function tests, then stage and production through a controlled release.
4. Store only the Supabase URL and publishable key in Flutter's public build configuration. Keep service-role/secret keys and SMTP credentials in restricted Supabase/GitHub secret stores; never commit them or embed them in Pages artifacts.
5. Create the first owner using the approved secure bootstrap procedure. The procedure is a release gate and must not rely on a default password or public bootstrap endpoint.
6. Configure production email delivery if invitations/recovery are enabled. Test the whole invitation and reset flow with non-production accounts.

## GitHub Pages deployment

- Use a GitHub Actions workflow with least-privilege permissions, reviewed action versions pinned to immutable SHAs and a protected production environment.
- Build with Flutter web release mode and the correct Pages project subpath base href.
- Deploy only the generated static build artifact. Exclude source maps and any `.env`, staff data, service keys or signing material.
- Use hash-based Flutter routing for reliable refresh/deep links on Pages unless a custom 404 rewrite is deliberately implemented and tested.
- Test asset paths, login/logout, email redirects, refresh, permission-denied pages, backend outage and cache behavior at the actual hosted URL.
- Keep production deploys restricted to a protected branch/tag and require the planned review gate.

## Schema and release operations

1. Author a versioned migration and review its data/security impact.
2. Apply to development and run migration, RLS, function and application checks.
3. Deploy to staging with synthetic data; verify upgrade/recovery steps.
4. Back up production according to the selected service plan and migration risk.
5. Apply production migration using protected credentials; verify health and key flows.
6. Prefer a forward fix for production schema issues. Restore only through the documented, owner-approved recovery runbook.

## Backup and recovery

Before real data is entered, decide backup cadence/retention, RPO/RTO, restore owner and incident contact. Supabase backup capability depends on current plan; confirm current provider details instead of assuming a free or paid feature. Periodically restore into a separate non-production project and reconcile representative scores and ledger entries. Never store exported backups or real staff CSVs in the source repository.

## Account operations

- Invite only named users; grant minimum role permissions; revoke access promptly when roles change or employment ends.
- Keep public signup disabled. Admin user-management API calls belong only in Dashboard or trusted server-side functions.
- Automated invitation/reset requires an approved SMTP service and tested redirect domain. Do not expose admin keys to Flutter.
- Document a safe owner recovery path before production; do not rely on an undocumented manual database edit.

## Monitoring and incident response

Monitor Pages deployment result, Supabase availability/quotas, authentication failures, function errors and database resource use. Avoid collecting merit reasons or full CSV data in telemetry. Incident runbook identifies who can revoke sessions/keys, suspend accounts, preserve audit information, restore service and communicate with affected users.

## Pre-release checklist

- [ ] Owner has approved cloud processing, region, plan, retention, privacy notice and repository visibility.
- [ ] Separate development/staging/production projects exist; public registration is disabled.
- [ ] RLS and role authorization positive/negative checks pass.
- [ ] Flutter artifact has no secrets, personal data or source maps.
- [ ] Pages base path, routes, Auth redirects and production domain work.
- [ ] Deployment workflow is least privilege and protected.
- [ ] SMTP/bootstrap/recovery paths work if included.
- [ ] Backup restore and ledger reconciliation were exercised.
- [ ] RPO/RTO, support owner, incident contacts and rollback/forward-fix procedures are documented.
