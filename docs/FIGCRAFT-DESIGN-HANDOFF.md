# FigCraft Frontend Design Handoff

**Status:** Updated by Kid through FigCraft MCP. The prototype at `design/merit-tracker-v1.figcraft` contains 11 product screens plus a motion-spec board. Screenshots were reviewed after the latest edits; Moon's visual approval is still pending.
**Design owner:** Moon
**Registered AI agent:** Kid (`kid`)
**Phase:** Product UI visual prototype completed. 11 preview PNGs exported to `design/previews/`. Ready for Moon's sign-off before frontend implementation.

## 1. Goal

Create an editable FigCraft prototype so Moon can review the proposed Merit Tracker screens before frontend implementation. The deliverable should show the productâ€™s visual direction, key admin and staff journeys, responsive phone behavior and a small set of purposeful motion notes.

Do not create React, Flutter, HTML/CSS, API, database or installer code during this phase. Do not convert the prototype into a production UI until Moon approves the design.

## 2. Design read and motion weighting

**Reading this as:** an internal workforce-data dashboard for an owner/admin and invited staff, with a calm, trustworthy, polished product style. Merit should be legible and explainable; the interface should not gamify staff performance or encourage public ranking.

- **Design direction:** restrained enterprise product UI with clear hierarchy, carefully composed tables and profile/history views.
- **Variance:** low-to-moderate. Use purposeful layout variation, not decorative asymmetry that harms scanning.
- **Motion:** low intensity. Emil Kowalski is the primary lens for frequent dashboard actions; Jakub Krehel is secondary for production polish. Use Jhey-style delight only in a rare empty/onboarding state if it helps comprehension.
- **Density:** moderate. Admin screens can show useful data; staff phone screens should remain simple.
- **Brand colors and logo:** retain the prototype's existing navy, slate, blue and semantic green/red palette. Do not introduce a new palette. Keep the restrained light surfaces and compact, readable typography.

### Motion rules

- High-frequency actions such as table filters, navigation and merit-step selection should be instant or use a subtle transition.
- A modal or side panel may enter/exit with restrained opacity and small translation. A saved score may briefly confirm the new state.
- Avoid looping motion, parallax, bounce, spinning, large zooms and decorative motion.
- Provide a reduced-motion alternative for every animated state. Motion must never be required to understand a score change or validation error.
- Describe intended timing/easing in annotations; the prototype does not need production animation code.

## 3. Prototype deliverables

Create an editable `.figcraft` document at the proposed path:

```text
design/merit-tracker-v1.figcraft
```

Include a desktop board at approximately `1440 Ã— 900`, a narrow phone board at approximately `390 Ã— 844`, reusable components and short annotations for states/motion. A preview PNG/PDF may be exported for review, but the editable FigCraft file is the source artifact.

Use clearly fictitious staff data (for example, `ST-001`, `Amina Rahman`) and label it as prototype data. Do not copy real employee data into the design file.

## 4. Screens to prototype

### Admin desktop

1. **Admin login** â€” email, password, clear error state and password visibility control.
2. **Dashboard** â€” total active staff, recent merit changes and admin actions. Do not show a staff ranking leaderboard.
3. **Staff directory** â€” search, active/archived filters, staff code, name, current merit and latest change.
4. **Staff profile** â€” one overall merit score, starting score/default indicator and chronological history with reason, actor and time.
5. **Merit adjustment dialog** â€” choose increase/decrease and one exact step from `0.1` to `1.0`; require reason; preview score before, delta and score after; confirm/cancel/error/success states.
6. **CSV import** â€” choose file, preview valid/error/duplicate rows, download error details, cancel or confirm. Show that no changes occur before confirmation.
7. **Report view** â€” filter by staff/date/actor/direction, inspect rows, show a sensitive-export warning and export CSV. PDF can be shown as a future option, not a confirmed feature.
8. **Users and roles** â€” list users and role editor with grouped function permissions and explicit `Self` vs `All` scope. Show default staff role as self-view only.
9. **Settings** â€” default starting score `5`, optional score floor/ceiling, SMTP status/configuration and service/network status. The SMTP secret field must appear write-only.

### Invited staff phone

