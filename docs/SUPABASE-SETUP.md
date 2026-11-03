# Supabase Project Setup (MVP)

This guide configures a real Supabase project. Keep the service-role key and SMTP credentials in the Dashboard/secret store; never send them in chat or commit them.

## 1. Create the project

1. Owner creates a Supabase project in the region chosen after the privacy/data-jurisdiction review.
2. Save project URL, publishable key and service-role key in the organization's approved password manager. The publishable key is client-visible; the service-role key is privileged.
3. In **Authentication → Sign In / Providers**, disable **Allow new users to sign up**. Create the initial Owner Auth user in the Dashboard with a verified email; all other users are created by Owner invitations.
4. Set strong password policy and appropriate Auth rate limits. Keep only the email provider needed by the product enabled.
5. Enable TOTP MFA for Authenticator Assurance Level 2. The app requires Owner and CEO to enroll/verify TOTP before business data/functions are available.

## 2. Apply schema

Apply `supabase/migrations/20261103010000_initial_schema.sql` to the empty project using Supabase CLI/database migration tooling or the SQL Editor. Review the SQL before applying it to production. This MVP has a single organization and seeds a default starting score of 5.0.

Create the first Owner Auth account in the Dashboard with a verified email. Before the first app login, use the Supabase SQL Editor as the trusted project operator to link that Auth user's UUID to the Owner profile. Replace the placeholders below and execute as the project operator:

```sql
insert into public.profiles (user_id, email, display_name, role, staff_id, is_active, must_set_password)
select id, email, 'Moon', 'owner', null, true, false
from auth.users
where email = 'OWNER_EMAIL_HERE';
```

There is intentionally no client-callable bootstrap RPC. Immediately enroll and verify TOTP when prompted. Do not invite any other Auth user before creating the Owner profile.

## 3. Configure custom SMTP

Configure a production SMTP provider under **Project Settings → Authentication → SMTP Settings**. Use a verified sender/domain, authenticated TLS and provider credentials stored only in Supabase settings. Verify sender/domain at the mail provider first.

Then configure Auth **Site URL** and redirect URLs for:

- Production Pages URL: `https://moonwiraja.github.io/KPI/`
- Local development: `http://localhost:7357/` (or the exact local origin used)

Send invitation and password reset messages to test accounts in the staging project before inviting real staff. Supabase's default email sender is not the production SMTP configuration for this product.

## 4. Deploy the invite function

Deploy `supabase/functions/invite-user` using the Supabase CLI from the repository root. Supabase provides `SUPABASE_URL` and `SUPABASE_ANON_KEY` to Edge Functions. Set the remaining environment values using the CLI secret mechanism or Dashboard:

```text
SUPABASE_SERVICE_ROLE_KEY=<server-side service key>
SITE_URL=https://moonwiraja.github.io/KPI/
CORS_ORIGINS=https://moonwiraja.github.io,http://localhost:7357
```

The function verifies its JWT, checks the caller's Owner permission in Postgres, restricts roles to CEO/Staff and sends the invite through Supabase Auth SMTP. The service key is never configured in Flutter or GitHub Pages. Review function logs for errors, not user credentials.

## 5. Configure GitHub Actions and Pages

In the GitHub repository:

1. Add Actions **variables** `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` with the public project client values.
2. Under **Settings → Pages**, choose **GitHub Actions** as the build/deployment source.
3. Protect `main` and review the Pages workflow permissions and action versions before enabling automatic production deployment.
4. Confirm the repository's visibility and Pages availability are acceptable. Pages hosts inspectable static files; it does not protect or proxy Supabase data.
5. Set Supabase Auth site/redirect URLs to match the actual published Pages URL.

## 6. Initial accounts and operations

- Create/claim the first Owner using the one-time procedure above.
- Owner invites the CEO, who must activate the account by email and enroll TOTP before access.
- Owner adds staff records, then invites each staff user and links the matching staff record.
- Owner is the sole invite/role administrator in this MVP; CEO can add staff and adjust merit but cannot invite accounts.
- If the Owner is unavailable, do not manually edit production rows. Define and test a trusted recovery process before production.
- Enroll a second TOTP factor on a separate device for each privileged account before launch, if supported by the current authentication flow. MFA recovery UX is not yet implemented in this app.

## Not yet completed

No Supabase project, SMTP provider, GitHub Actions variables, production Auth settings or deployment were configured from this workspace. They require account access and owner-controlled credentials.
