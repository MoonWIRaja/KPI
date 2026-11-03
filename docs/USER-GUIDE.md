# User Guide (Draft)

The application is not implemented yet. These proposed workflows must be checked against the released screens and account setup policy.

## Owner / administrator

### Sign in and configure
1. Open the approved Merit Tracker web address.
2. Sign in using the owner account created through the deployment's secure bootstrap procedure.
3. Keep the default starting merit at `5`, or choose a different organization default.
4. Optionally configure score bounds after the product owner confirms the policy.
5. Review roles and grant only the permissions each person needs.

### Add or import staff
1. Open **Staff → Add staff**, enter required fields and choose the default or individual starting score.
2. To import, download the template, fill supported columns and upload it.
3. Review valid rows, duplicates, warnings and errors. Cancel to leave data unchanged or confirm to import.

### Adjust merit
1. Open a staff profile and select **Adjust merit**.
2. Choose an increase/decrease between `0.1` and `1.0` in `0.1` steps.
3. Enter the required reason; review the before/after values and confirm.
4. Check **History** for the committed event. Corrections append a new event rather than erasing the original.

### Accounts and email

Admins provision invited accounts and assign roles. Public self-registration is disabled. Invitation and password recovery steps depend on the approved account-delivery method; automated email requires configured production SMTP. Do not use undocumented local activation codes.

### Reports
1. Open **Reports → Merit history**, select permitted staff/date filters and review the preview.
2. Confirm export permission and save the generated file in an approved private location.
3. CSV is planned; PDF requires product-owner approval.

## Invited staff

1. Open the approved web address or released mobile app, if mobile is in scope.
2. Follow the invitation/account activation instructions provided by the administrator.
3. Sign in and open **My merit** to see the current score and permitted history.
4. Contact an administrator if a record appears incorrect; staff cannot change merit by default.

## Frequently asked questions

**Is the system local to the boss's PC?** No. The new direction hosts the Flutter Web bundle on GitHub Pages and runtime data/auth in Supabase. Cloud processing must be approved before real staff data is entered.

**Does the app need a public IP?** The static web app uses a web URL and Supabase is hosted. A custom domain and any office-only access restriction remain decisions.

**Can an admin change merit without a reason?** No; every adjustment requires a reason.

**Can staff see another person's merit?** No, not with the default self-only role. Supabase authorization must enforce this independently of the interface.

**Does open-source code publish staff data?** Source code and the Flutter client are inspectable. Staff data must remain in the protected Supabase project; secrets and real records must not enter GitHub or Pages artifacts.
