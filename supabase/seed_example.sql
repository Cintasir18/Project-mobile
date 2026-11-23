-- Opsional: data awal contoh agar dropdown institusi dapat digunakan saat registrasi.
-- Jalankan setelah schema.sql. Ganti data ini dengan institusi sebenarnya.
insert into public.institutions
  (name, type, location, latitude, longitude, is_active)
values
  ('Institusi Contoh ELORA', 'Sekolah', 'Yogyakarta (contoh)', -7.7956, 110.3695, true);
