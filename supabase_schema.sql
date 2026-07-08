-- ============================================================================
-- ORBIT — SUPABASE SCHEMA FINAL BERSIH
-- Portal Pegawai Teladan BPS Provinsi Sulawesi Utara
--
-- Sumber penyusunan:
-- - index.html final website ORBIT
-- - SCHEMA ORBIT.txt mentah berisi migration/patch lama
--
-- Tujuan file:
-- - Menjadi supabase_schema.sql utuh untuk project Supabase baru.
-- - Menghapus pengulangan migration lama dan hanya menyisakan struktur yang
--   masih dipakai oleh HTML final.
-- - Menyertakan komentar/keterangan pada setiap bagian query.
--
-- Cara pakai untuk project baru:
-- 1. Buka Supabase Dashboard -> SQL Editor -> New Query.
-- 2. Jalankan seluruh file ini sekali.
-- 3. Di Authentication -> Users, buat akun Auth atau lakukan Sign Up dari web.
--    Jika email sama dengan seed di public.users, trigger akan menautkan auth_id.
-- 4. Pastikan index.html memakai SUPABASE_URL dan ANON KEY project yang benar.
--
-- Catatan penting:
-- - SQL ini TIDAK membuat password Auth karena password dikelola Supabase Auth.
-- - Akun awal di public.users disediakan agar role/status bisa langsung terlihat.
-- - Bucket storage "doc-pegawai" dibuat private; akses file memakai signed URL.
-- ============================================================================

BEGIN;

-- ============================================================================
-- 0. EXTENSION
-- Keterangan: pgcrypto menyediakan gen_random_uuid() untuk primary key UUID.
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. MASTER ENUM-LIKE CHECK LIST
-- Keterangan: daftar nilai valid dipakai konsisten pada CHECK constraint.
-- ============================================================================
-- Role akun yang dikenal aplikasi: admin, juri, verifikator, pegawai.
-- Tim/divisi yang dikenal aplikasi: Umum, Sosial, Produksi, Nerwilis, IPDS, Distribusi.

