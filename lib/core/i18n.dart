/// Teks antarmuka Indonesia/Inggris (ringan, tanpa generator). Pilih lewat `S.of(locale)`.
class S {
  const S._(this.id);
  final bool id;
  static const _id = S._(true);
  static const _en = S._(false);
  static S of(String locale) => locale == 'id' ? _id : _en;

  String _(String i, String e) => id ? i : e;

  // Navigasi
  String get home => _('Beranda', 'Home');
  String get search => _('Cari', 'Search');
  String get library => _('Pustaka', 'Library');
  String get liked => _('Lagu yang Disukai', 'Liked Songs');
  String get settings => _('Pengaturan', 'Settings');

  // Sapaan
  String greeting(int hour) => hour < 11
      ? _('Selamat pagi', 'Good morning')
      : hour < 15
          ? _('Selamat siang', 'Good afternoon')
          : hour < 19
              ? _('Selamat sore', 'Good evening')
              : _('Selamat malam', 'Good night');

  // Masuk
  String get loginTitle => _('Masuk ke RAVE', 'Sign in to RAVE');
  String get tagline => _('Musik independen Indonesia — dari kamar tidur sampai panggung.', 'Indonesian independent music — from bedrooms to stages.');
  String get email => 'Email';
  String get emailHint => _('kamu@contoh.com', 'you@example.com');
  String get sendCode => _('Kirim kode', 'Send code');
  String codeSent(String e) => _('Kode 6 digit dikirim ke $e.', 'A 6-digit code was sent to $e.');
  String get code => _('Kode', 'Code');
  String get signIn => _('Masuk', 'Sign in');
  String get changeEmail => _('Ganti email', 'Change email');
  String get resend => _('Kirim ulang', 'Resend');
  String devCode(String c) => _('Kode dev: $c', 'Dev code: $c');
  String get server => 'Server';
  // Onboarding
  String get ob1Title => _('Suara skena independen', 'The sound of the indie scene');
  String get ob1Body => _('Rilisan terbaru dari band kamar tidur sampai panggung kota — dikurasi, tanpa algoritma yang menenggelamkan.', 'New releases from bedroom bands to city stages — curated, not buried by the algorithm.');
  String get ob2Title => _('Dengar di mana saja', 'Listen anywhere');
  String get ob2Body => _('Lirik tersinkron, antrean, dan pemutaran latar belakang dengan kontrol di layar kunci & headset.', 'Synced lyrics, queues and background playback with lock-screen & headset controls.');
  String get ob3Title => _('Dukung artismu', 'Back your artists');
  String get ob3Body => _('Setiap putaran tercatat untuk royalti artis. Ikuti, tonton live, dan beli tiket gig langsung dari RAVE.', 'Every play is counted toward artist royalties. Follow, watch live and buy gig tickets right in RAVE.');
  String get obNext => _('Lanjut', 'Next');
  String get obSkip => _('Lewati', 'Skip');
  String get obGuest => _('Jelajahi dulu', 'Just browse');
  String get signup => _('Daftar gratis', 'Sign up free');
  String get signupTitle => _('Daftar RAVE', 'Join RAVE');
  String get signupBody => _('Gratis. Cukup email — kami kirim kode 6 digit, tanpa kata sandi.', 'Free. Just your email — we send a 6-digit code, no password.');
  String get signupCta => _('Buat akun', 'Create account');
  String get noAccount => _('Belum punya akun? Daftar', 'No account yet? Sign up');
  String get haveAccount => _('Sudah punya akun? Masuk', 'Already have an account? Sign in');
  String get guest => _('Tamu', 'Guest');
  String get guestTitle => _('Masuk untuk lanjut', 'Sign in to continue');
  String get guestBody => _('Simpan lagu favorit, buat pustaka, ikuti artis, dan dengarkan lagu penuh — gratis.', 'Save favourites, build your library, follow artists and listen to full songs — free.');
  String get guestBanner => _('Kamu mendengarkan sebagai tamu — pratinjau 30 detik. Daftar gratis untuk lagu penuh.', 'You are listening as a guest — 30-second previews. Sign up free for full songs.');

