# Changelog — RAVE Mobile (Android)

Format: [Keep a Changelog](https://keepachangelog.com/id/1.1.0/) · Versi: [SemVer](https://semver.org/lang/id/) `MAJOR.MINOR.PATCH+BUILD`
(BUILD = versionCode Android, selalu naik). Naikkan dengan `dart run tool/bump_version.dart patch|minor|major|build`;
tag git `mobile-vX.Y.Z`. Kompatibel dengan API gateway RAVE `/v1`.

## [Unreleased]

## [0.3.1] - 2026-11-21

### Ditambahkan
- **Masuk dengan Google tanpa keluar aplikasi**: tombol Google membuka lembar akun Google bawaan Android (Credential
  Manager) di atas aplikasi — pilih akun yang sudah tersinkron di ponsel, satu ketukan langsung masuk (akun ber-2FA
  lanjut ke langkah kode authenticator). Server memverifikasi ID token Google (`POST /v1/auth/oauth/google/native`).
- Bila login native belum tersedia (klien OAuth Android belum didaftarkan / tanpa Layanan Google Play), aplikasi otomatis
  memakai alur browser **di dalam aplikasi** (Custom Tab) — juga untuk Facebook/Apple — bukan membuka browser terpisah.
  Paket baru `google_sign_in` 7.

### Diubah
- **Halaman Pengaturan dirapikan** — lebih bersih & profesional: kartu profil di atas (avatar, nama + badge Verified,
  email, paket; ketuk = Edit profil), satu banner Premium ringkas untuk akun Gratis, lalu bagian bergaya daftar
  (Akun & keamanan · Pemutaran · Tampilan · Notifikasi & privasi · Tentang) dengan baris seragam: ikon kecil, judul,
  keterangan, status (Aktif/Nonaktif, tag Premium) dan kontrol/penunjuk (› sub-halaman, ↗ dibuka di web).
  Detail panjang pindah ke sub-halaman: **Kualitas audio**, **Equalizer**, **Notifikasi** per kategori, **Privasi &
  data** (kini dengan penjelasan tiap persetujuan) dan **Server**. Bahasa jadi sakelar ID/EN; **Keluar** (dengan
  konfirmasi) di bawah, **Hapus akun** sebagai tautan merah berkonfirmasi. Pencarian tetap menjangkau isi sub-halaman.
  Komponen baris/bagian yang sama ikut merapikan layar Edit profil. Uji tangkapan layar baru `test/settings_shots_test.dart`.

## [0.3.0] - 2026-11-21

### Ditambahkan
- **Verifikasi 2 langkah (2FA) saat masuk**: akun ber-authenticator diminta kode 6 digit setelah OTP email atau login
  sosial, dengan opsi **kode pemulihan** sekali pakai; kode salah, terkunci sementara, dan sesi verifikasi kedaluwarsa
  (kembali ke langkah email) ditangani dengan pesan jelas. Tanpa ini akun ber-2FA tidak bisa masuk dari aplikasi.
- **Verifikasi 2 langkah di Pengaturan → Akun**: status aktif/belum + tombol Aktifkan / Kelola di web
  (`/app/settings#set-security`). Model `Me` membawa `totp_enabled`. Uji baru `test/mfa_test.dart`.
- **Badge Verified** (`lib/widgets/verified_badge.dart`) — port 1:1 dari web: stiker bintang-sobek 12 sudut mustard
  bergaris tinta + bayangan sablon, centang "V" RAVE, cincin putus-putus di ≥ 28 px; plus cap **VERIFIED**. Tampil di
  samping nama akun yang `verified` (baris akun Pengaturan, sapaan Beranda, avatar kepala Koleksi).
- **Status verifikasi akun di Pengaturan → Akun**: Terverifikasi sejak … (+ cap), Identitas terverifikasi tanpa badge
  (KYC lama), Ditinjau, Belum disetujui, atau ajakan KYC. Tombol "Ajukan akun Verified" / "Kelola verifikasi" membuka
  `/app/settings#set-verify` di browser — pengajuan (data diri, NIK, OTP email/WhatsApp) hanya di RAVE web. Profil
  dimuat ulang saat aplikasi kembali aktif & saat Pengaturan dibuka, jadi status/badge langsung terbarui.
- **Edit profil**: foto profil (pilih dari galeri lewat Photo Picker Android → unggah `purpose: avatar`, JPG/PNG
  ≥ 300 px; hapus), nama tampilan, kota. Paket baru `image_picker`.
- Model `Me` membawa `full_name`, `birth_date`, `gender`, `bio`, `socials`, `phone`, `id_number_masked`, `verified`,
  `verified_at`, `verification_status` (profil tersimpan versi lama tetap terbaca). 27 uji baru
  (`test/verification_test.dart`).

### Diubah
- **Onboarding dirombak** — lebih bersih, profesional & responsif (320–480 dp, layar pendek, teks ×1,3): slide pertama
  memakai **cover album asli** dari katalog (`/v1/catalog/home`, cadangan kotak bermerek saat offline) berkipas di
  belakang **ilustrasi kaset RAVE** baru (`lib/widgets/cassette.dart`, reel berputar pelan, hormati kurangi-gerakan);
  sakelar ID/EN bersegmen, CTA tetap di bawah, tiket slide akhir "BRAP COMPILATION". 29 uji baru.
- **Bilah atas Beranda tamu**: tombol Masuk & Daftar diganti satu ikon Pengaturan yang membuka lembar berisi
  Masuk, Daftar, dan alamat Server (`showGuestMenu`). Pengguna yang masuk tetap langsung ke layar Pengaturan.

### Diperbaiki
- **Iklan "setiap lagu" kadang terlewat**: event `complete` ditunggu terkirim (maks 2 dtk) sebelum jeda iklan diminta.

### Diperbaiki
- **ANR / "aplikasi tidak merespons" saat gestur kembali dari tepi layar di Beranda**: handler kembali shell memanggil
  `maybePop()` pada route-nya sendiri (`PopScope(canPop: false)`) sehingga dipanggil ulang tanpa henti dan main thread
  macet 100%. Kini keluar ke launcher (`SystemNavigator.pop`). Uji regresi `test/back_gesture_test.dart`.

### Diubah
- **Tier Gratis tidak bisa menggeser lagu** (kebijakan server `streaming.free_seek_enabled`, default mati): progres hanya
  tampilan dengan ikon kunci + pesan "Geser lagu khusus Premium"; kontrol layar kunci/notifikasi & ketuk lirik juga diabaikan. "Sebelumnya" tidak mengulang
  lagu dari awal — langsung ke lagu sebelumnya. Premium tidak berubah.
- **Iklan untuk tamu**: setelah pratinjau 30 detik berakhir, pengguna yang belum masuk menerima satu iklan lalu lanjut ke
  pratinjau berikutnya (`ads.anonymous_enabled`; butuh server dengan migrasi ads `003_anonymous_impressions`).
- **Stabilitas**: hasil muat lagu lama dibuang (generasi muat), penjaga `mounted`/disposed di Live & Masuk, hitungan
  iklan memakai notifier terpisah (UI pemutar tidak dibangun ulang tiap 250 md), daftar Koleksi dibangun malas,
  profil tersimpan yang rusak tidak lagi menggagalkan start-up.

## [0.2.5] - 2026-11-15

### Ditambahkan
- **Episode podcast embed** (Spotify, YouTube, Apple Podcasts, SoundCloud, Spotify for Creators) diputar **di dalam
  aplikasi** lewat WebView (`webview_flutter`, `lib/widgets/embed_player.dart`) + tombol "Buka di …" ke aplikasi
  platform asal. Tautan keluar dari host embed dibuka di aplikasi eksternal. Episode embed tidak masuk antrean pemutar
  RAVE; memutarnya dari kartu/pencarian membuka halaman acara.
- **Beranda lebih lega & jelas:** bilah atas kini berisi **ikon V RAVE putih tanpa kotak ungu** (vektor dari
  `icon mobile.svg`, tinta di tema terang) sejajar tombol Masuk/Daftar (tamu) atau Pengaturan; hero (RAVE · Tamu,
  sapaan, catatan tamu) diturunkan ke bawah bilah atas sehingga tidak lagi menumpuk dengan tombol masuk. Tombol
  Masuk/Daftar sedikit lebih besar (target sentuh). Uji tata letak memastikan ikon satu baris dengan Masuk & hero
  di bawahnya (360/412 dp).
- **Logo Google asli** (4 warna resmi) di tombol login sosial — digambar sebagai vektor (`lib/widgets/brand_marks.dart`,
  parser path SVG kecil tanpa paket tambahan).
- **Login sosial (Google, Apple, Facebook)** di layar Masuk — hanya provider yang diaktifkan server yang tampil
  (`GET /v1/auth/oauth/providers`; server development menambah **Simulasi (dev)**). Alur aplikasi: `POST
  /v1/auth/oauth/:provider/app` → browser sistem membuka halaman konfirmasi berkode → lembar tunggu menampilkan kode
  yang sama ("Pastikan kode sama dengan di browser", Buka browser lagi, Batal) sambil polling `POST
  /v1/auth/oauth/poll` (428 menunggu · 200 token · 400 gagal · 410 kedaluwarsa). Polling dijeda saat aplikasi di
  latar belakang dan langsung memeriksa saat kembali; sesi disimpan sama seperti login OTP (`lib/core/social_login.dart`, tes `test/social_login_test.dart`).
- **Beranda setara web:** chip **Semua · Musik · Artis · Podcast · Live · Event** (mengikuti modul platform) yang
  menyaring bagian beranda; banner permanen **Mulai di RAVE** (6 langkah: putar → Cari, simpan → Disukai, mixtape →
  Pustaka, ikuti artis → chip Artis, nonton live → Live, datang ke gig → Event) dengan warna RAVE per langkah,
  "Langkah X dari N", CTA + "Tips berikutnya"/"Ulang dari awal", titik halaman; **Pilihan untuk {nama}** (tile
  penuh setinggi banner, playlist editorial). Rak = daftar horizontal ≈2,2 kartu per layar. Live tidak lagi tampil
  di "Semua" — hanya di chip Live sebagai kartu besar.
- **Satu tombol putar/jeda** (kotak mustard bertepi ink + bayangan sablon) di kartu, header, quick picks, baris
  pustaka & episode: menjadi Jeda (animasi) bila antrean berasal dari item itu, ketuk = jeda/lanjut (tidak mengulang).
  Pemutar menyimpan **konteks antrean** (`release:` · `playlist:` · `artist:` · `liked` · `show:`), sama dengan web.
  Baris lagu yang diputar menampilkan bilah EQ.
- **Kartu artis "poster gig"**: foto persegi hitam-putih + raster halftone, nama Staatliches di atas gradasi, sudut
  kanan atas terpotong, bilah mustard; berwarna penuh saat diputar. Semua foto artis persegi. Playlist tanpa sampul
  → kotak berikon (ukuran tetap).
- **Stiker toast RAVE** (BERES!/CATAT/WADUH; sampul & Urungkan opsional, miring, hilang sendiri) untuk suka/batal
  suka (+Urungkan), ikuti/berhenti ikuti, simpan album, playlist dibuat/dihapus, "Pita berputar" saat koleksi mulai,
  acak/ulangi. **Dialog konfirmasi RAVE** (bilah aksen, kicker Konfirmasi, fokus awal Batal untuk aksi berbahaya)
  untuk hapus playlist (baru) & hapus akun.
- **Sedang Diputar:** latar ambient dari warna dominan sampul (didekode 24×24 dari cache gambar, tanpa paket baru),
  piringan hitam yang menyembul & berputar saat diputar (bisa dimatikan), label pita codec, catatan "Lossless sedang
  disiapkan".
- **Pengaturan** ditata ulang per bagian berikon (Akun, Bahasa, Kualitas audio, Equalizer, Pustaka, Tampilan,
  Notifikasi, Privasi, Server, Tentang, Zona bahaya), **kolom cari** yang menyaring baris, saklar RAVE.
  Baru: **Normalisasi volume** (`loudness_gain_db` sesi, −12…+6 dB: negatif → volume, positif → LoudnessEnhancer
  Android), **Equalizer khusus Premium** (Android Equalizer bawaan, pita perangkat, preset Datar/Bass/Vokal/Akustik/
  Elektronik/Treble, kustom & atur ulang; akun Gratis terkunci + ajakan Premium), tata letak pustaka ringkas,
  animasi piringan, preferensi notifikasi per kategori × kanal.
- **Kebijakan kualitas** dari platform (`streaming.free_max_quality` / `premium_max_quality` /
  `lossless_max_resolution` / `lossless_enabled`): opsi di atas plafon Premium disembunyikan, di atas plafon Gratis
  dikunci (label Premium), deskripsi Lossless "FLAC hingga …". Sesi `lossless_pending` → pemberitahuan sekali per lagu.

- **Tema Gelap/Terang** (Pengaturan → Tampilan → Tema: Gelap · Terang · Ikuti sistem), tersinkron ke akun
  (`PATCH /v1/me {theme}`, ikut ke web & desktop). Urutan: pilihan akun → pilihan perangkat (tamu/offline) →
  default platform `appearance.player_theme` (bawaan gelap); `appearance.allow_user_theme` mati → pilihan
  disembunyikan. Tema terang "poster kertas berwarna": kanvas #f6f1e7, panel #fffdf8 bertepi ink dengan bayangan
  sablon yang sama, teks ink, aksen teks ungu (mustard tak terbaca di kertas), chip terpilih tetap mustard, logo
  versi gelap. "Pulau gelap" tetap gelap: mini-player & deck, layar Sedang Diputar, layar tonton Live, splash &
  onboarding, header artis/kategori/Premium, kartu poster artis, tile pilihan, kartu langkah berwarna.
  Ikon bilah status & navigasi mengikuti tema. Tema gelap tidak berubah.

- **Pengaturan mengikuti status akun** (sama dengan web): tamu tidak punya menu pengaturan — beranda hanya
  menampilkan **Masuk** & **Daftar**, layar Pengaturan untuk tamu hanya kartu ajakan Masuk/Daftar; server tetap bisa
  diganti tamu lewat tombol **Server** di banner koneksi. Akun Gratis: bagian Kualitas audio & Equalizer diganti satu
  kartu Premium; Normalisasi volume & Hemat data pindah ke bagian **Pemutaran** (semua akun); kualitas yang diminta =
  bawaan server, pilihan di atas plafon Gratis dikembalikan ke Otomatis. Premium: semua tampil. Chip lompat & pencarian
  hanya untuk bagian yang tampil; berubah langsung saat masuk/keluar/naik-turun paket.

- **Gerak & animasi RAVE** (terasa seperti stiker & tape deck; "kurangi gerakan" Android → langsung tanpa animasi):
  - **Tepi memudar** di semua daftar horizontal (rak beranda, chip, Mulai di RAVE, Pilihan untuk…, kartu Live,
    chip Pustaka, rak cari/kategori, chip lompat Pengaturan, tombol banner koneksi) — hanya sisi yang masih berisi,
    muncul/hilang beranimasi (`FadedEdges` / `RaveHorizontalList`).
  - Rak & tile **snap per kartu** dengan deselerasi halus.
  - **Header paralaks** di Album/Playlist/Podcast/Artis: sampul/foto bergeser lebih lambat, mengecil & memudar,
    membesar saat ditarik; judul mengecil, latar app bar memudar masuk.
  - **Masuk bertahap** bagian beranda & baris lagu awal (sekali, tidak diulang saat digulir kembali).
  - Ketuk ulang tab aktif → **gulir ke atas** beranimasi; haptik ringan pada tab, chip, putar, suka.
  - Mulai di RAVE: paralaks isi & kolase saat digeser, titik halaman beranimasi.
  - **Tekan-amblas** kartu, tombol, tile, PlayFab (mengecil & bergeser ke bayangan, memantul kembali); chip terpilih
    disapu mustard; Putar↔Jeda berputar-morf; hati suka **memantul + semburan mustard**; stiker toast keluar
    beranimasi.
  - Transisi halaman RAVE (geser cepat + pudar); Sedang Diputar bisa **ditarik ke bawah mengikuti jari**, piringan
    **spin-up/spin-down** halus saat putar/jeda.
  - **Overscroll "kain ditarik"** (menggantikan pantul + indikator mustard): di tepi atas/bawah isi & latar header
    (gradasi Beranda, hero Premium, header artis/album/playlist/podcast) **meregang** — tidak pernah ada celah kosong.
    Satu `RaveScrollBehavior` (StretchingOverscrollIndicator + fisika jepit) untuk seluruh aplikasi: Beranda, Cari,
    Koleksi, Premium, Artis/Album/Playlist/Podcast, Pengaturan, Live.
  - **Tarik-segarkan kaset**: stiker kaset kecil turun di area regang, gulungan pita berputar mengikuti jarak tarik,
    label Space Mono "Tarik / Lepas untuk segarkan" (mustard saat siap), getar ringan sekali saat melewati ambang.
    Dilepas → pegas teredam kritis (tanpa getar balik), gulungan terus berputar sampai muat ulang selesai, lalu
    menghilang lembut. Memakai logika muat ulang yang ada (ApiView/Live); layar tanpa muat ulang hanya meregang.
    Satu pemicu per tarikan; ApiView bersarang (Koleksi → artis/album) → satu indikator, semua reload sekali.
    "Kurangi gerakan" → indikator statis tanpa animasi.
  - **Kerangka shimmer** untuk rak & daftar saat memuat.
- **Spektrum LCD mengikuti lagu (Sedang Diputar):** layar LCD selebar isi (sejajar gutter), spektrum memenuhi sisa
  lebar LCD dengan jumlah bilah dari lebarnya (`clamp(lebar / 6, 16, 64)` — ±30–40 bilah di ponsel). Bentuk bilah
  diambil dari amplop spektrum per lagu di server (`GET /v1/catalog/tracks/:id/spectrum`, 32 pita log, sama dengan
  web & desktop) dan diputar sinkron dengan posisi pemutar: interpolasi antar-frame, attack cepat/release halus,
  topi puncak ala hi-fi yang jatuh pelan, bilah turun ke lantai saat jeda, lompat langsung saat seek. Digambar
  dengan satu `CustomPainter` (tanpa rebuild widget per frame); ticker hanya berjalan saat diputar, layar terlihat,
  dan aplikasi aktif. Episode, iklan, amplop belum siap (202, dicoba ulang ±30 dtk maks 2×), 404 atau galat
  jaringan → animasi dekoratif selebar sama — pemutaran tidak pernah terganggu, jalur audio/EQ/normalisasi tidak
  diubah. Amplop disimpan di memori (LRU 20 lagu), respons basi saat ganti lagu diabaikan. "Kurangi gerakan" →
  bilah statis dari frame saat ini (≤ 4×/dtk, tanpa topi puncak).

### Diubah
- **Tombol transport Sedang Diputar setara web:** lima tuts kini rapat dalam satu baki deck (celah 4 dp, padding 6 dp)
  selebar isi — tepi baki tepat di gutter — dengan proporsi tetap (toggle 1 · lompat 1,25 · PLAY 1,6) alih-alih
  tersebar berjarak.
- **Efek tekan tape deck vintage pada semua tuts deck:** muka tuts turun ±3 dp menutupi sisi gelap tuts saat disentuh
  (langsung, tanpa jeda pengenal ketukan), kembali dengan pegas kecil saat dilepas; tekanan kilat tetap terlihat masuk
  penuh. Toggle Acak/Ulang yang aktif terkunci setengah turun seperti tuts deck kaset. Haptik dua tahap (masuk/kembali);
  gerak dikurangi → tanpa animasi.
- **Copy seluruh aplikasi** ditulis ulang: santai tapi profesional, "kamu" (bukan "Anda"), singkat & hangat, istilah
  setara web — **Pustaka → Koleksi** ("Koleksi Kamu" / "Your Collection"), Lagu yang Disukai, Sedang Diputar,
  Antrean, Lirik, Equalizer, Normalisasi volume, Tema. Galat menyebut apa yang terjadi + langkah berikutnya
  ("Waduh, ada yang error. Coba lagi ya." / "Oops, something went wrong — try again?"); galat mentah (5xx,
  FormatException, dsb.) tidak lagi tampil ke pengguna (`friendlyError`). Keadaan kosong punya dorongan ramah +
  CTA (Koleksi artis/album kosong, playlist kosong → **Cari musik**). Teks legal, privasi, pembayaran & hapus akun
  tetap jelas & presisi. EN diselaraskan dengan suara yang sama. Label tab bawah: "Koleksi".
- **Tepi kontrol pemutar sejajar UI**: satu gutter `Rave.gutter` (16 dp) untuk isi halaman, mini-player & Sedang
  Diputar. Mini-player: tepi kiri sampul & tepi kanan tombol putar tepat di gutter (margin + bingkai + padding =
  16 dp). Sedang Diputar: sampul, judul + suka, LCD + progres + waktu, transport (acak · sebelumnya · putar ·
  berikutnya · ulangi, tersebar rata, tombol terluar menempel gutter, satu garis tengah) dan baris Antrean/Lirik/
  Bagikan berbagi tepi kiri/kanan yang sama; tombol ikon diberi padding "gutter − sisipan ikon" sehingga **muka**
  ikon yang sejajar (bayangan sablon tidak dihitung). Komposisi sampul + piringan kini selebar isi (piringan yang
  menyembul berhenti tepat di tepi kanan); animasi piringan mati → sampul persegi selebar isi. Target sentuh tombol
  deck ≥ 48 dp tanpa sisipan visual (area sentuh diperluas vertikal).
- Kicker "Racikan RAVE" di atas "Pilihan untuk …" dihapus (sama dengan web).
- Warna tema dibaca lewat ekstensi tema `RaveColors` (`context.rc`) alih-alih hex gelap tertanam.
- Pustaka: chip filter bergaya RAVE, sampul persegi, tombol putar per baris, muat ulang otomatis setelah perubahan.
- Snackbar Material diganti stiker toast di seluruh aplikasi.

### Diperbaiki
- Slider progres Sedang Diputar menyusut ke lebar isiannya (lintasan tidak terlihat penuh); thumb tidak lagi
  menonjol 2 dp keluar lintasan.
- Kartu "Mulai di RAVE": CTA panjang tidak lagi overflow di layar 360 dp.

### Catatan teknis
- `AudioPlayer` kini dibuat dengan `AudioPipeline` (LoudnessEnhancer + Equalizer, Android). Bila efek gagal dibuat di
  perangkat, pemutar dibuat ulang tanpa efek, lagu dimuat ulang, dan efek tidak dicoba lagi (`fxUnsupported`) —
  pemutaran, notifikasi & audio latar tidak terpengaruh.
- Tidak ada dependensi baru.

## [0.2.4] - 2026-11-13

### Diperbaiki
- Info siaran Live: nama organisasi tidak lagi ditampilkan dobel bila sama dengan nama artis
  ("Senja Kolektif · Senja Kolektif"), sama dengan desktop.

### Diuji
- Diuji di Pixel 7: beranda, musik latar & layar terkunci (tanpa crash notifikasi), Live (video, penonton, chat), Cari & kategori.

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
