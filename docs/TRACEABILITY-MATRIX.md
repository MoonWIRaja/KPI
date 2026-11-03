# Requirements Traceability Matrix

This matrix links business requirements to product requirements and planned acceptance evidence. Evidence is planned; no application implementation or test run is represented by this document.

| Business need | Product requirement | Planned evidence |
|---|---|---|
| One overall merit score with default 5 and per-staff override | FR-MERIT-01, FR-SET-01 | Database constraint and workflow tests for default and override. |
| Optional bounds, no fixed 0–10 range | FR-MERIT-02 | Boundary tests for configured/unconfigured limits; owner confirms negative-score policy. |
| Positive/negative 0.1–1.0 adjustments and required reason | FR-MERIT-03..05 | Reject invalid steps/empty reason; concurrent transaction and ledger reconciliation tests. |
| Traceable history and corrections | FR-MERIT-04 | Verify actor, timestamp, before/after, reason and compensating entry. |
| Staff self-view and function roles | FR-AUTH-03..04 | RLS tests for self, other staff, admin grants, forged IDs and denied defaults. |
| Invite-only accounts | FR-AUTH-01..02, FR-AUTH-05 | Verify signup disabled, admin provisioning boundary, revocation and chosen reset/invite flow. |
| Bulk staff import | FR-CSV-01..02 | Preview, cancel, duplicate, malformed/oversized file and atomic commit checks. |
| Reports explain score changes | FR-REPORT-01 | Export reconciles to ledger, enforces permission/scope and writes audit event. |
| Hosted web application | FR-OPS-03 | GitHub Actions Pages deployment, project subpath, refresh, assets and Auth redirect verification. |
| Stable operation and recovery | FR-OPS-02, FR-OPS-04 | Error/timeout/idempotency checks and successful restore drill with reconciliation. |
| Sensitive staff data stays private | Security and Privacy Plan | RLS/function review; scan repository, bundle, artifacts and logs for secrets/real records. |
| Cloud operation approved and governed | PRD release gates | Owner approval of region, provider processing, retention, notice, backup and incident responsibilities. |

## Superseded business assumptions

Older BRD identifiers for owner-PC SQLite, office-LAN hosting, static-IP setup and Rust/React/Tauri installers no longer describe v1. Product requirements now use hosted Flutter/GitHub Pages/Supabase. Update BRD and role/user guides if they conflict with this matrix.
