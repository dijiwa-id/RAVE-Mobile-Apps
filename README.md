# RAVE Mobile (Android)

Aplikasi dengar RAVE untuk Android, dibangun dengan **Flutter**. Tata letak ala aplikasi musik (3 tab + mini-player +
pemutar layar penuh) dengan gaya khas RAVE: kanvas gelap, mustard, ungu, judul poster Staatliches, label Space Mono,
sudut tegas, bayangan sablon, tekstur grain. Klien untuk platform RAVE (`../Development`, gateway `/v1`).

## Alur

1. **Splash** — piringan hitam berputar masuk, huruf R-A-V-E jatuh seperti potongan kertas ransom-note, stiker menempel.
2. **Onboarding** (sekali) — 3 halaman poster: skena independen · dengar di mana saja · dukung artis; pilih bahasa;
   akhir: **Daftar gratis / Masuk / Jelajahi dulu**.
3. **Langsung ke pemutar sebagai tamu** — katalog terbuka, putar = pratinjau 30 dtk. Tombol Masuk & Daftar selalu ada
   (beranda, Pustaka, Pengaturan); fitur pribadi (Disukai, Pustaka, Ikuti) mengajak masuk. Masuk/Daftar = OTP email
   (IAM RAVE tanpa kata sandi; akun baru dibuat otomatis).

## Fitur (v0.1)

| Area | Isi |
|---|---|
| Dengar | Beranda (quick picks + rak), Cari (langsung saat mengetik, jelajah genre), Album, Artis (header poster gig), Playlist, Lagu yang Disukai, Pustaka (playlist/artis/album), Podcast & episode |
| Pemutar | Mini-player + layar penuh (geser), antrean, acak, ulangi, seek, **lirik tersinkron** (ketuk baris untuk lompat), pemulihan stream, kualitas sesuai hak Premium, hemat data, laporan putar untuk royalti (antre ulang saat offline), iklan tier Gratis |
| Android | Putar di latar belakang + kontrol di notifikasi, layar kunci, headset/Bluetooth (audio_service); jeda otomatis saat headset dicabut / telepon masuk; token di Keystore (flutter_secure_storage); cache gambar di disk |
| UX | Riwayat per tab, tombol kembali Android, tarik untuk menyegarkan, bahasa Indonesia/Inggris, responsif (ponsel–tablet) |

Ringan: 7 dependensi (tanpa paket state/router), APK arm64 ±19,6 MB.

## Struktur

```
lib/
  main.dart                 inisialisasi (pengaturan, sesi, pemutar) → IntroGate
  core/                     theme (token RAVE), api (gateway + refresh token), models, settings, i18n, app_state (cache, likes)
  player/player.dart        pemutar (just_audio + audio_service), laporan putar, iklan
  widgets/                  common (sampul, tombol, ApiView), media (kartu, rak, baris lagu), mini_player, collection
  screens/                  intro (splash + onboarding), shell (tab), home, search, library, album, artist, playlist, show, now_playing, login, settings
android/                    manifest (izin & layanan audio), MainActivity (AudioServiceActivity), ikon, network_security_config
```

## Build

Butuh Flutter 3.47+ (Dart 3.13), JDK 17, Android SDK 36+.

```bash
flutter pub get
flutter analyze && flutter test
# Server default dipasang saat build; pengguna dapat menggantinya di Pengaturan → Server.
flutter build apk --release --split-per-abi --target-platform android-arm64 --dart-define=RAVE_API=http://<IP-LAN-PC>:8080
```

- Emulator: `--dart-define=RAVE_API=http://10.0.2.2:8080` (10.0.2.2 = komputer host).
- **Server demo:** di repo `Development` jalankan `./rave demo` (atau `--reset` untuk data bersih). Perintah itu mencetak alamat LAN
  dan akun demo (`fan@rave.id`, `premium@rave.id`; kode OTP tampil di layar masuk). Ponsel & PC harus di Wi-Fi yang sama.
- Pilihan cepat server di Pengaturan: `--dart-define=RAVE_API_PRESETS=Demo PC|http://<IP>:8080,Produksi PC|http://<IP>:8088`.
  Skrip `C:\Users\Melod\rave-mobile-tools\build-apk.bat [URL]` membangun APK uji dengan preset ini.
- Ponsel fisik: IP LAN komputer (Wi-Fi yang sama). `adb reverse` tidak berfungsi pada setup WSL di mesin pengembangan ini.
- Instal: `adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.

## Sebelum rilis Play Store

- `android/app/src/main/res/xml/network_security_config.xml`: **build uji internal mengizinkan HTTP** — ubah ke
  `cleartextTrafficPermitted="false"` dan pakai server HTTPS.
- Kunci tanda tangan rilis sendiri (`android/app/build.gradle.kts` masih memakai kunci debug) + App Bundle (`flutter build appbundle`).
- Verifikasi developer Android (wajib untuk sideload di Indonesia sejak 2026) atau distribusi lewat Play Store.
- Kebijakan langganan Premium (billing Play) — lihat `../Development/docs/CLIENT-APPS.md` §2.3.

## Belum termasuk (rencana)

Buat/ubah playlist, unduhan offline Premium, tonton Live (HLS), tiket & dompet e-ticket, scanner check-in promotor,
notifikasi push (FCM), deep link `rave://`, iOS.
