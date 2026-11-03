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

Migration terkini ialah `20261103010000_initial_schema.sql`. **Jangan teruskan push jika migration `20261103010000` sudah tercatat sebagai applied tetapi schema itu bukan versi semasa repo.** Migration yang sudah applied tidak dijalankan semula. Semak schema remote; jika ia schema lama, sediakan migration pembaikan forward yang disemak terlebih dahulu. Jika projek mengandungi schema/data lain, hentikan dan buat pelan migrasi khusus—jangan reset projek.

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

## 3. Cipta Owner pertama

Buat akaun Auth Owner pertama melalui kaedah admin yang diluluskan dan pastikan emailnya verified. Selepas migration berjaya, jalankan SQL berikut di SQL Editor Dashboard sebagai project operator. Tukar email dan nama placeholder:

```sql
insert into public.profiles
  (user_id, email, display_name, role, staff_id, is_active, must_set_password)
select id, email, 'Moon', 'owner', null, true, false
from auth.users
where email = 'OWNER_EMAIL_HERE'
  and email_confirmed_at is not null
  and not exists (select 1 from public.profiles where role = 'owner');
```

Semak hasilnya sebelum login. Jangan dedahkan SQL Editor kepada client dan jangan cipta endpoint bootstrap awam. Log masuk, enroll TOTP, sahkan aal2. Jemput CEO/staff hanya selepas invitation SMTP diuji.

## 4. Deploy invitation function

Pastikan `SITE_URL` dan `CORS_ORIGINS` sepadan dengan alamat production sebenar. Arahan ini menulis konfigurasi fungsi pada project yang telah dilink:

```powershell
supabase secrets set SITE_URL=https://moonwiraja.github.io/KPI/ CORS_ORIGINS=https://moonwiraja.github.io,http://localhost:7357 --remote
supabase functions deploy invite-user --remote
```

Fungsi menggunakan kunci terbina dalam Supabase Edge Functions dan masih menerima nama legacy jika runtime projek membekalkannya. Jangan cipta/letak service-role key dalam Flutter atau Actions variables. Semak log fungsi tanpa menyalin token atau kandungan peribadi.

## 5. Sambung GitHub Pages

Di GitHub repo `MoonWIRaja/KPI`:

1. Tambah **Actions variables** `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` daripada Dashboard → API Settings. Ini konfigurasi client awam; ia bukan pengganti RLS.
2. Pilih **Settings → Pages → GitHub Actions**.
3. Workflow Pages hanya deploy dari `main` dan membina app di subpath `/KPI/`. Semak branch/Actions status serta redirect URL selepas release.
4. Jangan simpan kunci `secret`/`service_role`, password database atau SMTP di repository variables, source code, chat atau artifact.

## 6. Checklist selepas konfigurasi

- Login Owner, MFA, jemputan email, password setup dan sign-out diuji dengan akaun bukan produksi dahulu.
- Uji seorang CEO dan seorang Staff: Staff hanya boleh baca rekod merit sendiri; manipulasi ID/API tidak membuka data orang lain.
- Uji tambah/edit/archive/import, larangan partial CSV import, bounds score, pelarasan dengan reason, correction, permission revoke dan export audit.
- Semak Auth redirect, fungsi jemputan, Pages base path dan skrin phone browser.
- Tentukan region/privasi, retention, kos/quota, backup, owner recovery dan incident contact sebelum masukkan data pekerja sebenar.

Migration CI menyemak stack Supabase tempatan; ia tidak membuktikan tetapan akaun awan, SMTP, backup atau project RLS remote telah dikonfigurasi. Arahan CLI `--dry-run` memaparkan migration yang akan dihantar tanpa menerapkannya; `db push --remote` hanya menerapkan migration yang belum direkod applied. Rujuk [Supabase CLI workflow](https://supabase.com/docs/guides/local-development/cli-workflows) dan [Edge Function secrets](https://supabase.com/docs/guides/functions/secrets).
