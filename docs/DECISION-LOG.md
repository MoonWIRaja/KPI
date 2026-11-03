# Product Decision Log

This log separates user-confirmed direction from proposals and unresolved decisions. The hosted deployment direction supersedes earlier local-hosting decisions.

| ID | Topic | Decision/status | Notes |
|---|---|---|---|
| D-001 | Product name | Confirmed working name: Merit Tracker | Branding open. |
| D-002 | Score model | Confirmed: one overall merit score per staff | No separate KPI categories. |
| D-003 | Default starting score | Confirmed: `5` | Admin may set an individual starting value. |
| D-004 | Score range | Open | No hard-coded 0–10. Optional admin floor/ceiling proposed; negative/unbounded behavior needs confirmation. |
| D-005 | Adjustment steps | Confirmed: ±0.1 through ±1.0 | 0.1 increments only. |
| D-006 | Reason/history | Confirmed: reason required | Record actor, time, before/after and delta. |
| D-007 | Staff visibility | Confirmed default: invited staff see own merit only | Broader scope requires explicit permission. |
| D-008 | Roles | Confirmed direction: configurable function-level permissions | Owner/admin separation and delegation boundaries open. |
| D-009 | Provisioning | Confirmed: invite-only accounts, no public registration | Operator creates the first confirmed Auth user in Supabase Dashboard and allowlists that verified email in the private setup row; the first-login wizard claims Owner once. Owner invites CEO/Staff through Edge Function. |
| D-010 | Email | Confirmed requirement: SMTP for invitations and recovery | Configure custom SMTP in Supabase; provider choice and verified sender remain open. |
| D-011 | Hosting | Superseded | Owner-PC Rust service + SQLite replaced by D-021. |
| D-012 | Network scope | Superseded/open | Office-LAN-only replaced by hosted direction; whether office-only access remains required is open. |
| D-013 | Static IP | Not applicable to hosted v1 | Installer will not change PC/router IP. Domain/access restrictions open. |
| D-014 | Stack | Superseded | Rust/React/Tauri/SQLite replaced by Flutter + GitHub Pages + Supabase. |
| D-015 | IDE | Assumption: “Web Mason” means WebStorm | Not a runtime decision. |
| D-016 | Security level | User requested level three; mapping proposed | OWASP ASVS v5 L3 planning target, not certification or DDoS immunity. |
| D-017 | Open source | Confirmed | License and contribution/security policy open. |
| D-018 | Reports | CSV required; PDF proposed | Confirm formats. |
| D-019 | UI language | Open | Bahasa Melayu likely; English support unconfirmed. |
| D-020 | Retention | Open | Set retention and deletion/anonymization policy before production. |
| D-021 | Deployment stack | Confirmed direction: GitHub, GitHub Pages, Supabase and Flutter | Flutter Web static output on Pages; hosted Supabase Auth/data. Scaffold/workflows/migration are in the workspace; no cloud deployment configured yet. |
| D-022 | Cloud region/plan | Open | Review jurisdiction, backups, restore, quotas, support and cost. Singapore is a candidate only. |
| D-023 | Repository visibility | Open | Source is open source, but repo visibility and Pages plan remain undecided. Flutter bundle is inspectable either way. |
| D-024 | Mobile release | Open | Confirm Android/iOS, distribution and whether included in web v1. |
| D-025 | Domain/access boundary | Open | Choose URL, Auth redirects, and whether office-only access remains required. |
| D-026 | Recovery/operations | Open | Set RPO/RTO, backup retention, restore owner and incident process. |
| D-027 | Desktop installer | Deferred for v1 | Hosted Flutter Web removes the always-running owner-PC service/installer requirement. Revisit only if requested. |
| D-028 | Initial access model | Confirmed direction | One system maintainer/Owner and one CEO, with additional staff only by invitation. Public registration is disabled; Owner alone invites and assigns roles. |
| D-029 | Privileged-user MFA | Implemented direction; deployment setup required | Owner and CEO must use TOTP MFA; database policies/functions require AAL2 for their operational permissions. Recovery and secondary-factor runbook remain to be completed. |
| D-030 | Invitation email | Confirmed requirement | Custom SMTP must be configured in Supabase for production invitations and password recovery. Credentials remain in Supabase settings, never the Flutter client. |
| D-031 | Built-in roles | Confirmed implementation direction | Owner (maintainer) controls invites; CEO manages staff/merit; invited Staff is self-only by default. Owner and CEO require TOTP MFA/AAL2 for operations. |
