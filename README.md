# Merit Tracker

Invite-only staff merit tracking for internal use. The application is built with Flutter Web; it works in desktop and phone browsers. GitHub Pages hosts the static client and Supabase provides authentication, PostgreSQL, row-level security and invitation email delivery.

## Implemented workflows

- Owner and CEO sign-in; TOTP MFA required for privileged accounts and permission-elevated users.
- Staff directory, add/edit/archive/restore, individual starting scores and configurable default score/bounds.
- Reason-required merit adjustments in 0.1 increments from 0.1 through 1.0; immutable history and compensating corrections.
- CSV import with preview, validation, duplicate checks, limits and transactional commit.
- Permission-scoped reports and CSV export with spreadsheet formula neutralization and export audit.
- Owner-managed invitations, per-user permissions, account activation/deactivation and audit history.
- Supabase RLS and trusted database functions enforce access and mutations independently of the interface.

## Repository layout

```text
apps/merit_app/                 Flutter Web client
supabase/migrations/            PostgreSQL schema, RLS and transactional functions
supabase/functions/invite-user/ Trusted invite endpoint
.github/workflows/              Flutter and Supabase migration verification; Pages deployment
docs/                           Product, security and operating guides
```

## Local development

Requirements: Flutter stable (Dart 3.12+), Supabase CLI with Docker for local backend, and a Supabase project for hosted use.

```powershell
cd apps/merit_app
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Follow [the Supabase setup guide](docs/SUPABASE-SETUP.md) before connecting a hosted project. Never put a Supabase secret/service-role key or SMTP credential in Flutter, GitHub Pages, or chat.

## GitHub Pages

The Pages workflow builds for `/KPI/` from `main`. Set repository Actions variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`, then choose **Settings → Pages → GitHub Actions**. Both are public client configuration. Supabase RLS and server-side functions protect private data.

## Operational boundary

The hosted project, SMTP provider, Auth settings, production data and Pages variables are controlled by the project owner. This repository contains setup instructions; it does not imply those external settings have been changed. Do not enter real staff records until the owner has approved hosting region, privacy/retention policy, backups and recovery procedures.

## Product and operating docs

- [PRD](docs/PRD.md)
- [Delivery playbook](docs/PLAYBOOK.md)
- [Supabase setup](docs/SUPABASE-SETUP.md)
- [Role and permission matrix](docs/ROLE-PERMISSION-MATRIX.md)
- [Security and privacy](docs/SECURITY-AND-PRIVACY.md)
- [User guide](docs/USER-GUIDE.md)
- [Deployment and operations](docs/INSTALLER-AND-OPERATIONS.md)
