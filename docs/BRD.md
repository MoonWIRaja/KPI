# Business Requirements Document — Merit Tracker

**Status:** Draft for product review
**Owner:** Moon
**Prepared with:** Moon / Kid
**Updated:** 2026-11-03

## 1. Executive summary

Merit Tracker is an internal application to manage staff merit scores transparently. Authorized administrators manage staff accounts, permissions, starting scores, merit adjustments, CSV import and reports. Invited staff can view their own merit record when their role permits it.

The updated deployment direction is Flutter with Flutter Web hosted on GitHub Pages and Supabase for hosted authentication and database services. This replaces the former local-only PC/SQLite plan and means employee records will be processed by a cloud provider. The organization must approve privacy, jurisdiction, retention, recovery and cost before production data is entered.

## 2. Business problem and objectives

Manual merit tracking makes score changes difficult to apply consistently, explain and report. Merit Tracker will:
- maintain one overall merit score and its history per staff member;
- require a reason and authenticated actor for every change;
- let authorized admins manage staff and function-level permissions;
- reduce repetitive entry with validated CSV import;
- provide reports that reconcile to the change history;
- protect private runtime data independently of the public open-source client code.

## 3. Stakeholders

| Stakeholder | Need |
|---|---|
| Owner | Control access, roles, score policy and production decisions |
| Administrator | Perform only authorized staff, merit, import and report actions |
| Invited staff member | View own merit information when permitted |
| System operator | Maintain hosted configuration, deployments, backups and recovery |
| Open-source maintainer | Publish code without publishing employee data or secrets |

## 4. Scope

### First-release scope
- One overall score per staff member, default starting score `5`, with authorized per-staff override.
- Optional admin-configured score bounds; no hard-coded `0–10` range.
- Positive/negative adjustments in exact `0.1` steps from `0.1` through `1.0`, each with a required reason and attributable history.
- Invite-only users, self-only staff view by default and function-level roles.
- CSV import preview/validation, merit history and permission-gated reports.
- Flutter application; Flutter Web delivery through GitHub Pages; Supabase Auth/PostgreSQL with server-side authorization.
- Reviewed migrations, environment separation, backup/restore and protected CI/CD.

### Not in v1 unless re-approved
- Local Rust service, SQLite database, React/Tauri desktop shell, always-on owner-PC service or cross-platform desktop installer.
- Anonymous access, public self-registration, employee surveillance, payroll/HR integrations or public database exposure.
- Public Internet or office-only restriction; network access policy remains to be decided for the hosted deployment.

## 5. Business requirements

| ID | Requirement |
|---|---|
| BR-01 | Maintain one overall merit score for each staff member. |
| BR-02 | Default initial score is `5`; authorized admin may override per staff. |
| BR-03 | Do not hard-code a 0–10 range; policy for bounds is configurable and requires owner confirmation. |
| BR-04 | Adjustments use exact ±0.1 to ±1.0 steps. |
| BR-05 | Every adjustment has a non-empty reason and authenticated actor. |
| BR-06 | Keep chronological, attributable change history; corrections do not silently erase events. |
| BR-07 | Staff accounts are invite-only and self-view only by default. |
| BR-08 | Admin assigns permissions by function. |
| BR-09 | CSV is previewed and validated before commit. |
| BR-10 | Reports explain score changes, reasons and actors and honor permissions. |
| BR-11 | No public self-registration; initial owner setup and recovery must use an approved secure workflow. |
| BR-12 | Email delivery may be configured for invitations and recovery; provider/fallback remains open. |
| BR-13 | Runtime employee records are stored in the selected Supabase project; owner must approve cloud processing and jurisdiction. |
| BR-14 | No installer silently changes a user's PC, IP or router configuration. A desktop installer is not in hosted v1. |
| BR-15 | Admin can archive staff; permanent deletion follows an approved retention policy. |

## 6. Business rules

1. Score values use one decimal place; integer tenths are preferred to avoid floating-point arithmetic.
2. A change is one approved magnitude, positive or negative, with a reason.
3. Server-side authorization and atomic commit govern score plus ledger history.
4. Existing merit events are not silently overwritten; corrections append a linked event.
5. Staff role has no access unless permissions are granted; self-view is scoped to authenticated identity.
6. Sensitive CSV/report export requires explicit permission and must not leak into source control or logs.
7. Cloud region, provider processing, retention and recovery need owner approval before live staff data is entered.

## 7. Success measures

- Every committed change has a reason, actor, time, prior value, delta and resulting value.
- A self-only account cannot access another staff record by manipulating a request.
- Invalid imports can be reviewed/cancelled without partial changes.
- Reports reconcile to the ledger.
- A Pages deployment works at its project subpath and uses the approved Auth redirects.
- A documented backup can be restored and reconciled in a non-production environment.

## 8. Open business decisions

Cloud jurisdiction/region and plan; employee privacy/legal basis and notice; repo visibility and license; URL/domain and access boundary; SMTP and secure account recovery; score bounds; report formats; language; retention/deletion; mobile release scope; expected scale; RPO/RTO; and named operational owner.
