# Sambungkan projek Supabase yang sedia ada

Panduan ini untuk menyambungkan aplikasi yang telah dibina kepada projek Supabase milik anda. Ia tidak mengubah projek awan dengan sendiri. Jalankan arahan dari PowerShell di akar repo dan masukkan kata laluan/project ref hanya pada terminal tempatan; jangan hantar kunci atau rahsia ke chat atau GitHub.

## 1. Semak project dan rekod migration dahulu

Pastikan anda memilih projek yang betul dalam Supabase Dashboard. Dapatkan **Project Ref** daripada URL/Project Settings dan sahkan sama ada projek itu masih kosong atau pernah menerima schema KPI terdahulu.

Pasang Supabase CLI, kemudian:

```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase migration list --remote
```

Migration asas ialah `20261103010000_initial_schema.sql`; claim Owner sekali sahaja berada dalam `20261103015100_owner_bootstrap_wizard.sql`, dan status first-run untuk app berada dalam `20261103022000_initial_owner_setup_status.sql`. **Jangan teruskan push jika migration asas sudah applied tetapi schema itu bukan versi aplikasi semasa.** Migration applied tidak dijalankan semula. Semak schema remote; jika ia schema lama, sediakan migration pembaikan forward yang disemak dahulu. Jika projek mengandungi schema/data lain, hentikan dan buat pelan migrasi khusus—jangan reset projek.

Jika projek kosong atau belum ada migration ini, lihat perubahan yang akan dihantar:

```powershell
supabase db push --dry-run --remote
```

Semak output serta nama projek yang disasarkan. Selepas anda sendiri sahkan sasaran dan SQL, apply:

```powershell
supabase db push --remote
```

CLI akan minta pengesahan bagi operasi remote mengikut versi semasa. Jangan guna `db reset` terhadap projek awan.

## 2. Sediakan Supabase Auth

Dalam Dashboard projek yang sama:

1. Matikan **Allow new users to sign up** supaya pengguna hanya boleh dijemput.
2. Kekalkan email provider. Log masuk kini menggunakan **Email OTP (One-Time Password)** tanpa kata laluan.
3. Benarkan TOTP authenticator MFA; Owner dan CEO boleh mendaftar serta mengesahkan faktor kedua sebelum guna akses pengurusan.
4. Set Auth **Site URL** kepada `https://moonwiraja.github.io/KPI/` dan tambah redirect URL itu serta URL pembangunan yang benar-benar digunakan. Elakkan wildcard yang tidak diperlukan.
5. Atur Google SMTP di **Project Settings → Authentication → SMTP Settings**:
   - **Enable Custom SMTP:** `ON`
   - **Sender email:** `support@mesrc.com.my`
   - **Sender name:** `Merit Tracker`
   - **Host:** `smtp.gmail.com`
   - **Port:** `587`
   - **Minimum transfer security:** `STARTTLS`
   - **User:** `support@mesrc.com.my`
   - **Password:** Masukkan 16-character Google Workspace App Password (jangan commit ke git).
   - Simpan tetapan dan hantar emel ujian untuk pengesahan.
6. Kemas kini template e-mel di **Authentication → Email Templates → Magic Link**:
   - Secara lalai, Supabase meletakkan pautan URL `{{ .ConfirmationURL }}` dan bukannya nombor kod 6-digit.
   - Supaya pengguna menerima kod 6-digit (OTP) dan bukannya pautan biasa, tukar **Subject** kepada: `Your Merit Tracker Verification Code`
   - Gantikan kandungan **Body** dengan HTML dari fail `supabase/templates/magic_link_otp.html` yang menggunakan token: `{{ .Token }}`.
   - Klik **Save changes**.

SMTP ialah sambungan keluar daripada Supabase Auth. PC bos tidak memerlukan public IP untuk penghantaran kod OTP.

## 3. Sediakan wizard Owner pertama

Selepas semua migration setup berjaya digunakan (termasuk `20261103030000_email_otp_auth_flow.sql`), matikan public sign-up.

