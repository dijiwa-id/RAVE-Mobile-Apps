# Changelog — RAVE Mobile (Android)

Format: [Keep a Changelog](https://keepachangelog.com/id/1.1.0/) · Versi: [SemVer](https://semver.org/lang/id/) `MAJOR.MINOR.PATCH+BUILD`
(BUILD = versionCode Android, selalu naik). Naikkan dengan `dart run tool/bump_version.dart patch|minor|major|build`;
tag git `mobile-vX.Y.Z`. Kompatibel dengan API gateway RAVE `/v1`.

## [0.2.3] - 2026-11-13

### Ditambahkan
- **Live** setara web: daftar Sedang live / Akan datang / Siaran sebelumnya, layar tonton dengan pemutar HLS
  (token diperbarui otomatis, tunggu saat belum mulai, sambung ulang saat terputus), jumlah penonton (heartbeat),
  chat langsung (tamu membaca, kirim setelah masuk, mode lambat), gerbang masuk/tiket/terjadwal (hitung mundur)/selesai.
  Rak **Sedang live** di beranda saat ada siaran; musik RAVE dijeda saat siaran diputar.
- Halaman **kategori** (`/v1/catalog/browse/:id`): playlist bertag, artis, rilisan, lagu populer — sama dengan web.
- Halaman **Podcast / Cerita & Fiksi** (tab, daftar acara).
- Hasil pencarian kini juga menampilkan **episode**.

### Diubah
- Tab **Cari**: kisi kategori kini dari server (`/v1/catalog/browse`, warna & gambar sama dengan web) — bukan lagi
  8 genre tetap yang hanya menjalankan pencarian teks. Tile Live ditambahkan; podcast/live mengikuti modul platform.
- **Satu pintu masuk** "Masuk / Daftar" (beranda, Pustaka, Pengaturan, onboarding, lembar tamu) menggantikan tombol
  Masuk + Daftar yang terpisah — login OTP membuat akun baru otomatis (sama dengan desktop).

## [0.2.2] - 2026-11-13

### Diperbaiki
- **Aplikasi tertutup sendiri saat memutar lagu** (build release): ikon notifikasi pemutar `ic_stat_rave` dihapus
  resource shrinker R8 karena hanya dirujuk lewat nama dari Dart (`androidNotificationIcon`) → Android menolak
  notifikasi media ("Invalid notification (no valid small icon)") dan mematikan proses. Kini dijaga lewat
  `res/raw/keep.xml`.

## [0.2.1] - 2026-11-13

### Ditambahkan
- Beranda setara web dengan data demo: **Diputar baru-baru ini** (putar riwayat mulai lagu itu), **Playlist pilihan
  RAVE**, **Event di kotamu** (tiket dibuka di web RAVE). Rak yang gagal dimuat disembunyikan, feed utama tetap tampil.
- Banner koneksi di atas mini-player: cek server saat start, saat server diganti, dan saat aplikasi kembali aktif;
  coba ulang otomatis (5→60 dtk) dan tawarkan server lain dari preset. Tanpa polling selama server sehat.
- Pilihan cepat server di Pengaturan (`--dart-define=RAVE_API_PRESETS=Nama|URL,…`).

### Diubah
- Build uji menunjuk server demo `http://<IP-LAN-PC>:8080` (`./rave demo`), bukan produksi lokal :8088.
- Uji koneksi tidak lagi mengubah pengaturan sementara (alamat dikirim langsung, tanpa token).
- Ganti server lewat satu jalur aman (`switchServer`): kirim event putar, keluar, bersihkan cache.

### Diperbaiki
- **Layar berputar terus** (onboarding artis, beranda, dll.): `DataCache.load` menunggu dirinya sendiri (`whenComplete` mengembalikan Future yang sama) sehingga data tak pernah tampil walau server menjawab 200. Diperbaiki + tes regresi. Onboarding kini memuat data sekali per langkah (bukan di
  setiap build), dengan status galat jelas, tombol Coba lagi / Pakai server lain, dan batas waktu 8 dtk.
- Saat start (selama splash), bila server default tak terjangkau dan pengguna belum memilih server sendiri, aplikasi
  memakai server preset pertama yang menjawab (mis. emulator → 10.0.2.2:8080).

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
