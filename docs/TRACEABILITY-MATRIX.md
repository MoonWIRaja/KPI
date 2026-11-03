# Requirements Traceability Matrix

This matrix links the approved business needs to application controls and the verification still needed before production. Implemented source does not mean the hosted project or release checks have passed.

| Business need | Product requirement | Implementation / outstanding evidence |
|---|---|---|
| One score, default 5 and per-staff override | FR-MERIT-01, FR-SET-01 | Integer tenths and trusted create/settings operations; verify in staging. |
| Optional bounds without fixed 0–10 range | FR-MERIT-02 | Settings and mutation functions enforce configured bounds; verify boundaries; owner confirms policy. |
| Signed 0.1–1.0 adjustments and required reason | FR-MERIT-03..05 | UI and atomic `adjust_merit` validate step, reason, bounds and request ID; concurrency and reconciliation remain. |
| Traceable history and corrections | FR-MERIT-04 | Ledger captures actor, timestamp, before/after and reason; corrections append events; staging reconciliation remains. |
| Staff self-view and function permissions | FR-AUTH-03..04 | RLS and trusted functions enforce scope/grants; negative cross-account API verification remains. |
| Invite-only accounts | FR-AUTH-01..02, FR-AUTH-05 | One-time verified-email Owner wizard and Owner-only invitations implemented; hosted signup, SMTP, MFA and recovery setup remain. |
| Bulk staff import | FR-CSV-01..02 | CSV preview/validation and transactional 500-row RPC implemented; hosted verification remains. |
| Reports explain score changes | FR-REPORT-01 | Scoped report history, CSV formula neutralization and export audit implemented; hosted permission checks remain. |
| Hosted web app | FR-OPS-03 | Pages workflow builds `/KPI/`; actual repository variables and production URL remain. |
| Stability and recovery | FR-OPS-02, FR-OPS-04 | Flutter analyzer/Web build and clean migration CI pass on `12de7f2`; restore drill and recovery operations remain. |
| Employee data stays private | Security and Privacy Plan | RLS/security controls are present in source; verify direct API roles and scan deployed artifacts. |
| Cloud operation approved | PRD release gates | Owner must approve region, provider processing, retention, privacy notice, backups and incident responsibilities. |

Older BRD assumptions for owner-PC SQLite, office-LAN hosting, static-IP setup and Rust/React/Tauri installers are superseded by hosted Flutter Web + GitHub Pages + Supabase.
