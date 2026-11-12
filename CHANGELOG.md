# Changelog — RAVE Mobile (Android)

Format: [Keep a Changelog](https://keepachangelog.com/id/1.1.0/) · Versi: [SemVer](https://semver.org/lang/id/) `MAJOR.MINOR.PATCH+BUILD`
(BUILD = versionCode Android, selalu naik). Naikkan dengan `dart run tool/bump_version.dart patch|minor|major|build`;
tag git `mobile-vX.Y.Z`. Kompatibel dengan API gateway RAVE `/v1`.

## [0.2.0] - 2026-11-13

### Ditambahkan
- Tab **Pustaka Kamu**, **Premium** (paket & harga dari konfigurasi platform, perbandingan Gratis vs Premium, daftar tunggu)
  dan **Buat** (playlist baru); **Tambah ke playlist** dari menu lagu.
- Onboarding personalisasi: kota → genre → min. 3 artis (dikirim ke `/v1/me/onboarding` setelah masuk); beranda
  dipersonalisasi kota.
- Kontrol pemutar bergaya tape deck sama dengan web: baki berbevel, tombol PLAY mustard, LED acak/ulang, layar LCD
  (status, codec, waktu, spektrum), slider alur; tombol Antrean/Lirik/Bagikan.
- Versioning: satu sumber (pubspec), `lib/core/version.dart`, versi + build di Pengaturan.

### Diubah
- Mini-player memakai tombol PLAY deck & progres mustard.

## [0.1.0] - 2026-11-13

### Ditambahkan
- Rilis awal: splash & onboarding, mode tamu (pratinjau 30 dtk), Masuk/Daftar OTP, Beranda, Cari, Pustaka, Album,
  Artis, Playlist, Disukai, Podcast, pemutar latar belakang (audio_service) dengan lirik tersinkron, laporan putar
  royalti, iklan tier Gratis, ID/EN.
