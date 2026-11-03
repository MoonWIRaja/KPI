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
2. Kekalkan email provider dan tetapkan password policy/rate limit yang sesuai.
3. Benarkan TOTP authenticator MFA; Owner dan CEO perlu mendaftar serta mengesahkan faktor sebelum guna akses pengurusan.
4. Set Auth **Site URL** kepada `https://moonwiraja.github.io/KPI/` dan tambah redirect URL itu serta URL pembangunan yang benar-benar digunakan. Elakkan wildcard yang tidak diperlukan.
5. Atur SMTP custom di **Project Settings → Authentication → SMTP Settings**. Sahkan domain dan sender dengan pembekal; simpan kelayakan di Dashboard sahaja. Uji invitation dan password recovery menggunakan akaun ujian.

SMTP ialah sambungan keluar daripada Supabase Auth. PC bos tidak memerlukan public IP untuk penghantaran jemputan. Had dan reputasi email tertakluk kepada pembekal SMTP yang dipilih.

## 3. Sediakan wizard Owner pertama

Selepas semua migration setup berjaya digunakan, matikan public sign-up dan buat satu akaun Auth melalui Dashboard sebagai operator. Gunakan e-mel Owner yang disahkan, tetapkan kata laluan sementara, dan jangan invite pengguna lain dahulu. Apabila laman dibuka kali pertama, app memaparkan skrin Sediakan sistem anda; Owner log masuk di situ, kemudian melengkapkan nama serta kata laluan baharu pada wizard.

Di SQL Editor, benarkan satu alamat e-mel untuk tuntutan Owner pertama. Gantikan placeholder dan sahkan satu baris dikemas kini:

```sql
update public.initial_owner_setup
set expected_email = lower(trim('OWNER_EMAIL_HERE'))
where id = true and claimed_at is null and claimed_user_id is null;
```

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