-- ============================================================================
-- 2. TABEL USERS
-- Keterangan:
-- - public.users adalah profil aplikasi yang terhubung ke auth.users.
-- - auth_id dapat NULL sebelum user membuat akun Auth.
-- - Sign Up dari website akan otomatis membuat profil pending melalui trigger.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.users (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_id    UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  email      TEXT NOT NULL UNIQUE,
  nama       TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'pegawai'
             CHECK (role IN ('admin','juri','verifikator','pegawai')),
  tim        TEXT NOT NULL DEFAULT 'Umum'
             CHECK (tim IN ('Umum','Sosial','Produksi','Nerwilis','IPDS','Distribusi')),
  status     TEXT NOT NULL DEFAULT 'pending'
             CHECK (status IN ('pending','aktif','nonaktif')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_auth_id ON public.users(auth_id);
CREATE INDEX IF NOT EXISTS idx_users_role_status ON public.users(role,status);
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON public.users(LOWER(email));

COMMENT ON TABLE public.users IS 'Profil akun aplikasi ORBIT yang terhubung ke Supabase Auth.';

-- ============================================================================
-- 3. TABEL PEGAWAI
-- Keterangan:
-- - Master pegawai BPS per tim.
-- - user_id opsional untuk menautkan pegawai dengan akun login role pegawai.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.pegawai (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID UNIQUE REFERENCES public.users(id) ON DELETE SET NULL,
  nama       TEXT NOT NULL,
  tim        TEXT NOT NULL
             CHECK (tim IN ('Umum','Sosial','Produksi','Nerwilis','IPDS','Distribusi')),
  status     TEXT NOT NULL DEFAULT 'aktif'
             CHECK (status IN ('aktif','nonaktif')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT pegawai_nama_tim_unique UNIQUE (nama,tim)
);

CREATE INDEX IF NOT EXISTS idx_pegawai_tim_status ON public.pegawai(tim,status);
CREATE INDEX IF NOT EXISTS idx_pegawai_user_id ON public.pegawai(user_id);

COMMENT ON TABLE public.pegawai IS 'Master data pegawai yang menjadi peserta penilaian ORBIT.';

-- ============================================================================
-- 4. TABEL JURI
-- Keterangan:
-- - Daftar juri aktif berasal dari public.users dengan role juri.
-- - Seed nama lama disimpan nonaktif agar tidak mengunci alur penilaian.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.juri (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID UNIQUE REFERENCES public.users(id) ON DELETE SET NULL,
  nama       TEXT NOT NULL,
  tim        TEXT NOT NULL DEFAULT 'Umum'
             CHECK (tim IN ('Umum','Sosial','Produksi','Nerwilis','IPDS','Distribusi')),
  status     TEXT NOT NULL DEFAULT 'nonaktif'
             CHECK (status IN ('aktif','nonaktif')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT juri_nama_unique UNIQUE (nama)
);

CREATE INDEX IF NOT EXISTS idx_juri_user_status ON public.juri(user_id,status);

COMMENT ON TABLE public.juri IS 'Daftar juri penilai yang tersinkron dari akun role Juri.';

-- ============================================================================
-- 5. TABEL NILAI_FINAL
-- Keterangan:
-- - Menyimpan nilai bulanan per pegawai.
-- - HTML memakai upsert berdasarkan pegawai_id + periode_bulan.
-- - total_nilai saat ini sama dengan nilai TPK/CKP; jumlah_kipapp disimpan
--   sebagai parameter pendukung.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.nilai_final (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pegawai_id     UUID NOT NULL REFERENCES public.pegawai(id) ON DELETE CASCADE,
  tim            TEXT,
  nilai          NUMERIC(6,2) NOT NULL CHECK (nilai BETWEEN 0 AND 100),
  jumlah_kipapp  INTEGER NOT NULL DEFAULT 0 CHECK (jumlah_kipapp >= 0),
  total_nilai    NUMERIC(6,2) NOT NULL CHECK (total_nilai BETWEEN 0 AND 100),
  periode_bulan  DATE NOT NULL,
  triwulan       INTEGER NOT NULL CHECK (triwulan BETWEEN 1 AND 4),
  tahun          INTEGER NOT NULL CHECK (tahun BETWEEN 2020 AND 2100),
  periode        TEXT,
  mode_rekam     TEXT NOT NULL DEFAULT 'operasional'
                 CHECK (mode_rekam IN ('operasional','arsip')),
  status         TEXT NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft','approved','rejected','arsip')),
  status_bulanan TEXT NOT NULL DEFAULT 'draft'
                 CHECK (status_bulanan IN ('draft','ditutup','arsip')),
  input_user_id  UUID REFERENCES public.users(id) ON DELETE SET NULL,
  updated_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT nilai_final_pegawai_periode_unique UNIQUE (pegawai_id, periode_bulan),
  CONSTRAINT nilai_final_awal_bulan CHECK (periode_bulan = DATE_TRUNC('month', periode_bulan)::DATE)
);

CREATE INDEX IF NOT EXISTS idx_nilai_final_periode ON public.nilai_final(tahun,triwulan,periode_bulan);
CREATE INDEX IF NOT EXISTS idx_nilai_final_pegawai ON public.nilai_final(pegawai_id);
CREATE INDEX IF NOT EXISTS idx_nilai_final_tim ON public.nilai_final(tim);

COMMENT ON TABLE public.nilai_final IS 'Nilai bulanan pegawai untuk dasar nominasi per tim dan triwulan.';

-- ============================================================================
-- 6. TABEL NOMINASI_FINAL
-- Keterangan:
-- - Menyimpan kandidat yang dipilih Admin dan dikirim ke Juri.
-- - status_alur: juri -> verifikasi -> selesai, atau dikembalikan.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.nominasi_final (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pegawai_id            UUID NOT NULL REFERENCES public.pegawai(id) ON DELETE CASCADE,
  tim                   TEXT,
  nilai_awal            NUMERIC(6,2),
  total_nilai           NUMERIC(6,2),
  periode_bulan         DATE,
  bulan_sumber          DATE,
  triwulan              INTEGER NOT NULL CHECK (triwulan BETWEEN 1 AND 4),
  tahun                 INTEGER NOT NULL CHECK (tahun BETWEEN 2020 AND 2100),
  status_alur           TEXT NOT NULL DEFAULT 'juri'
                         CHECK (status_alur IN ('juri','verifikasi','dikembalikan','selesai')),
  catatan_verifikator   TEXT,
  dikirim_verifikator_at TIMESTAMPTZ,
  approved_at           TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT nominasi_pegawai_periode_unique UNIQUE (pegawai_id,tahun,triwulan)
);

CREATE INDEX IF NOT EXISTS idx_nominasi_status ON public.nominasi_final(status_alur);
CREATE INDEX IF NOT EXISTS idx_nominasi_periode ON public.nominasi_final(tahun,triwulan);
CREATE INDEX IF NOT EXISTS idx_nominasi_pegawai ON public.nominasi_final(pegawai_id);

COMMENT ON TABLE public.nominasi_final IS 'Kandidat final yang masuk alur penilaian Juri dan Verifikator.';

-- ============================================================================
-- 7. TABEL PENILAIAN
-- Keterangan:
-- - Nilai yang diberikan juri untuk nominasi.
-- - juri_id disimpan TEXT agar kompatibel dengan kode lama dan nilai override.
-- - nominasi_id dipakai flow final agar penilaian aman per siklus.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.penilaian (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nominasi_id   UUID REFERENCES public.nominasi_final(id) ON DELETE CASCADE,
  pegawai_id    UUID NOT NULL REFERENCES public.pegawai(id) ON DELETE CASCADE,
  juri_id       TEXT NOT NULL,
  total_nilai   NUMERIC(6,2) NOT NULL CHECK (total_nilai BETWEEN 0 AND 100),
  catatan       TEXT,
  admin_user_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT penilaian_nominasi_juri_unique UNIQUE (nominasi_id,juri_id),
  CONSTRAINT penilaian_pegawai_juri_unique UNIQUE (pegawai_id,juri_id)
);

CREATE INDEX IF NOT EXISTS idx_penilaian_nominasi ON public.penilaian(nominasi_id);
CREATE INDEX IF NOT EXISTS idx_penilaian_pegawai ON public.penilaian(pegawai_id);
CREATE INDEX IF NOT EXISTS idx_penilaian_juri ON public.penilaian(juri_id);

COMMENT ON TABLE public.penilaian IS 'Nilai juri untuk setiap nominasi final.';

-- ============================================================================
-- 8. TABEL HISTORY_PENGHARGAAN
-- Keterangan: arsip pemenang akhir setelah ditetapkan Verifikator.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.history_penghargaan (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nominasi_id      UUID REFERENCES public.nominasi_final(id) ON DELETE SET NULL,
  pegawai_id       UUID REFERENCES public.pegawai(id) ON DELETE SET NULL,
  nama             TEXT NOT NULL,
  tim              TEXT,
  total_nilai      NUMERIC(6,2),
  triwulan         INTEGER CHECK (triwulan BETWEEN 1 AND 4),
  tahun            INTEGER CHECK (tahun BETWEEN 2020 AND 2100),
  periode_label    TEXT,
  ditetapkan_oleh  UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT history_periode_unique UNIQUE (tahun,triwulan)
);

CREATE INDEX IF NOT EXISTS idx_history_periode ON public.history_penghargaan(tahun,triwulan);

COMMENT ON TABLE public.history_penghargaan IS 'Arsip pemenang Pegawai Teladan per triwulan.';

-- ============================================================================
-- 9. TABEL NOTIFIKASI
-- Keterangan: pesan Admin kepada role tertentu atau semua akun aktif.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.notifikasi (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  judul       TEXT NOT NULL,
  pesan       TEXT NOT NULL,
  role_target TEXT NOT NULL DEFAULT 'semua'
              CHECK (role_target IN ('admin','juri','verifikator','pegawai','semua')),
  tipe        TEXT NOT NULL DEFAULT 'info'
              CHECK (tipe IN ('info','deadline','warning')),
  deadline    DATE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.notifikasi IS 'Notifikasi aplikasi ORBIT berdasarkan target role.';

-- ============================================================================
-- 10. TABEL UPLOAD DOKUMEN DAN SERTIFIKAT
-- Keterangan:
-- - excel_uploads dipakai untuk dokumen pendukung umum.
-- - sertifikat dipakai untuk metadata file sertifikat.
-- - kipapp dipertahankan sebagai tempat dokumen KIPAPP per pegawai.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.excel_uploads (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_name   TEXT NOT NULL,
  file_path   TEXT,
  file_url    TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.sertifikat (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pegawai_id  UUID NOT NULL REFERENCES public.pegawai(id) ON DELETE CASCADE,
  triwulan    INTEGER CHECK (triwulan BETWEEN 1 AND 4),
  tahun       INTEGER CHECK (tahun BETWEEN 2020 AND 2100),
  file_name   TEXT,
  file_path   TEXT,
  file_url    TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.kipapp (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pegawai_id  UUID NOT NULL REFERENCES public.pegawai(id) ON DELETE CASCADE,
  file_name   TEXT,
  file_path   TEXT,
  file_url    TEXT NOT NULL,
  uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.excel_uploads IS 'Metadata dokumen yang diunggah Admin.';
COMMENT ON TABLE public.sertifikat IS 'Metadata file sertifikat Pegawai Teladan.';
COMMENT ON TABLE public.kipapp IS 'Metadata dokumen KIPAPP per pegawai.';

-- ============================================================================
-- 11. TABEL PENDUKUNG PROSES DAN AUDIT
-- Keterangan:
-- - permintaan_koreksi menyimpan alasan Verifikator ketika mengembalikan proses.
-- - audit_log menyimpan jejak aksi penting.
-- - orbit_schema_migrations menandai versi schema yang sudah dipasang.
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.permintaan_koreksi (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipe        TEXT NOT NULL DEFAULT 'proses_verifikasi',
  tahun       INTEGER,
  triwulan    INTEGER,
  alasan      TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'menunggu'
              CHECK (status IN ('menunggu','selesai')),
  dibuat_oleh UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  selesai_at  TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  aksi        TEXT NOT NULL,
  entitas     TEXT,
  ref_id      UUID,
  detail      JSONB NOT NULL DEFAULT '{}'::JSONB,
  actor_id    UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.orbit_schema_migrations (
  version     TEXT PRIMARY KEY,
  description TEXT,
  applied_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 12. TRIGGER UPDATED_AT
-- Keterangan: setiap UPDATE otomatis memperbarui kolom updated_at.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_updated_at ON public.users;
CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_pegawai_updated_at ON public.pegawai;
CREATE TRIGGER trg_pegawai_updated_at
BEFORE UPDATE ON public.pegawai
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_juri_updated_at ON public.juri;
CREATE TRIGGER trg_juri_updated_at
BEFORE UPDATE ON public.juri
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_nilai_updated_at ON public.nilai_final;
CREATE TRIGGER trg_nilai_updated_at
BEFORE UPDATE ON public.nilai_final
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_nominasi_updated_at ON public.nominasi_final;
CREATE TRIGGER trg_nominasi_updated_at
BEFORE UPDATE ON public.nominasi_final
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS trg_penilaian_updated_at ON public.penilaian;
CREATE TRIGGER trg_penilaian_updated_at
BEFORE UPDATE ON public.penilaian
FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- ============================================================================
-- 13. HELPER WAKTU DAN PROFIL LOGIN
-- Keterangan: aplikasi menggunakan WITA / Asia-Makassar untuk kalender.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.orbit_wita_now()
RETURNS TIMESTAMP
LANGUAGE sql
STABLE
AS $$
  SELECT timezone('Asia/Makassar', NOW());
$$;

CREATE OR REPLACE FUNCTION public.orbit_wita_today()
RETURNS DATE
LANGUAGE sql
STABLE
AS $$
  SELECT public.orbit_wita_now()::DATE;
$$;

CREATE OR REPLACE FUNCTION public.current_profile_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.id
  FROM public.users u
  WHERE u.auth_id = auth.uid()
     OR LOWER(u.email) = LOWER(COALESCE(auth.jwt() ->> 'email',''))
  ORDER BY (u.auth_id = auth.uid()) DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_role()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT u.role
  FROM public.users u
  WHERE (u.auth_id = auth.uid()
     OR LOWER(u.email) = LOWER(COALESCE(auth.jwt() ->> 'email','')))
    AND u.status = 'aktif'
  ORDER BY (u.auth_id = auth.uid()) DESC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_juri_id()
RETURNS UUID
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT j.id
  FROM public.juri j
  JOIN public.users u ON u.id = j.user_id
  WHERE (u.auth_id = auth.uid()
     OR LOWER(u.email) = LOWER(COALESCE(auth.jwt() ->> 'email','')))
    AND u.role = 'juri'
    AND u.status = 'aktif'
    AND j.status = 'aktif'
  LIMIT 1;
$$;

-- ============================================================================
-- 14. AUDIT LOG
-- Keterangan: function kecil untuk mencatat aksi penting tanpa mengganggu flow.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.log_audit(p_aksi TEXT, p_entitas TEXT, p_ref UUID, p_detail JSONB DEFAULT '{}'::JSONB)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.audit_log(aksi,entitas,ref_id,detail,actor_id)
  VALUES(p_aksi,p_entitas,p_ref,COALESCE(p_detail,'{}'::JSONB),public.current_profile_id());
EXCEPTION WHEN OTHERS THEN
  -- Audit tidak boleh membuat transaksi utama gagal.
  NULL;
END;
$$;

-- ============================================================================
-- 15. TRIGGER SIGN UP AUTH -> PUBLIC.USERS
-- Keterangan:
-- - Setiap user baru di auth.users otomatis dibuat di public.users.
-- - Jika email sudah ada sebagai seed, auth_id ditautkan tanpa mengubah role/status.
-- - Akun baru non-seed masuk sebagai pegawai pending.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nama TEXT;
  v_tim TEXT;
  v_profile public.users%ROWTYPE;
BEGIN
  v_nama := COALESCE(NULLIF(TRIM(NEW.raw_user_meta_data ->> 'nama'),''), SPLIT_PART(NEW.email,'@',1));
  v_tim := CASE
    WHEN NEW.raw_user_meta_data ->> 'tim' IN ('Umum','Sosial','Produksi','Nerwilis','IPDS','Distribusi')
    THEN NEW.raw_user_meta_data ->> 'tim'
    ELSE 'Umum'
  END;

  SELECT * INTO v_profile
  FROM public.users
  WHERE LOWER(email) = LOWER(NEW.email)
  LIMIT 1;

  IF FOUND THEN
    UPDATE public.users
    SET auth_id = NEW.id,
        nama = COALESCE(NULLIF(nama,''), v_nama),
        tim = COALESCE(NULLIF(tim,''), v_tim),
        updated_at = NOW()
    WHERE id = v_profile.id;
  ELSE
    INSERT INTO public.users(auth_id,email,nama,role,tim,status)
    VALUES(NEW.id,LOWER(NEW.email),v_nama,'pegawai',v_tim,'pending');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_auth_user();

-- ============================================================================
-- 16. PROTEKSI AKUN DAN SINKRONISASI ROLE
-- Keterangan:
-- - Admin aktif terakhir tidak boleh dinonaktifkan.
-- - Role Juri aktif + auth_id tersedia otomatis menjadi Juri siap menilai.
-- - Role Pegawai aktif ditautkan ke master pegawai bila memungkinkan.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.protect_user_account_integrity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.role='admin' AND OLD.status='aktif'
       AND NOT EXISTS (SELECT 1 FROM public.users WHERE id<>OLD.id AND role='admin' AND status='aktif') THEN
      RAISE EXCEPTION 'Admin aktif terakhir tidak dapat dihapus.';
    END IF;
    RETURN OLD;
  END IF;

  IF OLD.role='admin' AND OLD.status='aktif'
     AND (NEW.role<>'admin' OR NEW.status<>'aktif')
     AND NOT EXISTS (SELECT 1 FROM public.users WHERE id<>OLD.id AND role='admin' AND status='aktif') THEN
    RAISE EXCEPTION 'Minimal harus tersedia satu Admin aktif.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_user_account ON public.users;
CREATE TRIGGER trg_protect_user_account
BEFORE UPDATE OR DELETE ON public.users
FOR EACH ROW EXECUTE FUNCTION public.protect_user_account_integrity();

CREATE OR REPLACE FUNCTION public.sync_user_role_to_personnel()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_target UUID;
  v_juri_status TEXT;
BEGIN
  -- Sinkronisasi Juri: hanya aktif jika akun Auth sudah tertaut.
  v_juri_status := CASE WHEN NEW.role='juri' AND NEW.status='aktif' AND NEW.auth_id IS NOT NULL THEN 'aktif' ELSE 'nonaktif' END;

  IF NEW.role='juri' THEN
    SELECT id INTO v_target
    FROM public.juri
    WHERE user_id = NEW.id OR LOWER(TRIM(nama)) = LOWER(TRIM(NEW.nama))
    ORDER BY (user_id = NEW.id) DESC, created_at ASC
    LIMIT 1;

    IF v_target IS NULL THEN
      INSERT INTO public.juri(user_id,nama,tim,status)
      VALUES(NEW.id,NEW.nama,NEW.tim,v_juri_status)
      ON CONFLICT (nama) DO UPDATE SET user_id=NEW.id,tim=NEW.tim,status=v_juri_status,updated_at=NOW();
    ELSE
      UPDATE public.juri
      SET user_id=NEW.id,nama=NEW.nama,tim=NEW.tim,status=v_juri_status,updated_at=NOW()
      WHERE id=v_target;
    END IF;
  ELSE
    UPDATE public.juri SET status='nonaktif',updated_at=NOW() WHERE user_id=NEW.id;
  END IF;

  -- Sinkronisasi Pegawai: akun pegawai aktif ditautkan ke master pegawai.
  IF NEW.role='pegawai' AND NEW.status='aktif' THEN
    SELECT id INTO v_target
    FROM public.pegawai
    WHERE user_id = NEW.id OR (user_id IS NULL AND LOWER(TRIM(nama)) = LOWER(TRIM(NEW.nama)))
    ORDER BY (user_id = NEW.id) DESC, (tim = NEW.tim) DESC, created_at ASC
    LIMIT 1;

    IF v_target IS NULL THEN
      INSERT INTO public.pegawai(user_id,nama,tim,status)
      VALUES(NEW.id,NEW.nama,NEW.tim,'aktif')
      ON CONFLICT (nama,tim) DO UPDATE SET user_id=NEW.id,status='aktif',updated_at=NOW();
    ELSE
      UPDATE public.pegawai
      SET user_id=NEW.id,nama=NEW.nama,tim=NEW.tim,status='aktif',updated_at=NOW()
      WHERE id=v_target;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_user_role_to_personnel ON public.users;
CREATE TRIGGER trg_sync_user_role_to_personnel
AFTER INSERT OR UPDATE OF auth_id,nama,tim,role,status
ON public.users
FOR EACH ROW EXECUTE FUNCTION public.sync_user_role_to_personnel();

-- ============================================================================
-- 17. RPC LOGIN DAN PROFIL
-- Keterangan:
-- - orbit_login_profile dipakai HTML setelah Supabase Auth login berhasil.
-- - orbit_update_my_profile dipakai halaman profil semua role.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.orbit_login_profile(p_email TEXT DEFAULT NULL)
RETURNS SETOF public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_email TEXT := LOWER(COALESCE(p_email, auth.jwt() ->> 'email'));
  v_user public.users%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Sesi login tidak valid.';
  END IF;

  SELECT * INTO v_user
  FROM public.users
  WHERE auth_id = v_uid OR LOWER(email) = v_email
  ORDER BY (auth_id = v_uid) DESC
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.users(auth_id,email,nama,role,tim,status)
    VALUES(v_uid,v_email,COALESCE(SPLIT_PART(v_email,'@',1),'Pengguna'),'pegawai','Umum','pending')
    RETURNING * INTO v_user;
  ELSIF v_user.auth_id IS NULL THEN
    UPDATE public.users
    SET auth_id = v_uid, updated_at = NOW()
    WHERE id = v_user.id
    RETURNING * INTO v_user;
  END IF;

  RETURN NEXT v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public.orbit_update_my_profile(p_nama TEXT, p_tim TEXT)
RETURNS SETOF public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile UUID := public.current_profile_id();
  v_user public.users%ROWTYPE;
BEGIN
  IF v_profile IS NULL OR public.current_role() IS NULL THEN
    RAISE EXCEPTION 'Akun aktif diperlukan.';
  END IF;
  IF NULLIF(TRIM(p_nama),'') IS NULL THEN
    RAISE EXCEPTION 'Nama wajib diisi.';
  END IF;
  IF p_tim NOT IN ('Umum','Sosial','Produksi','Nerwilis','IPDS','Distribusi') THEN
    RAISE EXCEPTION 'Tim tidak valid.';
  END IF;

  UPDATE public.users
  SET nama=TRIM(p_nama), tim=p_tim, updated_at=NOW()
  WHERE id=v_profile
  RETURNING * INTO v_user;

  RETURN NEXT v_user;
END;
$$;

CREATE OR REPLACE FUNCTION public.orbit_admin_upsert_user(p_email TEXT, p_nama TEXT, p_role TEXT, p_tim TEXT DEFAULT 'Umum', p_status TEXT DEFAULT 'pending')
RETURNS SETOF public.users
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user public.users%ROWTYPE;
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat mengelola pengguna.';
  END IF;

  INSERT INTO public.users(email,nama,role,tim,status)
  VALUES(LOWER(p_email),TRIM(p_nama),p_role,p_tim,p_status)
  ON CONFLICT (email) DO UPDATE SET
    nama=EXCLUDED.nama, role=EXCLUDED.role, tim=EXCLUDED.tim, status=EXCLUDED.status, updated_at=NOW()
  RETURNING * INTO v_user;

  RETURN NEXT v_user;
END;
$$;

-- ============================================================================
-- 18. RPC KALENDER, JURI, DAN NILAI BULANAN
-- Keterangan: dipakai Dashboard Admin, Input Nilai, dan monitoring Juri.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_daftar_juri_status()
RETURNS TABLE(user_id UUID,nama TEXT,email TEXT,tim TEXT,status_akun TEXT,status_juri TEXT,kesiapan TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat melihat status juri.';
  END IF;

  RETURN QUERY
  SELECT u.id,u.nama,u.email,u.tim,u.status,COALESCE(j.status,'belum_tersinkron') AS status_juri,
         CASE
           WHEN u.status <> 'aktif' THEN 'Menunggu Aktivasi'
           WHEN u.auth_id IS NULL THEN 'Belum Terhubung Login'
           WHEN j.id IS NULL OR j.status <> 'aktif' THEN 'Perlu Sinkronisasi'
           ELSE 'Siap Menilai'
         END AS kesiapan
  FROM public.users u
  LEFT JOIN public.juri j ON j.user_id = u.id
  WHERE u.role='juri'
  ORDER BY u.nama;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_kalender_operasional()
RETURNS TABLE(
  sekarang_wita TIMESTAMP,
  tahun_monitoring INTEGER,
  triwulan_monitoring INTEGER,
  bulan_berjalan DATE,
  bulan_ditutup_monitoring INTEGER,
  tahun_seleksi INTEGER,
  triwulan_seleksi INTEGER,
  siap_finalisasi BOOLEAN,
  status_proses TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_now TIMESTAMP := public.orbit_wita_now();
  v_current_q DATE := DATE_TRUNC('quarter', v_now)::DATE;
  v_previous_q DATE := (DATE_TRUNC('quarter', v_now) - INTERVAL '3 months')::DATE;
  v_selected_q DATE := v_current_q;
  v_current_ready BOOLEAN := FALSE;
  v_previous_ready BOOLEAN := FALSE;
  v_current_months INTEGER := 0;
BEGIN
  IF public.current_role() IS NULL THEN
    RAISE EXCEPTION 'Akun aktif diperlukan.';
  END IF;

  SELECT COUNT(DISTINCT nf.periode_bulan) INTO v_current_months
  FROM public.nilai_final nf
  WHERE nf.tahun = EXTRACT(YEAR FROM v_current_q)::INT
    AND nf.triwulan = EXTRACT(QUARTER FROM v_current_q)::INT
    AND nf.mode_rekam = 'operasional';

  SELECT COALESCE(COUNT(DISTINCT nf.periode_bulan),0) >= 3 INTO v_previous_ready
  FROM public.nilai_final nf
  WHERE nf.tahun = EXTRACT(YEAR FROM v_previous_q)::INT
    AND nf.triwulan = EXTRACT(QUARTER FROM v_previous_q)::INT
    AND nf.mode_rekam = 'operasional'
    AND NOT EXISTS (
      SELECT 1 FROM public.history_penghargaan h
      WHERE h.tahun = EXTRACT(YEAR FROM v_previous_q)::INT
        AND h.triwulan = EXTRACT(QUARTER FROM v_previous_q)::INT
    );

  SELECT COALESCE(COUNT(DISTINCT nf.periode_bulan),0) >= 3 INTO v_current_ready
  FROM public.nilai_final nf
  WHERE nf.tahun = EXTRACT(YEAR FROM v_current_q)::INT
    AND nf.triwulan = EXTRACT(QUARTER FROM v_current_q)::INT
    AND nf.mode_rekam = 'operasional';

  IF v_previous_ready THEN
    v_selected_q := v_previous_q;
  ELSE
    v_selected_q := v_current_q;
  END IF;

  RETURN QUERY SELECT
    v_now,
    EXTRACT(YEAR FROM v_current_q)::INT,
    EXTRACT(QUARTER FROM v_current_q)::INT,
    DATE_TRUNC('month', v_now)::DATE,
    v_current_months,
    EXTRACT(YEAR FROM v_selected_q)::INT,
    EXTRACT(QUARTER FROM v_selected_q)::INT,
    CASE WHEN v_selected_q = v_previous_q THEN v_previous_ready ELSE v_current_ready END,
    CASE
      WHEN EXISTS(SELECT 1 FROM public.nominasi_final WHERE status_alur IN ('juri','verifikasi','dikembalikan')) THEN 'proses_aktif'
      WHEN (CASE WHEN v_selected_q = v_previous_q THEN v_previous_ready ELSE v_current_ready END) THEN 'siap_finalisasi'
      ELSE 'monitoring'
    END;
END;
$$;

CREATE OR REPLACE FUNCTION public.simpan_nilai_bulanan_realtime(p_pegawai_id UUID, p_nilai NUMERIC, p_jumlah_kipapp INTEGER, p_periode_bulan DATE)
RETURNS TABLE(mode_rekam TEXT,status_bulanan TEXT,pesan TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pg public.pegawai%ROWTYPE;
  v_month DATE := DATE_TRUNC('month', p_periode_bulan::TIMESTAMP)::DATE;
  v_year INTEGER := EXTRACT(YEAR FROM p_periode_bulan)::INT;
  v_quarter INTEGER := EXTRACT(QUARTER FROM p_periode_bulan)::INT;
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat menginput nilai.';
  END IF;
  IF p_periode_bulan <> v_month THEN
    RAISE EXCEPTION 'Periode bulan harus tanggal pertama bulan tersebut.';
  END IF;
  IF p_nilai < 0 OR p_nilai > 100 OR COALESCE(p_jumlah_kipapp,0) < 0 THEN
    RAISE EXCEPTION 'Nilai harus 0 sampai 100 dan KIPAPP tidak boleh negatif.';
  END IF;

  SELECT * INTO v_pg FROM public.pegawai WHERE id=p_pegawai_id AND status='aktif';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pegawai tidak ditemukan atau nonaktif.';
  END IF;

  INSERT INTO public.nilai_final(pegawai_id,tim,nilai,jumlah_kipapp,total_nilai,periode_bulan,triwulan,tahun,periode,mode_rekam,status,status_bulanan,input_user_id,updated_user_id)
  VALUES(p_pegawai_id,v_pg.tim,p_nilai,COALESCE(p_jumlah_kipapp,0),p_nilai,v_month,v_quarter,v_year,'Triwulan '||v_quarter,'operasional','draft','draft',public.current_profile_id(),public.current_profile_id())
  ON CONFLICT (pegawai_id,periode_bulan) DO UPDATE SET
    tim=EXCLUDED.tim,
    nilai=EXCLUDED.nilai,
    jumlah_kipapp=EXCLUDED.jumlah_kipapp,
    total_nilai=EXCLUDED.total_nilai,
    triwulan=EXCLUDED.triwulan,
    tahun=EXCLUDED.tahun,
    periode=EXCLUDED.periode,
    mode_rekam='operasional',
    status='draft',
    status_bulanan='draft',
    updated_user_id=public.current_profile_id(),
    updated_at=NOW();

  PERFORM public.log_audit('SIMPAN_NILAI_BULANAN','nilai_final',p_pegawai_id,JSONB_BUILD_OBJECT('periode_bulan',v_month,'nilai',p_nilai));
  RETURN QUERY SELECT 'operasional'::TEXT,'draft'::TEXT,'Nilai berhasil disimpan.'::TEXT;
END;
$$;

-- Fallback RPC untuk kode lama di HTML final.
CREATE OR REPLACE FUNCTION public.orbit_simpan_nilai_final(p_pegawai_id UUID, p_nilai NUMERIC, p_jumlah_kipapp INTEGER, p_periode_bulan DATE, p_triwulan INTEGER DEFAULT NULL, p_tahun INTEGER DEFAULT NULL, p_tim TEXT DEFAULT NULL)
RETURNS TABLE(id UUID)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result RECORD;
BEGIN
  PERFORM public.simpan_nilai_bulanan_realtime(p_pegawai_id,p_nilai,p_jumlah_kipapp,p_periode_bulan);
  SELECT nf.id INTO v_result
  FROM public.nilai_final nf
  WHERE nf.pegawai_id=p_pegawai_id AND nf.periode_bulan=DATE_TRUNC('month',p_periode_bulan::TIMESTAMP)::DATE;
  RETURN QUERY SELECT v_result.id::UUID;
END;
$$;

-- ============================================================================
-- 19. RPC NOMINASI BULANAN DAN TRIWULAN
-- Keterangan:
-- - get_nominasi_bulanan_per_tim: menampilkan pemenang bulanan tiap tim.
-- - get_kandidat_nominasi_triwulan: kompatibilitas versi lama, hanya kandidat top.
-- - kirim_nominasi_ke_juri: final fleksibel; minimal 1 kandidat, maksimal 1 per tim.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_nominasi_bulanan_per_tim(p_tahun INTEGER, p_triwulan INTEGER)
RETURNS TABLE(
  tim TEXT,
  bulan_sumber DATE,
  pegawai_id UUID,
  nama TEXT,
  nilai_bulanan NUMERIC,
  nilai_tertinggi_triwulan NUMERIC,
  kandidat_tertinggi BOOLEAN,
  seri_tertinggi BOOLEAN,
  bulan_tersedia BIGINT,
  lengkap_tiga_bulan BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat melihat nominasi per tim.';
  END IF;

  RETURN QUERY
  WITH nilai_valid AS (
    SELECT nf.pegawai_id, pg.nama, pg.tim, nf.total_nilai, nf.periode_bulan
    FROM public.nilai_final nf
    JOIN public.pegawai pg ON pg.id = nf.pegawai_id
    WHERE pg.status='aktif'
      AND nf.mode_rekam='operasional'
      AND nf.tahun=p_tahun
      AND nf.triwulan=p_triwulan
  ), urutan AS (
    SELECT nv.*, RANK() OVER(PARTITION BY nv.tim,nv.periode_bulan ORDER BY nv.total_nilai DESC, nv.nama ASC) AS rk
    FROM nilai_valid nv
  ), pemenang_bulanan AS (
    SELECT * FROM urutan WHERE rk=1
  ), maks AS (
    SELECT pb.tim, MAX(pb.total_nilai) AS nilai_maksimum
    FROM pemenang_bulanan pb
    GROUP BY pb.tim
  ), status_tim AS (
    SELECT pg.tim, COUNT(DISTINCT nf.periode_bulan)::BIGINT AS bulan_tersedia
    FROM public.pegawai pg
    LEFT JOIN public.nilai_final nf ON nf.pegawai_id=pg.id AND nf.tahun=p_tahun AND nf.triwulan=p_triwulan AND nf.mode_rekam='operasional'
    WHERE pg.status='aktif'
    GROUP BY pg.tim
  ), seri AS (
    SELECT pb.tim, COUNT(*)::BIGINT AS jumlah_seri
    FROM pemenang_bulanan pb
    JOIN maks m ON m.tim=pb.tim AND m.nilai_maksimum=pb.total_nilai
    GROUP BY pb.tim
  )
  SELECT pb.tim,pb.periode_bulan,pb.pegawai_id,pb.nama,pb.total_nilai,
         m.nilai_maksimum,
         (pb.total_nilai=m.nilai_maksimum) AS kandidat_tertinggi,
         COALESCE(s.jumlah_seri,0) > 1 AS seri_tertinggi,
         COALESCE(st.bulan_tersedia,0),
         COALESCE(st.bulan_tersedia,0) >= 3
  FROM pemenang_bulanan pb
  JOIN maks m ON m.tim=pb.tim
  LEFT JOIN status_tim st ON st.tim=pb.tim
  LEFT JOIN seri s ON s.tim=pb.tim
  ORDER BY CASE pb.tim WHEN 'Umum' THEN 1 WHEN 'Sosial' THEN 2 WHEN 'Produksi' THEN 3 WHEN 'Nerwilis' THEN 4 WHEN 'IPDS' THEN 5 WHEN 'Distribusi' THEN 6 ELSE 99 END,
           pb.periode_bulan,
           pb.total_nilai DESC,
           pb.nama;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_kandidat_nominasi_triwulan(p_tahun INTEGER, p_triwulan INTEGER)
RETURNS TABLE(
  pegawai_id UUID,
  nama TEXT,
  tim TEXT,
  nilai_tertinggi NUMERIC,
  bulan_sumber DATE,
  bulan_ditutup BIGINT,
  jumlah_nilai_masuk BIGINT,
  jumlah_nilai_wajib BIGINT,
  siap_finalisasi BOOLEAN,
  berstatus_tie BOOLEAN
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat melihat kandidat.';
  END IF;

  RETURN QUERY
  WITH bulanan AS (
    SELECT * FROM public.get_nominasi_bulanan_per_tim(p_tahun,p_triwulan)
  ), aktif_tim AS (
    SELECT pg.tim, COUNT(*)::BIGINT AS jumlah_pegawai
    FROM public.pegawai pg WHERE pg.status='aktif' GROUP BY pg.tim
  ), masuk AS (
    SELECT pg.tim, COUNT(nf.id)::BIGINT AS jumlah_nilai
    FROM public.pegawai pg
    LEFT JOIN public.nilai_final nf ON nf.pegawai_id=pg.id AND nf.tahun=p_tahun AND nf.triwulan=p_triwulan AND nf.mode_rekam='operasional'
    WHERE pg.status='aktif'
    GROUP BY pg.tim
  )
  SELECT b.pegawai_id,b.nama,b.tim,b.nilai_bulanan,b.bulan_sumber,
         b.bulan_tersedia,
         COALESCE(m.jumlah_nilai,0),
         COALESCE(a.jumlah_pegawai,0) * 3,
         b.lengkap_tiga_bulan,
         b.seri_tertinggi
  FROM bulanan b
  LEFT JOIN aktif_tim a ON a.tim=b.tim
  LEFT JOIN masuk m ON m.tim=b.tim
  WHERE b.kandidat_tertinggi=TRUE
  ORDER BY CASE b.tim WHEN 'Umum' THEN 1 WHEN 'Sosial' THEN 2 WHEN 'Produksi' THEN 3 WHEN 'Nerwilis' THEN 4 WHEN 'IPDS' THEN 5 WHEN 'Distribusi' THEN 6 ELSE 99 END,
           b.nama;
END;
$$;

CREATE OR REPLACE FUNCTION public.kirim_nominasi_ke_juri(p_tahun INTEGER, p_triwulan INTEGER, p_pegawai_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
  v_row RECORD;
  v_tim_dipilih TEXT[] := ARRAY[]::TEXT[];
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat mengirim nominasi.';
  END IF;
  IF p_triwulan NOT BETWEEN 1 AND 4 OR p_tahun NOT BETWEEN 2020 AND 2100 THEN
    RAISE EXCEPTION 'Tahun atau triwulan tidak valid.';
  END IF;
  IF COALESCE(ARRAY_LENGTH(p_pegawai_ids,1),0) = 0 THEN
    RAISE EXCEPTION 'Pilih minimal satu kandidat terlebih dahulu.';
  END IF;
  IF EXISTS(SELECT 1 FROM public.nominasi_final WHERE status_alur IN ('juri','verifikasi','dikembalikan')) THEN
    RAISE EXCEPTION 'Masih ada proses nominasi aktif. Selesaikan atau reset proses terlebih dahulu.';
  END IF;
  IF EXISTS(SELECT 1 FROM public.history_penghargaan WHERE tahun=p_tahun AND triwulan=p_triwulan) THEN
    RAISE EXCEPTION 'Pemenang periode ini sudah ditetapkan.';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.juri j JOIN public.users u ON u.id=j.user_id WHERE j.status='aktif' AND u.role='juri' AND u.status='aktif' AND u.auth_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Belum ada akun Juri yang siap menilai. Aktifkan user role Juri terlebih dahulu.';
  END IF;

  FOREACH v_id IN ARRAY p_pegawai_ids LOOP
    SELECT * INTO v_row
    FROM public.get_nominasi_bulanan_per_tim(p_tahun,p_triwulan) nb
    WHERE nb.pegawai_id = v_id
    ORDER BY nb.kandidat_tertinggi DESC, nb.nilai_bulanan DESC
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Kandidat yang dipilih tidak tersedia pada periode ini.';
    END IF;
    IF v_row.tim = ANY(v_tim_dipilih) THEN
      RAISE EXCEPTION 'Setiap tim hanya boleh memiliki satu kandidat final.';
    END IF;

    v_tim_dipilih := ARRAY_APPEND(v_tim_dipilih, v_row.tim);

    INSERT INTO public.nominasi_final(pegawai_id,tim,nilai_awal,total_nilai,periode_bulan,bulan_sumber,triwulan,tahun,status_alur)
    VALUES(v_row.pegawai_id,v_row.tim,v_row.nilai_bulanan,NULL,v_row.bulan_sumber,v_row.bulan_sumber,p_triwulan,p_tahun,'juri');
  END LOOP;

  PERFORM public.log_audit('KIRIM_NOMINASI_KE_JURI','nominasi_final',NULL,JSONB_BUILD_OBJECT('tahun',p_tahun,'triwulan',p_triwulan,'jumlah',ARRAY_LENGTH(p_pegawai_ids,1)));
END;
$$;

-- Overload lama: kirim berdasarkan satu bulan sumber.
CREATE OR REPLACE FUNCTION public.kirim_nominasi_ke_juri(p_periode_bulan DATE, p_pegawai_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.kirim_nominasi_ke_juri(EXTRACT(YEAR FROM p_periode_bulan)::INT, EXTRACT(QUARTER FROM p_periode_bulan)::INT, p_pegawai_ids);
END;
$$;

CREATE OR REPLACE FUNCTION public.kirim_nominasi_ke_juri(p_periode_bulan TEXT, p_pegawai_ids UUID[])
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.kirim_nominasi_ke_juri(p_periode_bulan::DATE, p_pegawai_ids);
END;
$$;

-- ============================================================================
-- 20. RPC JURI, RANKING, VERIFIKATOR
-- Keterangan: alur penilaian kandidat sampai penetapan pemenang.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.simpan_penilaian_juri(p_nominasi_id UUID, p_nilai NUMERIC, p_catatan TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_juri UUID := public.current_juri_id();
  v_pegawai UUID;
BEGIN
  IF v_juri IS NULL THEN
    RAISE EXCEPTION 'Akun Juri belum siap menilai. Hubungi Admin.';
  END IF;
  IF p_nilai < 0 OR p_nilai > 100 THEN
    RAISE EXCEPTION 'Nilai harus 0 sampai 100.';
  END IF;

  SELECT pegawai_id INTO v_pegawai
  FROM public.nominasi_final
  WHERE id=p_nominasi_id AND status_alur='juri';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Nominasi tidak tersedia untuk penilaian.';
  END IF;

  INSERT INTO public.penilaian(nominasi_id,pegawai_id,juri_id,total_nilai,catatan)
  VALUES(p_nominasi_id,v_pegawai,v_juri::TEXT,p_nilai,p_catatan)
  ON CONFLICT (nominasi_id,juri_id) DO UPDATE SET
    total_nilai=EXCLUDED.total_nilai,
    catatan=EXCLUDED.catatan,
    updated_at=NOW();

  PERFORM public.log_audit('SIMPAN_PENILAIAN_JURI','penilaian',p_nominasi_id,JSONB_BUILD_OBJECT('juri_id',v_juri));
END;
$$;

CREATE OR REPLACE FUNCTION public.hapus_penilaian_juri(p_nominasi_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_juri UUID := public.current_juri_id();
BEGIN
  IF v_juri IS NULL THEN
    RAISE EXCEPTION 'Akun Juri belum siap menilai.';
  END IF;

  DELETE FROM public.penilaian
  WHERE nominasi_id=p_nominasi_id AND juri_id=v_juri::TEXT;

  PERFORM public.log_audit('HAPUS_PENILAIAN_JURI','penilaian',p_nominasi_id,JSONB_BUILD_OBJECT('juri_id',v_juri));
END;
$$;

CREATE OR REPLACE FUNCTION public.get_ranking_live()
RETURNS TABLE(
  nominasi_id UUID,
  pegawai_id UUID,
  nama TEXT,
  tim TEXT,
  nilai NUMERIC,
  jumlah_penilai BIGINT,
  jumlah_juri BIGINT,
  lengkap BOOLEAN,
  is_override BOOLEAN,
  status_alur TEXT
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_juri BIGINT;
BEGIN
  IF public.current_role() NOT IN ('admin','juri','verifikator') THEN
    RAISE EXCEPTION 'Akses ranking tidak diizinkan.';
  END IF;

  SELECT COUNT(*) INTO v_total_juri
  FROM public.juri j
  JOIN public.users u ON u.id=j.user_id
  WHERE j.status='aktif' AND u.role='juri' AND u.status='aktif' AND u.auth_id IS NOT NULL;

  RETURN QUERY
  SELECT n.id,n.pegawai_id,p.nama,p.tim,
         COALESCE(AVG(pe.total_nilai),0)::NUMERIC AS nilai,
         COUNT(pe.id)::BIGINT AS jumlah_penilai,
         v_total_juri AS jumlah_juri,
         (COUNT(pe.id)=v_total_juri AND v_total_juri>0) AS lengkap,
         FALSE AS is_override,
         n.status_alur
  FROM public.nominasi_final n
  JOIN public.pegawai p ON p.id=n.pegawai_id
  LEFT JOIN public.penilaian pe ON pe.nominasi_id=n.id
  WHERE n.status_alur IN ('juri','verifikasi')
  GROUP BY n.id,n.pegawai_id,p.nama,p.tim,n.status_alur
  ORDER BY COALESCE(AVG(pe.total_nilai),0) DESC, p.nama;
END;
$$;

CREATE OR REPLACE FUNCTION public.kirim_ranking_ke_verifikator()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_juri BIGINT;
  v_nom BIGINT;
  v_lengkap BIGINT;
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat mengirim ranking ke Verifikator.';
  END IF;

  SELECT COUNT(*) INTO v_juri
  FROM public.juri j JOIN public.users u ON u.id=j.user_id
  WHERE j.status='aktif' AND u.role='juri' AND u.status='aktif' AND u.auth_id IS NOT NULL;

  SELECT COUNT(*) INTO v_nom FROM public.nominasi_final WHERE status_alur='juri';

  IF v_nom=0 OR v_juri=0 THEN
    RAISE EXCEPTION 'Belum ada nominasi atau Juri aktif.';
  END IF;

  SELECT COUNT(*) INTO v_lengkap FROM public.get_ranking_live() WHERE lengkap=TRUE AND status_alur='juri';
  IF v_lengkap <> v_nom THEN
    RAISE EXCEPTION 'Seluruh Juri aktif wajib menyelesaikan penilaian seluruh kandidat.';
  END IF;

  UPDATE public.nominasi_final n
  SET total_nilai = (
        SELECT AVG(pe.total_nilai)::NUMERIC
        FROM public.penilaian pe
        WHERE pe.nominasi_id=n.id
      ),
      status_alur='verifikasi',
      dikirim_verifikator_at=NOW(),
      updated_at=NOW()
  WHERE n.status_alur='juri';

  PERFORM public.log_audit('KIRIM_RANKING_KE_VERIFIKATOR','nominasi_final',NULL,'{}'::JSONB);
END;
$$;

CREATE OR REPLACE FUNCTION public.tetapkan_pemenang(p_nominasi_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nom public.nominasi_final%ROWTYPE;
  v_pg public.pegawai%ROWTYPE;
BEGIN
  IF public.current_role() <> 'verifikator' THEN
    RAISE EXCEPTION 'Hanya Verifikator yang dapat menetapkan pemenang.';
  END IF;

  SELECT * INTO v_nom FROM public.nominasi_final WHERE id=p_nominasi_id AND status_alur='verifikasi';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Nominasi belum siap ditetapkan.';
  END IF;

  IF EXISTS(SELECT 1 FROM public.history_penghargaan WHERE tahun=v_nom.tahun AND triwulan=v_nom.triwulan) THEN
    RAISE EXCEPTION 'Pemenang untuk periode ini sudah ditetapkan.';
  END IF;

  SELECT * INTO v_pg FROM public.pegawai WHERE id=v_nom.pegawai_id;

  INSERT INTO public.history_penghargaan(nominasi_id,pegawai_id,nama,tim,total_nilai,triwulan,tahun,periode_label,ditetapkan_oleh)
  VALUES(v_nom.id,v_nom.pegawai_id,v_pg.nama,v_pg.tim,v_nom.total_nilai,v_nom.triwulan,v_nom.tahun,'Triwulan '||v_nom.triwulan||' Tahun '||v_nom.tahun,public.current_profile_id());

  UPDATE public.nilai_final
  SET status = CASE WHEN pegawai_id=v_nom.pegawai_id THEN 'approved' ELSE status END,
      updated_at=NOW()
  WHERE tahun=v_nom.tahun AND triwulan=v_nom.triwulan;

  UPDATE public.nominasi_final
  SET status_alur='selesai', approved_at=NOW(), updated_at=NOW()
  WHERE tahun=v_nom.tahun AND triwulan=v_nom.triwulan;

  PERFORM public.log_audit('TETAPKAN_PEMENANG','history_penghargaan',p_nominasi_id,JSONB_BUILD_OBJECT('pegawai_id',v_nom.pegawai_id,'tahun',v_nom.tahun,'triwulan',v_nom.triwulan));
END;
$$;

CREATE OR REPLACE FUNCTION public.kembalikan_ke_admin(p_alasan TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tahun INTEGER;
  v_triwulan INTEGER;
BEGIN
  IF public.current_role() <> 'verifikator' THEN
    RAISE EXCEPTION 'Hanya Verifikator yang dapat mengembalikan proses.';
  END IF;
  IF NULLIF(TRIM(p_alasan),'') IS NULL THEN
    RAISE EXCEPTION 'Alasan pengembalian wajib diisi.';
  END IF;

  SELECT tahun,triwulan INTO v_tahun,v_triwulan
  FROM public.nominasi_final
  WHERE status_alur='verifikasi'
  LIMIT 1;

  IF v_tahun IS NULL THEN
    RAISE EXCEPTION 'Tidak ada proses verifikasi aktif.';
  END IF;

  UPDATE public.nominasi_final
  SET status_alur='dikembalikan', catatan_verifikator=p_alasan, updated_at=NOW()
  WHERE tahun=v_tahun AND triwulan=v_triwulan AND status_alur='verifikasi';

  INSERT INTO public.permintaan_koreksi(tipe,tahun,triwulan,alasan,status,dibuat_oleh)
  VALUES('proses_verifikasi',v_tahun,v_triwulan,p_alasan,'menunggu',public.current_profile_id());

  PERFORM public.log_audit('KEMBALIKAN_KE_ADMIN','nominasi_final',NULL,JSONB_BUILD_OBJECT('alasan',p_alasan,'tahun',v_tahun,'triwulan',v_triwulan));
END;
$$;

CREATE OR REPLACE FUNCTION public.buka_kembali_setelah_koreksi()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tahun INTEGER;
  v_triwulan INTEGER;
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat membuka koreksi.';
  END IF;

  SELECT tahun,triwulan INTO v_tahun,v_triwulan
  FROM public.nominasi_final
  WHERE status_alur='dikembalikan'
  LIMIT 1;

  IF v_tahun IS NULL THEN
    RAISE EXCEPTION 'Tidak ada proses yang sedang dikembalikan.';
  END IF;

  DELETE FROM public.penilaian
  WHERE nominasi_id IN (SELECT id FROM public.nominasi_final WHERE tahun=v_tahun AND triwulan=v_triwulan);

  DELETE FROM public.nominasi_final
  WHERE tahun=v_tahun AND triwulan=v_triwulan AND status_alur='dikembalikan';

  UPDATE public.permintaan_koreksi
  SET status='selesai', selesai_at=NOW()
  WHERE tahun=v_tahun AND triwulan=v_triwulan AND status='menunggu';

  PERFORM public.log_audit('BUKA_KEMBALI_SETELAH_KOREKSI','nominasi_final',NULL,JSONB_BUILD_OBJECT('tahun',v_tahun,'triwulan',v_triwulan));
END;
$$;

CREATE OR REPLACE FUNCTION public.reset_penilaian_baru()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat membuat siklus baru.';
  END IF;

  DELETE FROM public.penilaian WHERE id IS NOT NULL;
  DELETE FROM public.nominasi_final WHERE id IS NOT NULL;
  UPDATE public.permintaan_koreksi SET status='selesai', selesai_at=NOW() WHERE status='menunggu';

  PERFORM public.log_audit('RESET_PENILAIAN_BARU','nominasi_final',NULL,'{}'::JSONB);
END;
$$;

-- RPC lama yang tidak ditampilkan UI final, tetap disediakan agar script lama tidak error.
CREATE OR REPLACE FUNCTION public.simpan_override_nilai(p_pegawai_id UUID, p_nilai NUMERIC, p_alasan TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nom UUID;
BEGIN
  IF public.current_role() <> 'admin' THEN
    RAISE EXCEPTION 'Hanya Admin yang dapat membuat override.';
  END IF;
  IF p_nilai < 0 OR p_nilai > 100 OR LENGTH(TRIM(COALESCE(p_alasan,''))) < 5 THEN
    RAISE EXCEPTION 'Nilai atau alasan override tidak valid.';
  END IF;

  SELECT id INTO v_nom FROM public.nominasi_final WHERE pegawai_id=p_pegawai_id AND status_alur='juri' LIMIT 1;
  IF v_nom IS NULL THEN
    RAISE EXCEPTION 'Override hanya untuk nominasi pada tahap Juri.';
  END IF;

  INSERT INTO public.penilaian(nominasi_id,pegawai_id,juri_id,total_nilai,catatan,admin_user_id)
  VALUES(v_nom,p_pegawai_id,'override',p_nilai,p_alasan,public.current_profile_id())
  ON CONFLICT (nominasi_id,juri_id) DO UPDATE SET total_nilai=EXCLUDED.total_nilai,catatan=EXCLUDED.catatan,admin_user_id=EXCLUDED.admin_user_id,updated_at=NOW();
END;
$$;

-- ============================================================================
-- 21. ROW LEVEL SECURITY
-- Keterangan:
-- - RLS aktif di semua tabel public.
-- - Operasi kritis lebih aman lewat RPC SECURITY DEFINER.
-- - Admin mengelola data; Juri mengelola nilai miliknya; Verifikator membaca dan menetapkan pemenang lewat RPC.
-- ============================================================================
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pegawai ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.juri ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nilai_final ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nominasi_final ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.penilaian ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.history_penghargaan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifikasi ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.excel_uploads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sertifikat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.kipapp ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permintaan_koreksi ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orbit_schema_migrations ENABLE ROW LEVEL SECURITY;

-- Hapus policy lama agar file ini aman dijalankan ulang.
DROP POLICY IF EXISTS users_read ON public.users;
DROP POLICY IF EXISTS users_admin_write ON public.users;
DROP POLICY IF EXISTS pegawai_read ON public.pegawai;
DROP POLICY IF EXISTS pegawai_admin_write ON public.pegawai;
DROP POLICY IF EXISTS juri_read ON public.juri;
DROP POLICY IF EXISTS juri_admin_write ON public.juri;
DROP POLICY IF EXISTS nilai_read ON public.nilai_final;
DROP POLICY IF EXISTS nilai_admin_write ON public.nilai_final;
DROP POLICY IF EXISTS nominasi_read ON public.nominasi_final;
DROP POLICY IF EXISTS nominasi_admin_write ON public.nominasi_final;
DROP POLICY IF EXISTS penilaian_read ON public.penilaian;
DROP POLICY IF EXISTS penilaian_admin_write ON public.penilaian;
DROP POLICY IF EXISTS penilaian_juri_write ON public.penilaian;
DROP POLICY IF EXISTS history_read ON public.history_penghargaan;
DROP POLICY IF EXISTS history_verif_write ON public.history_penghargaan;
DROP POLICY IF EXISTS notifikasi_read ON public.notifikasi;
DROP POLICY IF EXISTS notifikasi_admin_write ON public.notifikasi;
DROP POLICY IF EXISTS upload_read ON public.excel_uploads;
DROP POLICY IF EXISTS upload_admin_write ON public.excel_uploads;
DROP POLICY IF EXISTS sertifikat_read ON public.sertifikat;
DROP POLICY IF EXISTS sertifikat_admin_write ON public.sertifikat;
DROP POLICY IF EXISTS kipapp_read ON public.kipapp;
DROP POLICY IF EXISTS kipapp_admin_write ON public.kipapp;
DROP POLICY IF EXISTS koreksi_read ON public.permintaan_koreksi;
DROP POLICY IF EXISTS koreksi_write ON public.permintaan_koreksi;
DROP POLICY IF EXISTS audit_admin_read ON public.audit_log;
DROP POLICY IF EXISTS migrations_admin_read ON public.orbit_schema_migrations;

CREATE POLICY users_read ON public.users
FOR SELECT TO authenticated
USING (id=public.current_profile_id() OR public.current_role()='admin');

CREATE POLICY users_admin_write ON public.users
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY pegawai_read ON public.pegawai
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','juri','verifikator') OR user_id=public.current_profile_id());

CREATE POLICY pegawai_admin_write ON public.pegawai
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY juri_read ON public.juri
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','juri','verifikator'));

CREATE POLICY juri_admin_write ON public.juri
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY nilai_read ON public.nilai_final
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','juri','verifikator'));

CREATE POLICY nilai_admin_write ON public.nilai_final
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY nominasi_read ON public.nominasi_final
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','juri','verifikator'));

CREATE POLICY nominasi_admin_write ON public.nominasi_final
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY penilaian_read ON public.penilaian
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','juri','verifikator'));

CREATE POLICY penilaian_admin_write ON public.penilaian
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY penilaian_juri_write ON public.penilaian
FOR ALL TO authenticated
USING (public.current_role()='juri' AND juri_id=public.current_juri_id()::TEXT)
WITH CHECK (public.current_role()='juri' AND juri_id=public.current_juri_id()::TEXT);

CREATE POLICY history_read ON public.history_penghargaan
FOR SELECT TO authenticated
USING (public.current_role() IS NOT NULL);

CREATE POLICY history_verif_write ON public.history_penghargaan
FOR ALL TO authenticated
USING (public.current_role() IN ('admin','verifikator'))
WITH CHECK (public.current_role() IN ('admin','verifikator'));

CREATE POLICY notifikasi_read ON public.notifikasi
FOR SELECT TO authenticated
USING (public.current_role()='admin' OR role_target='semua' OR role_target=public.current_role());

CREATE POLICY notifikasi_admin_write ON public.notifikasi
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY upload_read ON public.excel_uploads
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','verifikator'));

CREATE POLICY upload_admin_write ON public.excel_uploads
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY sertifikat_read ON public.sertifikat
FOR SELECT TO authenticated
USING (public.current_role() IS NOT NULL);

CREATE POLICY sertifikat_admin_write ON public.sertifikat
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY kipapp_read ON public.kipapp
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','verifikator'));

CREATE POLICY kipapp_admin_write ON public.kipapp
FOR ALL TO authenticated
USING (public.current_role()='admin')
WITH CHECK (public.current_role()='admin');

CREATE POLICY koreksi_read ON public.permintaan_koreksi
FOR SELECT TO authenticated
USING (public.current_role() IN ('admin','verifikator'));

CREATE POLICY koreksi_write ON public.permintaan_koreksi
FOR ALL TO authenticated
USING (public.current_role() IN ('admin','verifikator'))
WITH CHECK (public.current_role() IN ('admin','verifikator'));

CREATE POLICY audit_admin_read ON public.audit_log
FOR SELECT TO authenticated
USING (public.current_role()='admin');

CREATE POLICY migrations_admin_read ON public.orbit_schema_migrations
FOR SELECT TO authenticated
USING (public.current_role()='admin');

-- ============================================================================
-- 22. STORAGE BUCKET DAN POLICY
-- Keterangan:
-- - Bucket doc-pegawai dibuat private.
-- - Admin boleh upload/update/delete.
-- - Sertifikat dapat dibaca semua akun aktif; dokumen umum hanya Admin/Verifikator.
-- ============================================================================
INSERT INTO storage.buckets(id,name,public)
VALUES('doc-pegawai','doc-pegawai',FALSE)
ON CONFLICT (id) DO UPDATE SET public=FALSE;

DROP POLICY IF EXISTS storage_certificate_read ON storage.objects;
DROP POLICY IF EXISTS storage_document_read ON storage.objects;
DROP POLICY IF EXISTS storage_admin_insert ON storage.objects;
DROP POLICY IF EXISTS storage_admin_update ON storage.objects;
DROP POLICY IF EXISTS storage_admin_delete ON storage.objects;

CREATE POLICY storage_certificate_read ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id='doc-pegawai'
  AND (name LIKE 'sertifikat/%' OR name LIKE 'sert-%')
  AND public.current_role() IS NOT NULL
);

CREATE POLICY storage_document_read ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id='doc-pegawai'
  AND public.current_role() IN ('admin','verifikator')
);

CREATE POLICY storage_admin_insert ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (bucket_id='doc-pegawai' AND public.current_role()='admin');

CREATE POLICY storage_admin_update ON storage.objects
FOR UPDATE TO authenticated
USING (bucket_id='doc-pegawai' AND public.current_role()='admin')
WITH CHECK (bucket_id='doc-pegawai' AND public.current_role()='admin');

CREATE POLICY storage_admin_delete ON storage.objects
FOR DELETE TO authenticated
USING (bucket_id='doc-pegawai' AND public.current_role()='admin');

-- ============================================================================
-- 23. GRANT AKSES
-- Keterangan: RLS tetap menjadi pagar utama; GRANT memberi izin dasar Supabase.
-- ============================================================================
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;

REVOKE ALL ON FUNCTION public.current_profile_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_role() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.current_juri_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.orbit_login_profile(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.orbit_update_my_profile(TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.orbit_admin_upsert_user(TEXT,TEXT,TEXT,TEXT,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_daftar_juri_status() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_kalender_operasional() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.simpan_nilai_bulanan_realtime(UUID,NUMERIC,INTEGER,DATE) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.orbit_simpan_nilai_final(UUID,NUMERIC,INTEGER,DATE,INTEGER,INTEGER,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_nominasi_bulanan_per_tim(INTEGER,INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_kandidat_nominasi_triwulan(INTEGER,INTEGER) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.kirim_nominasi_ke_juri(INTEGER,INTEGER,UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.kirim_nominasi_ke_juri(DATE,UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.kirim_nominasi_ke_juri(TEXT,UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.simpan_penilaian_juri(UUID,NUMERIC,TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.hapus_penilaian_juri(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_ranking_live() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.kirim_ranking_ke_verifikator() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.tetapkan_pemenang(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.kembalikan_ke_admin(TEXT) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.buka_kembali_setelah_koreksi() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reset_penilaian_baru() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.simpan_override_nilai(UUID,NUMERIC,TEXT) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.current_profile_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_juri_id() TO authenticated;
GRANT EXECUTE ON FUNCTION public.orbit_login_profile(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.orbit_update_my_profile(TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.orbit_admin_upsert_user(TEXT,TEXT,TEXT,TEXT,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daftar_juri_status() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_kalender_operasional() TO authenticated;
GRANT EXECUTE ON FUNCTION public.simpan_nilai_bulanan_realtime(UUID,NUMERIC,INTEGER,DATE) TO authenticated;
GRANT EXECUTE ON FUNCTION public.orbit_simpan_nilai_final(UUID,NUMERIC,INTEGER,DATE,INTEGER,INTEGER,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nominasi_bulanan_per_tim(INTEGER,INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_kandidat_nominasi_triwulan(INTEGER,INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kirim_nominasi_ke_juri(INTEGER,INTEGER,UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kirim_nominasi_ke_juri(DATE,UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kirim_nominasi_ke_juri(TEXT,UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.simpan_penilaian_juri(UUID,NUMERIC,TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hapus_penilaian_juri(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_ranking_live() TO authenticated;
GRANT EXECUTE ON FUNCTION public.kirim_ranking_ke_verifikator() TO authenticated;
GRANT EXECUTE ON FUNCTION public.tetapkan_pemenang(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.kembalikan_ke_admin(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.buka_kembali_setelah_koreksi() TO authenticated;
GRANT EXECUTE ON FUNCTION public.reset_penilaian_baru() TO authenticated;
GRANT EXECUTE ON FUNCTION public.simpan_override_nilai(UUID,NUMERIC,TEXT) TO authenticated;

-- ============================================================================
-- 24. SEED DATA AWAL USERS
-- Keterangan:
-- - Baris ini membuat profil awal, bukan password Auth.
-- - Buat akun Auth dengan email yang sama via Supabase Auth atau Sign Up web.
-- - Admin pertama dipastikan aktif agar bisa mengelola akun lain.
-- ============================================================================
INSERT INTO public.users(email,nama,role,tim,status) VALUES
  ('admin@orbit123.com','Admin Orbit','admin','Umum','aktif'),
  ('juri@orbit123.com','Juri Penilai','juri','Umum','aktif'),
  ('verifikator@orbit123.com','Kepala BPS','verifikator','Umum','aktif'),
  ('pegawai@orbit123.com','Pegawai Orbit','pegawai','Umum','aktif')
ON CONFLICT (email) DO UPDATE SET
  nama=EXCLUDED.nama,
  role=EXCLUDED.role,
  tim=EXCLUDED.tim,
  status=EXCLUDED.status,
  updated_at=NOW();

-- ============================================================================
-- 25. SEED DATA JURI LAMA
-- Keterangan: nama lama disimpan nonaktif agar tidak dihitung sebagai Juri siap
-- menilai sebelum memiliki akun login role Juri yang aktif.
-- ============================================================================
INSERT INTO public.juri(nama,tim,status) VALUES
  ('Norma', 'Umum', 'nonaktif'),
  ('Roy', 'Umum', 'nonaktif'),
  ('Sirly', 'Umum', 'nonaktif'),
  ('Anton', 'Umum', 'nonaktif'),
  ('Titien', 'Umum', 'nonaktif'),
  ('Wuri', 'Umum', 'nonaktif'),
  ('Ratna', 'Umum', 'nonaktif'),
  ('Viktor', 'Umum', 'nonaktif'),
  ('Hotan', 'Umum', 'nonaktif'),
  ('Bhayu', 'Umum', 'nonaktif')
ON CONFLICT (nama) DO NOTHING;

-- ============================================================================
-- 26. SEED DATA PEGAWAI
-- Keterangan: daftar pegawai dari schema mentah lama, dikelompokkan per tim.
-- ============================================================================
INSERT INTO public.pegawai(nama,tim,status) VALUES
  ('Jermias Oscar Jeffry Sahambangun', 'Umum', 'aktif'),
  ('Johanna Maria Farida Tampemawa', 'Umum', 'aktif'),
  ('Radjid Dwi Iskandar', 'Umum', 'aktif'),
  ('Stela Engeline Doris Lomboan', 'Umum', 'aktif'),
  ('Nurul Hidayah', 'Umum', 'aktif'),
  ('Nurul Hayati Unonongo', 'Umum', 'aktif'),
  ('Deesye Loury Bue', 'Umum', 'aktif'),
  ('Joice Juliana Koyongian', 'Umum', 'aktif'),
  ('Steven Kalvin Montolalu', 'Umum', 'aktif'),
  ('Friska Patricia Raintung', 'Umum', 'aktif'),
  ('Christian Leonardo Pratama', 'Umum', 'aktif'),
  ('Insan Riski Dwi Perdana', 'Umum', 'aktif'),
  ('Muhammad Alifh', 'Umum', 'aktif'),
  ('Yuan Philips Gigir', 'Umum', 'aktif'),
  ('Priska Harto Lolowang', 'Umum', 'aktif'),
  ('Tri Hidayati', 'Umum', 'aktif'),
  ('Irene Ruth Longkutoy', 'Umum', 'aktif'),
  ('Yola Christhy Larinse', 'Umum', 'aktif'),
  ('Denis Diego Kaparang', 'Umum', 'aktif'),
  ('Michelle Jessica Suprapto', 'Umum', 'aktif'),
  ('Marlina Tuti Handayani', 'Umum', 'aktif'),
  ('Regina Pangau', 'Umum', 'aktif'),
  ('Wisnu Triaji', 'Umum', 'aktif'),
  ('Wardzatul Khoiriyah', 'Umum', 'aktif'),
  ('Mustika Aridya Arum', 'Umum', 'aktif'),
  ('Afifah Syabaniah Sanubari Langkau', 'Umum', 'aktif'),
  ('Nurul Fatmah Khoiriah', 'Umum', 'aktif'),
  ('Danty Welmin Yoshida Fatima', 'Umum', 'aktif'),
  ('Bregitta Sisilia Lasut', 'Umum', 'aktif'),
  ('Intan Angelia Senduk', 'Umum', 'aktif'),
  ('Ilham Alifian Firmansyah', 'Umum', 'aktif'),
  ('Muh. Miriansyah Putra Watupongoh', 'Umum', 'aktif'),
  ('Usman Maliki', 'Umum', 'aktif'),
  ('Merlin Worek', 'Umum', 'aktif'),
  ('Meltje Feralini Dohali', 'Umum', 'aktif'),
  ('Michael Damopoli', 'Umum', 'aktif'),
  ('Dedy Hartinya', 'Umum', 'aktif'),
  ('Ridho A. Sambuaga', 'Umum', 'aktif'),
  ('Kamaludin Djafar', 'Umum', 'aktif'),
  ('Yunardi Ansiga', 'Umum', 'aktif'),
  ('Adeantiko Riza Febiunca', 'Sosial', 'aktif'),
  ('Abdul Aziz Makhrus', 'Sosial', 'aktif'),
  ('Salonica Oktaviani', 'Sosial', 'aktif'),
  ('Piky Pomantow', 'Sosial', 'aktif'),
  ('Samuelin Caroles Pandelaki', 'Sosial', 'aktif'),
  ('Anggit Prihatmaja', 'Sosial', 'aktif'),
  ('Dwiwandi Alfa Sekeon', 'Sosial', 'aktif'),
  ('Yunanda Angelia Sinurat', 'Sosial', 'aktif'),
  ('Novert Cyril Lengkong', 'Produksi', 'aktif'),
  ('Eldorado Alfu Ilmy', 'Produksi', 'aktif'),
  ('Kristin Paskahrani Bakara', 'Produksi', 'aktif'),
  ('Mariane Esther Rantung', 'Produksi', 'aktif'),
  ('Rosmita Noor Arifah', 'Produksi', 'aktif'),
  ('Santje Magriet Prang', 'Produksi', 'aktif'),
  ('Laily Agustina Bestari', 'Produksi', 'aktif'),
  ('Daniel Tri Hemawan', 'Nerwilis', 'aktif'),
  ('Putri Sekarsinung', 'Nerwilis', 'aktif'),
  ('Dian Teguh Prasetyo', 'Nerwilis', 'aktif'),
  ('Cynthia Dwi Setyarini', 'Nerwilis', 'aktif'),
  ('Ratriani Retno Wardani', 'Nerwilis', 'aktif'),
  ('Muhammad Rifqi Mubarak', 'Nerwilis', 'aktif'),
  ('Agus Purwandi', 'IPDS', 'aktif'),
  ('Tiara Dameani Simamora', 'IPDS', 'aktif'),
  ('Zaenuri Putro Utomo', 'IPDS', 'aktif'),
  ('Yulius Wendi Triandaru', 'IPDS', 'aktif'),
  ('Ponimin', 'IPDS', 'aktif'),
  ('Jolly Jody Pesik', 'IPDS', 'aktif'),
  ('Satria June Adwendi', 'IPDS', 'aktif'),
  ('Muhammad Iqbal', 'IPDS', 'aktif'),
  ('Frisda Arisanti Tarigan', 'IPDS', 'aktif'),
  ('Ryko Aprianto Puasa', 'Distribusi', 'aktif'),
  ('Erna Kusumawati', 'Distribusi', 'aktif'),
  ('Marnita Simatupang', 'Distribusi', 'aktif'),
  ('Agnes Marlise Oroh', 'Distribusi', 'aktif'),
  ('Windha Wijaya', 'Distribusi', 'aktif'),
  ('Nurfadhila Fahmi Utami', 'Distribusi', 'aktif'),
  ('Dading', 'Distribusi', 'aktif'),
  ('Prima Puspita Indra Murti', 'Distribusi', 'aktif'),
  ('Ahmad Samsudin', 'Distribusi', 'aktif'),
  ('Kannia Amielsa Shanenda', 'Distribusi', 'aktif')
ON CONFLICT (nama,tim) DO UPDATE SET
  status=EXCLUDED.status,
  updated_at=NOW();

-- ============================================================================
-- 27. SINKRONISASI SEKALI SETELAH SEED
-- Keterangan: memicu sinkronisasi role -> juri/pegawai untuk seed users.
-- ============================================================================
UPDATE public.users SET updated_at=NOW() WHERE email IN ('admin@orbit123.com','juri@orbit123.com','verifikator@orbit123.com','pegawai@orbit123.com');

INSERT INTO public.orbit_schema_migrations(version,description)
VALUES('ORBIT_SUPABASE_SCHEMA_FINAL_CLEAN_2026_06_23','Schema final bersih ORBIT sesuai index.html final dan query Supabase yang masih diperlukan.')
ON CONFLICT (version) DO UPDATE SET description=EXCLUDED.description, applied_at=NOW();

COMMIT;

-- ============================================================================
-- 28. QUERY VERIFIKASI SETELAH RUN
-- Keterangan: jalankan query di bawah ini untuk memastikan objek utama tersedia.
-- ============================================================================
SELECT
  to_regprocedure('public.orbit_login_profile(text)') IS NOT NULL AS login_profile_ok,
  to_regprocedure('public.simpan_nilai_bulanan_realtime(uuid,numeric,integer,date)') IS NOT NULL AS simpan_nilai_ok,
  to_regprocedure('public.get_nominasi_bulanan_per_tim(integer,integer)') IS NOT NULL AS nominasi_bulanan_ok,
  to_regprocedure('public.kirim_nominasi_ke_juri(integer,integer,uuid[])') IS NOT NULL AS kirim_juri_ok,
  to_regprocedure('public.get_ranking_live()') IS NOT NULL AS ranking_ok,
  to_regprocedure('public.kirim_ranking_ke_verifikator()') IS NOT NULL AS verifikator_ok,
  to_regprocedure('public.tetapkan_pemenang(uuid)') IS NOT NULL AS pemenang_ok,
  EXISTS(SELECT 1 FROM storage.buckets WHERE id='doc-pegawai') AS bucket_doc_pegawai_ok;

SELECT
  (SELECT COUNT(*) FROM public.users) AS total_profil_user,
  (SELECT COUNT(*) FROM public.pegawai) AS total_pegawai,
  (SELECT COUNT(*) FROM public.juri) AS total_master_juri,
  (SELECT COUNT(*) FROM public.nilai_final) AS total_nilai_bulanan,
  (SELECT COUNT(*) FROM public.nominasi_final) AS total_nominasi_aktif,
  (SELECT COUNT(*) FROM public.history_penghargaan) AS total_arsip_pemenang;

-- ============================================================================
-- 29. CATATAN OPERASIONAL AKUN AUTH
-- Keterangan:
--   Agar akun awal bisa login, buat Auth user dengan email yang sama:
--   - admin@orbit123.com
--   - juri@orbit123.com
--   - verifikator@orbit123.com
--   - pegawai@orbit123.com
--
--   Password dibuat melalui Authentication -> Users di Supabase Dashboard,
--   atau lewat form Sign Up di website. SQL ini sengaja tidak menyimpan password.
-- ============================================================================
