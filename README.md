# Merit Tracker

Flutter web application for internal staff merit tracking. The client is deployed as static files to GitHub Pages; authentication and staff records live in Supabase.

## Access model

- Public registration is disabled in Supabase Auth.
- First Owner account is provisioned by the system maintainer. Owner is the only role allowed to invite users or assign roles.
- Owner and CEO accounts must enroll a TOTP authenticator before they can access operational data or run privileged actions. RLS and database functions require AAL2.
- CEO manages merit and staff operations. Invited Staff accounts are linked to one staff record and can read only their own merit by default.
- Supabase sends invitations and password recovery using custom SMTP configured in the Supabase Dashboard.
- No privileged Supabase key is included in the Flutter web build.

## Repository layout

```text
apps/merit_app/                 Flutter Web client
supabase/migrations/            PostgreSQL schema, RLS and transactional functions
supabase/functions/invite-user/ Trusted invite endpoint (service key stays server-side)
.github/workflows/pages.yml     Build and GitHub Pages deployment
docs/                           Requirements, operations and decisions
```

## Local development

Requirements: Flutter stable (Dart 3.9+), a Supabase project and configured project URL/publishable key.

```powershell
cd apps/merit_app
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Run SQL migrations and Supabase setup from [docs/SUPABASE-SETUP.md](docs/SUPABASE-SETUP.md). Disable public sign-up, create the first Owner Auth user in Supabase Dashboard, then link the Owner profile through the SQL Editor before first login. There is no client-callable bootstrap endpoint.

## GitHub Pages

Enable **Settings → Pages → GitHub Actions**. Add repository Actions variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`. The workflow builds the Flutter app at `/KPI/` and deploys it. Both values are public client configuration; all private access depends on RLS and server-side functions. Never set the service-role key as a repository variable or Flutter define.

## Current implementation scope

Sign-in and recovery request; first Owner bootstrap; required Owner/CEO TOTP; role-scoped staff directory and merit history; staff creation; atomic ±0.1–1.0 merit changes; Owner-only email invitations; GitHub Pages workflow. CSV import, reports, custom role editor, account disabling, recovery operations and mobile releases remain planned work.

## Product and operating docs

- [PRD](docs/PRD.md)
- [Delivery playbook](docs/PLAYBOOK.md)
- [Supabase setup](docs/SUPABASE-SETUP.md)
- [Security and privacy](docs/SECURITY-AND-PRIVACY.md)
- [Deployment and operations](docs/INSTALLER-AND-OPERATIONS.md)