1. **Staff login/activation** â€” one-time local activation code or invitation state.
2. **My merit** â€” current score and latest changes, limited to the signed-in staff member.
3. **Merit history detail** â€” date, change, reason and actor where the policy allows disclosure.
4. **Account** â€” password/session actions available to the staff role.

The responsive phone/web prototype should not include staff directory, other staff profiles, adjustment actions or admin-only settings for the default staff role. The eventual Flutter mobile release is still undecided.

## 5. Core facts the visual design must preserve

- One overall merit score per staff member.
- Default starting merit is `5`; an admin can override the initial value for an individual.
- No fixed `0â€“10` range is currently approved. Optional admin bounds are a proposal; show them as optional settings and mark the unset-bound behavior for review.
- Adjustments are fixed choices from `Â±0.1` through `Â±1.0`, in `0.1` steps.
- Every adjustment requires a reason and confirmation after the before/delta/after preview.
- Staff accounts are invite-only and default to their own record only.
- Admin permissions are configurable by function and enforced by the future backend.
- Hosted web deployment is the current direction. Do not imply that a public URL or client-side route is an authorization control; access policy remains open.

## 6. Visual quality checks

- The main score is immediately readable and always shown with one decimal place.
- Positive/negative movement is communicated by text/icon as well as color.
- No default purple AI gradients, glassmorphism, generic three-card hero, fake metrics or decorative â€œAIâ€ labels.
- Avoid public comparisons, gamified rank badges and celebratory treatment for reducing another personâ€™s score.
- Keep contrast, labels, focus, error messages and touch targets visible in the prototype.
- Show empty, loading, validation-error and success states for the main workflows.
- Keep reason and score history in the primary review flow; do not hide them behind a decorative chart.

## 7. MCP and host handoff

The project has a shared FigCraft declaration in `.Mcore/mcp-servers.json`. The current session exposes FigCraft MCP tools, and the editable prototype exists at `design/merit-tracker-v1.figcraft`. Other provider hosts still need their own working MCP connection.

For a later provider handoff:

1. Load the project instructions and authenticate MemoryCore as Moon / Kid (`moon` / `kid`).
2. Confirm Antigravity has a working FigCraft MCP connection and can open the existing `.figcraft` document.
3. If the MCP is missing, configure the FigCraft stdio server in Antigravity itself; do not claim the shared declaration alone connected it.
4. Read this handoff, `docs/DESIGN-SPEC.md`, `docs/PRD.md`, `docs/ROLE-PERMISSION-MATRIX.md`, and the relevant UI/UX, Hallmark Design, Anti-Slop, Design Taste Frontend and Design Motion Principles skills in `.Mcore/Feature/`.
5. Create only the FigCraft prototype and visual exports. Do not write app source code.
6. Return the editable document path, preview and open questions for Moonâ€™s approval.

## 8. Antigravity task prompt

```text
You are Kid, continuing the Merit Tracker project for Moon. Read AGENTS.md, .Mcore/rules.md, authenticate MemoryCore as user moon and agent kid, then read docs/FIGCRAFT-DESIGN-HANDOFF.md and its referenced PRD/design/role documents.

This handoff governed the design-only phase. If design work resumes, use FigCraft MCP to review/update `design/merit-tracker-v1.figcraft`, preserve its established palette, and use fictitious data only. Current product requirements and deployment live in `docs/PRD.md`: Flutter client, GitHub Pages web hosting and Supabase auth/data. Keep score bounds, PDF export, language, staff-history disclosure, cloud region, domain and account delivery open. Do not claim a FigCraft edit unless the MCP operation succeeds.

When finished, show the prototype and preview to Moon. Wait for explicit visual approval before any implementation phase.
```

## 9. Approval gate

Moon reviews:

- Overall visual direction, palette, typography and density.
- Dashboard and staff-directory hierarchy.
- Merit adjustment preview, reason emphasis and confirmation behavior.
- Staff self-view privacy and mobile layout.
- Role editor clarity and admin-only settings.
- Motion examples and reduced-motion alternatives.
- Any unresolved product assumptions called out above.

Implementation should translate the approved FigCraft prototype into Flutter screens, with Flutter Web deployed to GitHub Pages and connected securely to Supabase. Mobile targets remain subject to the release decision.
