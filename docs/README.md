# Merit Tracker — Project Documents

This directory contains the product requirements and delivery plan for the internal Merit Tracker application.

## Current direction

- Product: one overall merit score per staff member, required adjustment reasons, history, roles, CSV import and reports.
- Client: Flutter; web v1 is a static Flutter build hosted by GitHub Pages.
- Backend: Supabase Auth and PostgreSQL with server-side Row Level Security and trusted functions.
- Runtime staff data is cloud-hosted, not stored in the open-source repository. This changes the previous local-only privacy model and requires owner approval of region, legal/privacy handling, retention, cost and recovery before production data is entered.
- No service-role key, SMTP credential or staff data may be placed in Flutter assets, GitHub Pages or source control.
- Previous Rust/SQLite/React/Tauri owner-PC service and installer are superseded for v1.

## Documents

| Document | Purpose |
|---|---|
| [BRD.md](BRD.md) | Business need, scope, stakeholders and business rules |
| [PRD.md](PRD.md) | Product requirements, flows, acceptance criteria and release gates |
| [DECISION-LOG.md](DECISION-LOG.md) | Confirmed directions, superseded choices and unresolved decisions |
| [DESIGN-SPEC.md](DESIGN-SPEC.md) | Visual and interaction design reference; check stack-specific details before implementation |
| [FIGCRAFT-DESIGN-HANDOFF.md](FIGCRAFT-DESIGN-HANDOFF.md) | Approved design handoff and screen intent |
| [ROLE-PERMISSION-MATRIX.md](ROLE-PERMISSION-MATRIX.md) | Function-level role and permission proposal |
| [TECHNICAL-ARCHITECTURE.md](TECHNICAL-ARCHITECTURE.md) | Flutter, Pages, Supabase data/auth and delivery architecture |
| [SECURITY-AND-PRIVACY.md](SECURITY-AND-PRIVACY.md) | Threats, RLS, privacy, deployment and verification plan |
| [INSTALLER-AND-OPERATIONS.md](INSTALLER-AND-OPERATIONS.md) | Hosted deployment, account operations, backup and recovery |
| [TRACEABILITY-MATRIX.md](TRACEABILITY-MATRIX.md) | Requirements mapped to planned verification evidence |
| [PLAYBOOK.md](PLAYBOOK.md) | Ordered implementation plan and definition of done |
| [USER-GUIDE.md](USER-GUIDE.md) | User workflows; update before product release |

## Release gates still open

Approve cloud processing and region; choose Supabase plan and backup/recovery targets; decide repository visibility, domain, email delivery and account recovery; confirm mobile targets, language, retention, report formats and supported scale. See `DECISION-LOG.md` and `PRD.md`.

## Primary provider references

- [Flutter web deployment](https://docs.flutter.dev/deployment/web), [URL strategies](https://docs.flutter.dev/ui/navigation/url-strategies)
- [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages)
- [Supabase Flutter](https://supabase.com/docs/guides/getting-started/quickstarts/flutter), [RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Supabase regions](https://supabase.com/docs/guides/platform/regions), [backups](https://supabase.com/docs/guides/platform/backups), [SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
