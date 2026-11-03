# Design and UX Specification

**Status:** Proposed visual direction; no screens have been implemented or approved.

The design-only FigCraft task is detailed in [FIGCRAFT-DESIGN-HANDOFF.md](FIGCRAFT-DESIGN-HANDOFF.md). That handoff is for an editable visual prototype, not production frontend code.

## 1. Design goal

Make merit changes easy to review and difficult to submit accidentally. The interface should feel like a polished internal business application: calm, clear, data-dense where useful, and usable on a phone. Visual polish must not hide score history, reasons, permissions or system status.

## 2. Proposed visual direction

- **Character:** professional, modern, confident and restrained; avoid gamified leaderboards or public ranking that could shame staff.
- **Layout:** a clear dashboard with a compact left navigation on desktop and bottom navigation or a drawer on mobile.
- **Color:** neutral surfaces with one brand accent; semantic green for positive change, red for negative change, amber for pending/warning and gray for archived. Color is always paired with a label or icon.
- **Typography:** readable sans-serif, strong numeric hierarchy for scores, comfortable body size and clear Malay labels.
- **Motion:** short, purposeful transitions only; respect reduced-motion preferences.
- **Language:** Bahasa Melayu is the likely default based on the current brief; English support is Open.
- **Brand:** final logo, exact palette, font licensing and product capitalization are Open. Do not fabricate a logo or brand mark before approval.

## 3. Information architecture

### Admin navigation

1. **Dashboard** — total active staff, recent merit activity and permitted alerts.
2. **Staff** — search, add, edit, archive, profile and score history.
3. **Merit activity** — adjustments with filters and reason search.
4. **Import** — CSV template, upload, preview, validation and commit result.
5. **Reports** — staff/date filters, preview and export.
6. **Users & roles** — invite accounts, assign roles and configure permissions.
7. **Settings** — default score, optional bounds, account/email configuration and service information according to permissions.
8. **Audit log** — administrative and security events according to permission.

### Staff navigation

1. **My merit** — own current score and recent changes.
2. **History** — own entries with timestamp, adjustment and reason.
3. **Account** — password and session actions supported by policy.

Navigation is generated from permissions, but hiding a screen is not an authorization control; the backend still checks every request.

## 4. Key screens and states

### Login and owner setup

- The Flutter client signs in through Supabase Auth; public signup stays disabled.
- Before an Owner exists, the first visit opens a branded first-run setup screen. Only the exact operator-approved, email-confirmed Owner account can sign in and continue to the one-time profile/password wizard; after the database atomically claims Owner, first-run stays closed permanently and standard sign-in appears. Owner then enrolls TOTP.
- The operator creates the first Auth user in the Supabase Dashboard and configures the one-time allowlisted email in SQL. A public status function exposes only a boolean setup-complete state; the app never creates arbitrary users or accepts a client-provided Owner role.
- Login has accessible labels, generic failure messages and a password reveal control.
- Invitation/reset email availability depends on configured production delivery.
- Do not display a PC LAN/IP setup workflow in the hosted web v1.

### Staff list

- Search by staff code or name; filter active/archived.
- Show staff name/code, current merit, status and last change.
- No comparison leaderboard by default.
- Unauthorized users never receive hidden rows in API payloads.

### Staff profile

- Show current merit prominently and one decimal place.
- Show starting value and whether it was the organization default or an override.
- History is chronological and includes change, reason, actor and time.
- Admin actions appear only when authorized.

### Merit adjustment dialog

1. Select increase/decrease and a fixed step from `0.1` to `1.0`.
2. Enter a required reason.
3. Show previous score, delta, resulting score and any bound warning.
4. Confirm and report success/failure without losing the typed reason.

Do not rely on color alone to indicate increase/decrease. Do not submit on a single accidental click.

### CSV import

- Display a downloadable template and field definitions.
- Show file summary, valid rows, errors and duplicate warnings before commit.
- Allow download of row-level error details.
- Do not silently overwrite existing staff or ledger entries.
- Confirmation explains how starting scores are recorded.

### Reports and export

- Filters: date range, staff, actor and change direction where permitted.
- Preview totals and rows before export.
- Warn that the file may contain staff personal data.
- Proposed formats: CSV first; PDF is Open.

### Users, roles and email settings

- Permission editor groups permissions by function and shows the role’s effective access.
- Self-only and all-staff access are explicit and visually distinct.
- Email credentials remain server-side; the Flutter UI may show configuration status but never secret values.

## 5. Responsive behavior

- **Wide desktop:** multi-column dashboard and full tables.
- **Tablet:** one main content column; filters become collapsible.
- **Phone:** card/list layouts, large touch targets, no horizontal page scroll. A wide table becomes labeled cards or a deliberate horizontally scrollable region.
- Flutter Web is the first client; Flutter mobile targets and their release timing remain open. Keep responsive behavior and interaction tokens consistent across included Flutter targets.

Exact breakpoints are implementation decisions after the first responsive prototype.

## 6. Accessibility and content rules

- All tasks work by keyboard; focus remains visible and ordered.
- Inputs have persistent labels, validation text and error associations.
- Meet WCAG 2.2 AA as the proposed accessibility target; verify contrast and screen-reader flows during implementation.
- Use plain terms: “Tambah merit”, “Tolak merit”, “Sebab”, “Skor sebelum” and “Skor selepas”.
- Do not describe a score as proof of a person’s character. Explain that the application records administrator-entered merit events.

## 7. Design acceptance checks

- User can tell current score, prior score, change and reason without opening a hidden menu.
- Staff role never sees another staff member’s data.
- Increase/decrease is identifiable without color.
- CSV errors are actionable and do not silently discard rows.
- Primary phone flows fit a narrow viewport and have accessible controls.
- Admin can understand the effective permissions before saving a role.