Di SQL Editor, benarkan satu alamat e-mel untuk tuntutan Owner pertama (contohnya emel Moon):

```sql
update public.initial_owner_setup
set expected_email = lower(trim('OWNER_EMAIL_HERE'))
where id = true and claimed_at is null and claimed_user_id is null;
```

Apabila laman dibuka kali pertama:
1. Skrin *First-Run Setup* memaparkan kotak emel Owner.
2. Owner memasukkan emel `expected_email` yang dibenarkan dan menekan *Send setup code*.
3. Sistem menghantar 6-digit OTP melalui Google SMTP (`support@mesrc.com.my`).
4. Owner memasukkan kod OTP, mengesahkan nama paparan (*Owner name*), dan sistem mengunci tuntutan Owner secara atomik selama-lamanya.
5. Seterusnya, pengguna lain hanya boleh log masuk jika telah dijemput oleh Owner melalui fungsi *Invite user*. Pengguna tidak dijemput akan ditolak daripada menerima sebarang kod OTP.

Claim hanya berjaya jika e-mel tepat sepadan, telah disahkan dan belum ada Owner. Database mengunci tuntutan dalam satu transaksi dan menandakan setup selesai; selepas itu halaman first-run tidak muncul lagi dan semua orang menggunakan log masuk biasa. Owner perlu enroll TOTP. Tiada signup atau claim awam. Jemput CEO/staff hanya selepas invitation SMTP diuji.

## 4. Deploy invitation function

Pastikan `SITE_URL` dan `CORS_ORIGINS` sepadan dengan alamat production sebenar. Arahan ini menulis konfigurasi fungsi pada project yang telah dilink:

```powershell
supabase secrets set 'SITE_URL=https://moonwiraja.github.io/KPI/' 'CORS_ORIGINS=https://moonwiraja.github.io,http://localhost:7357' --remote
supabase functions deploy invite-user --remote
```

Fungsi menggunakan kunci terbina dalam Supabase Edge Functions dan masih menerima nama legacy jika runtime projek membekalkannya. Jangan cipta/letak service-role key dalam Flutter atau Actions variables. Semak log fungsi tanpa menyalin token atau kandungan peribadi.

## 5. Sambung GitHub Pages

Di GitHub repo `MoonWIRaja/KPI`:

1. Repository variables `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` sudah diisi untuk project ini. Kedua-duanya konfigurasi client awam; ia bukan pengganti RLS.
2. Pilih **Settings → Pages → GitHub Actions**.
3. Jalankan **Build and deploy Merit Tracker** melalui **Actions → Run workflow** pada branch release yang dipilih. Workflow membina app di subpath `/KPI/`. Semak status Actions serta redirect URL selepas release.
4. Jangan simpan kunci `secret`/`service_role`, password database atau SMTP di repository variables, source code, chat atau artifact.

## 6. Checklist selepas konfigurasi

- Login Owner, MFA, jemputan email, password setup dan sign-out diuji dengan akaun bukan produksi dahulu.
- Uji seorang CEO dan seorang Staff: Staff hanya boleh baca rekod merit sendiri; manipulasi ID/API tidak membuka data orang lain.
- Uji tambah/edit/archive/import, larangan partial CSV import, bounds score, pelarasan dengan reason, correction, permission revoke dan export audit.
- Semak Auth redirect, fungsi jemputan, Pages base path dan skrin phone browser.
- Tentukan region/privasi, retention, kos/quota, backup, owner recovery dan incident contact sebelum masukkan data pekerja sebenar.

Migration CI menyemak stack Supabase tempatan; ia tidak membuktikan tetapan akaun awan, SMTP, backup atau project RLS remote telah dikonfigurasi. Arahan CLI `--dry-run` memaparkan migration yang akan dihantar tanpa menerapkannya; `db push --remote` hanya menerapkan migration yang belum direkod applied. Rujuk [Supabase CLI workflow](https://supabase.com/docs/guides/local-development/cli-workflows) dan [Edge Function secrets](https://supabase.com/docs/guides/functions/secrets).
