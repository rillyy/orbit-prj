# ORBIT — Portal Pegawai Teladan BPS Provinsi Sulawesi Utara

**ORBIT** (*Outstanding Recognition & Benchmarking Tool*) adalah aplikasi web berbasis **Supabase** yang dirancang untuk mendukung proses penilaian, nominasi, verifikasi, dan pengarsipan Pegawai Teladan di lingkungan BPS Provinsi Sulawesi Utara.

Project ini dibuat sebagai sistem terintegrasi dengan beberapa role pengguna, yaitu **Admin**, **Juri**, **Verifikator**, dan **Pegawai**. Seluruh proses utama, mulai dari input nilai bulanan, penentuan nominasi, penilaian juri, verifikasi pemenang, hingga arsip penghargaan, dikelola dalam satu portal.

---

## Daftar Isi

- [Ringkasan Project](#ringkasan-project)
- [Fitur Utama](#fitur-utama)
- [Role Pengguna](#role-pengguna)
- [Teknologi yang Digunakan](#teknologi-yang-digunakan)
- [Struktur Paket Project](#struktur-paket-project)
- [Struktur Repository yang Disarankan](#struktur-repository-yang-disarankan)
- [Komponen Utama](#komponen-utama)
- [Alur Sistem](#alur-sistem)
- [Instalasi dan Setup](#instalasi-dan-setup)
- [Konfigurasi Supabase](#konfigurasi-supabase)
- [Database dan Supabase Schema](#database-dan-supabase-schema)
- [Pengujian Sistem](#pengujian-sistem)
- [Deployment](#deployment)
- [Catatan Keamanan](#catatan-keamanan)
- [Troubleshooting Singkat](#troubleshooting-singkat)
- [Dokumentasi Tambahan](#dokumentasi-tambahan)
- [Status Project](#status-project)

---

## Ringkasan Project

ORBIT dikembangkan untuk membantu digitalisasi proses pemilihan Pegawai Teladan agar lebih:

- **terstruktur**, karena setiap tahap memiliki alur kerja yang jelas;
- **terukur**, karena penilaian berbasis data nilai bulanan dan penilaian juri;
- **transparan**, karena progres nominasi dan penilaian dapat dipantau sesuai role;
- **terintegrasi**, karena frontend, database, authentication, storage, dan logic sistem terhubung melalui Supabase.

Aplikasi ini menggunakan pendekatan **single-page application** dalam satu file `index.html`, dengan backend menggunakan **Supabase PostgreSQL**, **Supabase Auth**, **RPC/Function**, **Row Level Security**, dan **Storage Bucket**.

---

## Fitur Utama

### 1. Authentication dan Manajemen Akun

- Sign In menggunakan Supabase Authentication.
- Sign Up akun baru melalui aplikasi.
- Akun baru otomatis masuk ke status `pending`.
- Admin dapat mengaktifkan akun dan menentukan role.
- Sistem mendukung status akun `pending`, `aktif`, dan `nonaktif`.
- Profil aplikasi tersimpan di tabel `public.users`.

### 2. Manajemen Role

Role yang tersedia:

- `admin`
- `juri`
- `verifikator`
- `pegawai`

Setiap role memiliki akses dan menu yang berbeda sesuai fungsi masing-masing.

### 3. Input Nilai Bulanan

- Admin dapat menginput nilai pegawai berdasarkan tahun, triwulan, dan bulan.
- Nilai disimpan dalam tabel `nilai_final`.
- Sistem mendukung penyimpanan nilai secara real-time melalui RPC.
- Nilai bulanan menjadi dasar dalam proses penentuan kandidat nominasi.

### 4. Nominasi Pegawai Teladan

- Sistem menampilkan kandidat nominasi berdasarkan nilai tertinggi.
- Nominasi dikelompokkan berdasarkan tim/divisi.
- Admin dapat memilih nominasi final.
- Setelah dikirim ke juri, proses nominasi terkunci agar alur tetap konsisten.

### 5. Penilaian Juri

- Juri aktif dapat melihat daftar nominasi.
- Juri dapat memberikan nilai untuk kandidat.
- Juri hanya dapat mengubah atau menghapus nilai miliknya sendiri.
- Sistem menampilkan status/progres penilaian setiap juri.

### 6. Ranking dan Verifikasi

- Ranking live dihitung berdasarkan nilai juri.
- Admin dapat mengirim ranking ke verifikator setelah seluruh juri menyelesaikan penilaian.
- Verifikator dapat menetapkan pemenang.
- Verifikator dapat mengembalikan proses ke admin apabila diperlukan koreksi.

### 7. Arsip Penghargaan

- Pemenang yang telah ditetapkan masuk ke tabel `history_penghargaan`.
- Arsip penghargaan tidak ikut terhapus saat siklus penilaian baru dimulai.
- Sistem mendukung pengelolaan sertifikat penghargaan.

### 8. Upload dan Storage

- Project menggunakan bucket Supabase Storage bernama `doc-pegawai`.
- File pendukung, dokumen, dan sertifikat dapat dikelola melalui storage.
- Akses file dibatasi melalui policy Supabase.

---

## Role Pengguna

| Role | Fungsi Utama |
|---|---|
| **Admin** | Mengelola akun, pegawai, juri, nilai bulanan, nominasi, pengiriman ke juri, pengiriman ke verifikator, file, dan siklus penilaian. |
| **Juri** | Memberikan penilaian terhadap nominasi yang telah dikirim oleh admin. |
| **Verifikator** | Memeriksa ranking akhir, menetapkan pemenang, atau mengembalikan proses apabila perlu koreksi. |
| **Pegawai** | Role dasar untuk akun pegawai. Akun baru dari Sign Up masuk sebagai pegawai dengan status awal `pending`. |

---

## Teknologi yang Digunakan

| Komponen | Teknologi |
|---|---|
| Frontend | HTML, CSS, JavaScript |
| Backend | Supabase |
| Database | PostgreSQL |
| Authentication | Supabase Auth |
| Authorization | Supabase Row Level Security |
| Business Logic | PostgreSQL Function / RPC |
| Storage | Supabase Storage |
| UI Assets | Google Fonts, Supabase JS CDN |
| Deployment | Static hosting, misalnya GitHub Pages, Netlify, Vercel, atau hosting internal |

---

## Struktur Paket Project

Berdasarkan paket `ORBIT_BPS_GUIDEBOOK_FINAL_PACKAGE.zip`, struktur file yang dianalisis adalah sebagai berikut:

```text
ORBIT_BPS_GUIDEBOOK_FINAL_PACKAGE/
├── GUIDE_BOOK/
│   ├── GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.docx
│   └── GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.pdf
├── README_SERAH_TERIMA.txt
├── SHA256SUMS.txt
└── ORBIT_BPS_HANDOVER_LENGKAP.zip
```

Di dalam `ORBIT_BPS_HANDOVER_LENGKAP.zip`, terdapat struktur berikut:

```text
ORBIT_BPS_HANDOVER_LENGKAP/
├── README.md
└── ORBIT/
    ├── index.html
    ├── supabase_schema.sql
    └── docs/
        ├── PANDUAN_INSTALASI.md
        ├── CHECKLIST_UJI_SISTEM.md
        └── CATATAN_KONFIGURASI_AKUN.md
```

---

## Struktur Repository yang Disarankan

Untuk repository GitHub, struktur yang disarankan adalah:

```text
orbit-bps/
├── README.md
├── ORBIT/
│   ├── index.html
│   ├── supabase_schema.sql
│   └── docs/
│       ├── PANDUAN_INSTALASI.md
│       ├── CHECKLIST_UJI_SISTEM.md
│       └── CATATAN_KONFIGURASI_AKUN.md
├── GUIDE_BOOK/
│   ├── GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.docx
│   └── GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.pdf
├── README_SERAH_TERIMA.txt
└── SHA256SUMS.txt
```

Catatan:

- Untuk GitHub, sebaiknya file `ORBIT_BPS_HANDOVER_LENGKAP.zip` diekstrak terlebih dahulu agar isi project dapat dibaca langsung.
- File ZIP boleh tetap disimpan sebagai arsip serah-terima, tetapi struktur folder utama tetap disarankan terbuka seperti contoh di atas.
- File `README.md` ini diletakkan di root repository.

---

## Komponen Utama

### `ORBIT/index.html`

File utama aplikasi web ORBIT.

Isi utama file ini:

- tampilan halaman login;
- layout dashboard;
- sidebar multi-role;
- halaman admin;
- halaman juri;
- halaman verifikator;
- halaman pegawai;
- logic koneksi Supabase;
- pemanggilan tabel database;
- pemanggilan RPC/function;
- validasi dan interaksi frontend.

File ini juga memuat konfigurasi:

```js
const SUPABASE_URL  = '...';
const SUPABASE_ANON = '...';
```

Jika project Supabase diganti, kedua nilai tersebut wajib disesuaikan.

### `ORBIT/supabase_schema.sql`

File schema utama database Supabase.

File ini berisi:

- pembuatan tabel;
- constraint;
- index;
- trigger;
- function/RPC;
- Row Level Security;
- policy akses;
- storage bucket;
- seed data awal;
- logic operasional untuk alur penilaian.

### `ORBIT/docs/PANDUAN_INSTALASI.md`

Panduan teknis untuk menjalankan database dan aplikasi dari awal.

### `ORBIT/docs/CHECKLIST_UJI_SISTEM.md`

Checklist pengujian setelah sistem dijalankan.

### `ORBIT/docs/CATATAN_KONFIGURASI_AKUN.md`

Dokumen khusus terkait role, status akun, Supabase Auth, dan aktivasi user.

### `GUIDE_BOOK/GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.docx`

Guide book versi Word yang dapat diedit untuk kebutuhan institusi.

### `GUIDE_BOOK/GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.pdf`

Guide book versi PDF yang siap dibaca, dicetak, atau diserahkan.

### `README_SERAH_TERIMA.txt`

Catatan ringkas isi paket dan hal penting saat serah-terima.

### `SHA256SUMS.txt`

Checksum file untuk membantu memastikan file tidak berubah setelah diserahkan.

---

## Alur Sistem

Alur umum penggunaan ORBIT adalah sebagai berikut:

```text
Admin Login
    ↓
Admin Mengelola User, Pegawai, dan Juri
    ↓
Admin Input Nilai Bulanan
    ↓
Sistem Menentukan Kandidat Nominasi
    ↓
Admin Memilih dan Mengirim Nominasi ke Juri
    ↓
Juri Memberikan Penilaian
    ↓
Sistem Menghitung Ranking Live
    ↓
Admin Mengirim Ranking ke Verifikator
    ↓
Verifikator Menetapkan Pemenang
    ↓
Pemenang Masuk ke Arsip Penghargaan
```

---

## Instalasi dan Setup

### 1. Siapkan Project Supabase

Buat project Supabase baru atau gunakan project Supabase yang sudah tersedia.

### 2. Jalankan Schema Database

1. Buka Supabase Dashboard.
2. Masuk ke menu **SQL Editor**.
3. Pilih **New Query**.
4. Buka file berikut:

```text
ORBIT/supabase_schema.sql
```

5. Copy seluruh isi file SQL.
6. Paste ke SQL Editor.
7. Klik **Run**.
8. Pastikan tidak ada error.

Schema akan membuat tabel, function, trigger, policy, storage bucket, dan data awal yang diperlukan aplikasi.

### 3. Konfigurasi Supabase di Frontend

Buka file:

```text
ORBIT/index.html
```

Cari bagian konfigurasi Supabase:

```js
const SUPABASE_URL  = '...';
const SUPABASE_ANON = '...';
```

Ganti nilainya jika menggunakan project Supabase baru.

### 4. Buat Akun Authentication

SQL hanya membuat struktur dan profil aplikasi. Password tetap harus dibuat melalui **Supabase Authentication**.

Langkah awal yang disarankan:

1. Buka **Authentication → Users** di Supabase.
2. Buat user admin dengan email yang sesuai dengan data awal di tabel `public.users`.
3. Atur password.
4. Login melalui aplikasi ORBIT.
5. Admin dapat mengaktifkan dan mengatur role user lain.

### 5. Jalankan Aplikasi

Aplikasi dapat dijalankan dengan membuka file:

```text
ORBIT/index.html
```

Untuk penggunaan lokal sederhana, file dapat dibuka langsung melalui browser.

Untuk penggunaan yang lebih rapi, gunakan hosting statis seperti GitHub Pages, Netlify, Vercel, atau server internal.

---

## Konfigurasi Supabase

### Lokasi Konfigurasi

Konfigurasi Supabase berada di dalam `index.html`:

```js
const SUPABASE_URL  = '...';
const SUPABASE_ANON = '...';
```

### Cara Mendapatkan Nilai Supabase

1. Buka Supabase Dashboard.
2. Masuk ke **Project Settings**.
3. Pilih **API**.
4. Salin:
   - Project URL
   - Anon/Public Key

### Catatan Penting

- `anon key` boleh digunakan di frontend karena memang public key.
- Jangan pernah memasukkan `service_role key` ke dalam frontend, GitHub publik, atau dokumen yang dibagikan.
- Keamanan data tetap dikendalikan melalui RLS policy dan RPC pada database.

---

## Database dan Supabase Schema

### Tabel Utama

Schema final memuat tabel berikut:

| Tabel | Fungsi |
|---|---|
| `users` | Profil aplikasi, role, status akun, dan relasi ke Supabase Auth. |
| `pegawai` | Master data pegawai dan tim/divisi. |
| `juri` | Data juri aktif/nonaktif. |
| `nilai_final` | Nilai bulanan pegawai. |
| `nominasi_final` | Nominasi yang dikirim ke juri/verifikator. |
| `penilaian` | Nilai dari masing-masing juri. |
| `history_penghargaan` | Arsip pemenang yang telah disetujui. |
| `notifikasi` | Informasi/pesan untuk role tertentu. |
| `excel_uploads` | Riwayat file/dokumen yang diunggah. |
| `sertifikat` | Data sertifikat pemenang. |
| `kipapp` | Dokumen atau file terkait KIPAPP. |
| `permintaan_koreksi` | Catatan koreksi dari proses verifikasi. |
| `audit_log` | Catatan aktivitas penting sistem. |
| `orbit_schema_migrations` | Penanda versi schema. |

### Function/RPC Penting

Beberapa function/RPC utama:

| Function/RPC | Fungsi |
|---|---|
| `orbit_login_profile` | Mengambil profil user login dan validasi status akun. |
| `orbit_update_my_profile` | Mengubah profil user sendiri. |
| `orbit_admin_upsert_user` | Admin membuat/memperbarui profil user aplikasi. |
| `simpan_nilai_bulanan_realtime` | Menyimpan nilai bulanan pegawai. |
| `orbit_simpan_nilai_final` | Menyimpan nilai final. |
| `get_kalender_operasional` | Mengambil kalender/periode operasional. |
| `get_nominasi_bulanan_per_tim` | Mengambil kandidat nominasi bulanan per tim. |
| `get_kandidat_nominasi_triwulan` | Mengambil kandidat nominasi triwulan. |
| `kirim_nominasi_ke_juri` | Mengirim nominasi dari admin ke juri. |
| `simpan_penilaian_juri` | Menyimpan penilaian juri. |
| `hapus_penilaian_juri` | Menghapus nilai juri sesuai aksesnya. |
| `get_daftar_juri_status` | Menampilkan status/progres penilaian juri. |
| `get_ranking_live` | Menghitung ranking berdasarkan nilai juri. |
| `kirim_ranking_ke_verifikator` | Mengirim hasil ranking ke verifikator. |
| `tetapkan_pemenang` | Menetapkan pemenang dan memasukkan ke arsip. |
| `kembalikan_ke_admin` | Mengembalikan proses dari verifikator ke admin. |
| `buka_kembali_setelah_koreksi` | Membuka kembali proses setelah koreksi. |
| `reset_penilaian_baru` | Memulai siklus penilaian baru tanpa menghapus arsip. |

---

## Pengujian Sistem

Setelah setup selesai, gunakan checklist berikut:

- Admin dapat login.
- User baru dapat Sign Up.
- User baru masuk status `pending`.
- Admin dapat mengaktifkan user.
- Admin dapat mengatur role user.
- Admin dapat input nilai bulanan.
- Kandidat nominasi tampil sesuai data nilai.
- Admin dapat mengirim nominasi ke juri.
- Juri dapat menyimpan penilaian.
- Ranking live tampil.
- Admin dapat mengirim hasil ke verifikator.
- Verifikator dapat menetapkan pemenang.
- Pemenang masuk ke arsip penghargaan.
- Sertifikat dan file pendukung dapat dikelola.
- RLS policy membatasi akses sesuai role.

Checklist lebih lengkap tersedia pada:

```text
ORBIT/docs/CHECKLIST_UJI_SISTEM.md
```

---

## Deployment

Aplikasi ORBIT dapat dijalankan sebagai static web app.

### Opsi deployment

- GitHub Pages
- Netlify
- Vercel
- Hosting internal BPS
- Web server statis sederhana

### Catatan Deployment

Karena aplikasi masih berbentuk satu file `index.html`, deployment cukup dilakukan dengan mengunggah file tersebut ke hosting statis.

Pastikan:

- `SUPABASE_URL` sudah benar.
- `SUPABASE_ANON` sudah benar.
- Supabase schema sudah dijalankan.
- Akun Auth sudah dibuat.
- RLS policy sudah aktif.
- Storage bucket tersedia.

---

## Catatan Keamanan

Hal yang harus diperhatikan:

1. Jangan membagikan **password akun**.
2. Jangan memasukkan **service role key** ke dalam file frontend.
3. Gunakan `anon/public key` saja pada frontend.
4. Pastikan RLS policy tetap aktif.
5. Pastikan user yang belum aktif tetap berstatus `pending`.
6. Admin sebaiknya rutin mengecek user aktif.
7. Backup database dilakukan sebelum perubahan besar.
8. Repository publik sebaiknya tidak memuat kredensial sensitif atau data produksi.
9. Jika repository dibuat publik, pertimbangkan untuk mengganti Supabase project key sebelum dipublikasikan.

---

## Troubleshooting Singkat

### User tidak bisa login

Cek:

- Akun sudah ada di Supabase Authentication.
- Email Auth sama dengan email di tabel `public.users`.
- Status user di `public.users` sudah `aktif`.
- Role user sudah benar.
- `SUPABASE_URL` dan `SUPABASE_ANON` di `index.html` sesuai project.

### Data tidak muncul

Cek:

- Schema SQL sudah dijalankan penuh.
- RLS policy tidak error.
- User login memiliki role yang sesuai.
- Tabel terkait sudah memiliki data.
- Browser console tidak menampilkan error Supabase.

### Juri tidak bisa menilai

Cek:

- User memiliki role `juri`.
- Status user `aktif`.
- User sudah tersinkron dengan tabel `juri`.
- Nominasi sudah dikirim oleh admin.
- Proses masih berada pada tahap penilaian juri.

### Verifikator tidak bisa menetapkan pemenang

Cek:

- User memiliki role `verifikator`.
- Status user `aktif`.
- Admin sudah mengirim ranking ke verifikator.
- Proses berada pada status verifikasi.
- Belum ada pemenang pada periode yang sama.

### File tidak bisa diunggah

Cek:

- Bucket `doc-pegawai` sudah tersedia.
- Policy storage sudah aktif.
- User memiliki role admin.
- File tidak melebihi batas upload Supabase.
- Koneksi internet stabil.

---

## Dokumentasi Tambahan

Dokumentasi lengkap tersedia pada folder:

```text
GUIDE_BOOK/
```

Isi folder:

- `GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.docx`
- `GUIDE_BOOK_PROJECT_ORBIT_BPS_FINAL.pdf`

Dokumen teknis tambahan tersedia pada:

```text
ORBIT/docs/
```

Isi folder:

- `PANDUAN_INSTALASI.md`
- `CHECKLIST_UJI_SISTEM.md`
- `CATATAN_KONFIGURASI_AKUN.md`

---

## Rekomendasi Pengelolaan Repository

Untuk menjaga repository tetap rapi:

- gunakan `README.md` ini sebagai dokumentasi utama;
- letakkan file aplikasi pada folder `ORBIT/`;
- letakkan dokumen manual pada folder `GUIDE_BOOK/`;
- hindari menyimpan file ZIP berulang jika isi file sudah diekstrak;
- gunakan commit message yang jelas;
- jangan commit password atau service role key;
- lakukan update README jika ada perubahan besar pada schema atau flow sistem.

Contoh commit message:

```text
feat: add final ORBIT handover package
docs: update installation guide
fix: adjust Supabase schema for user role flow
chore: add guide book and checksum
```

---

## Status Project

Status: **Final Handover Package**

Paket ini sudah memuat:

- aplikasi web ORBIT;
- schema database Supabase;
- dokumentasi instalasi;
- checklist pengujian;
- catatan konfigurasi akun;
- guide book project;
- checksum file;
- catatan serah-terima.

Project siap digunakan sebagai bahan serah-terima, dokumentasi GitHub, dan setup awal pada project Supabase pihak BPS.

---

## Kredit

Project ORBIT dikembangkan sebagai bagian dari kegiatan magang dan pengembangan sistem pendukung proses penilaian Pegawai Teladan BPS Provinsi Sulawesi Utara.