  // Umum
  String get play => _('Putar', 'Play');
  String get pause => _('Jeda', 'Pause');
  String get shuffle => _('Acak', 'Shuffle');
  String get follow => _('Ikuti', 'Follow');
  String get following => _('Mengikuti', 'Following');
  String get save => _('Simpan', 'Save');
  String get saved => _('Tersimpan', 'Saved');
  String get retry => _('Coba lagi', 'Try again');
  String get offline => _('Server RAVE tidak terjangkau. Periksa koneksi atau alamat server di Pengaturan.', 'Cannot reach the RAVE server. Check your connection or the server address in Settings.');
  String get empty => _('Belum ada apa-apa di sini.', 'Nothing here yet.');
  String songs(int n) => id ? '$n lagu' : '$n ${n == 1 ? 'song' : 'songs'}';
  String listeners(String n) => _('$n pendengar bulanan', '$n monthly listeners');
  String followers(String n) => _('$n pengikut', '$n followers');
  String get verified => _('Artis terverifikasi', 'Verified artist');
  String get popular => _('Populer', 'Popular');
  String get discography => _('Diskografi', 'Discography');
  String get about => _('Tentang', 'About');
  String get episodes => _('Episode', 'Episodes');
  String get premium => 'Premium';
  String get addQueue => _('Tambah ke antrean', 'Add to queue');
  String addedQueue(String t) => _('Ditambahkan ke antrean: $t', 'Added to queue: $t');
  String get like => _('Sukai', 'Like');
  String get unlike => _('Hapus dari Disukai', 'Remove from Liked');
  String get goArtist => _('Lihat artis', 'Go to artist');
  String get goAlbum => _('Lihat album', 'Go to album');
  String get seeAll => _('Lihat semua', 'See all');
  String get showLess => _('Lebih sedikit', 'Show less');
  String kind(String k) => switch (k) {
        'SINGLE' => 'Single',
        'EP' => 'EP',
        'ALBUM' || 'release' => 'Album',
        'artist' => _('Artis', 'Artist'),
        'playlist' => 'Playlist',
        'show' => 'Podcast',
        'episode' => 'Episode',
        _ => k,
      };

  // Cari
  String get searchHint => _('Apa yang ingin kamu dengar?', 'What do you want to listen to?');
  String get browse => _('Jelajahi', 'Browse');
  String get topResult => _('Hasil teratas', 'Top result');
  String get artists => _('Artis', 'Artists');
  String get albums => _('Album', 'Albums');
  String get podcasts => 'Podcast';
  String noResults(String q) => _('Tidak ada hasil untuk “$q”.', 'No results for “$q”.');

  // Pustaka
  String get playlists => 'Playlist';
  String likedSub(int n) => 'Playlist · ${songs(n)}';

  // Pemutar
  String get nowPlaying => _('Sedang diputar', 'Now playing');
  String get queue => _('Antrean', 'Queue');
  String get lyrics => _('Lirik', 'Lyrics');
  String get nextUp => _('Berikutnya', 'Next up');
  String get noQueue => _('Antrean kosong.', 'Your queue is empty.');
  String get noLyrics => _('Lirik belum tersedia untuk lagu ini.', 'No lyrics for this song yet.');
  String get playingFrom => _('MEMUTAR DARI', 'PLAYING FROM');
  String get previewEnded => _('Pratinjau 30 detik selesai.', '30-second preview ended.');
  String get premiumQuality => _('HQ & Lossless khusus Premium — diputar dengan kualitas standar.', 'HQ & Lossless are Premium only — playing in standard quality.');
  String get premiumEpisode => _('Episode ini khusus Premium.', 'This episode is Premium only.');
  String get streamLost => _('Stream terputus. Ketuk untuk mencoba lagi.', 'Stream interrupted. Tap to retry.');
  String get ad => _('Iklan', 'Ad');
  String get skip => _('Lewati', 'Skip');
  String skipIn(int s) => _('Lewati dalam $s', 'Skip in $s');
  String get adWhy => _('Iklan membantu artis tetap dibayar. Premium bebas iklan.', 'Ads keep artists paid. Premium is ad-free.');

  // Pengaturan
  String get account => _('Akun', 'Account');
  String get logout => _('Keluar', 'Sign out');
  String get premiumActive => _('Premium aktif', 'Premium active');
  String get free => _('Gratis (dengan iklan)', 'Free (with ads)');
  String get serverHint => _('Alamat gateway RAVE, mis. https://rave.id. Dari emulator: http://10.0.2.2:8088.', 'RAVE gateway address, e.g. https://rave.id. From the emulator: http://10.0.2.2:8088.');
  String get serverInvalid => _('Alamat server tidak valid (gunakan http:// atau https://).', 'Invalid server address (use http:// or https://).');
  String get serverSaved => _('Server disimpan.', 'Server saved.');
  String get test => _('Uji koneksi', 'Test connection');
  String testOk(String v) => _('Terhubung · RAVE $v', 'Connected · RAVE $v');
  String get language => _('Bahasa', 'Language');
  String get quality => _('Kualitas streaming', 'Streaming quality');
  String get qualityHint => _('HQ & Lossless khusus Premium.', 'HQ & Lossless are Premium only.');
  String q(String k) => switch (k) {
        'low' => _('Rendah (64 kbps)', 'Low (64 kbps)'),
        'normal' => 'Normal (160 kbps)',
        'high' => _('Tinggi (320 kbps)', 'High (320 kbps)'),
        'lossless' => 'Lossless (FLAC)',
        _ => _('Otomatis', 'Automatic'),
      };
  String get dataSaver => _('Hemat data', 'Data saver');
  String get dataSaverHint => _('Selalu putar kualitas rendah (64 kbps) — cocok untuk data seluler.', 'Always stream in low quality (64 kbps) — good for mobile data.');
  String version(String v) => 'RAVE Mobile $v · © 2026 RAVE · dijiwa.id';
}
