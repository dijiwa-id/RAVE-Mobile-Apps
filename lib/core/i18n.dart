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
  String get recentlyPlayed => _('Diputar baru-baru ini', 'Recently played');
  String get featuredPlaylists => _('Playlist pilihan RAVE', 'RAVE featured playlists');
  String get upcomingEvents => _('Event mendatang', 'Upcoming events');
  String eventsIn(String city) => _('Event di $city', 'Events in $city');

  // Jelajahi & kategori (sama dengan /app/search & /app/genre di web)
  String get browseAll => _('Jelajahi semua', 'Browse all');
  String get popularSongs => _('Lagu populer', 'Popular songs');
  String get releasesTitle => _('Rilisan', 'Releases');
  String get noContentInCategory => _('Belum ada konten di kategori ini', 'Nothing in this category yet');
  String get storiesTab => _('Cerita & Fiksi', 'Stories & Fiction');

  // Live (sama dengan /app/live di web)
  String get live => 'Live';
  String get showAll => _('Lihat semua', 'Show all');
  String get liveNow => _('Sedang live', 'Live now');
  String get liveNowEyebrow => _('Sedang tayang', 'On air now');
  String get liveUpcoming => _('Akan datang', 'Upcoming');
  String get livePast => _('Siaran sebelumnya', 'Past streams');
  String get liveNoScheduled => _('Belum ada siaran terjadwal.', 'No scheduled streams yet.');
  String get liveNobody => _('Belum ada yang live', 'Nobody is live right now');
  String get liveNobodyBody => _('Siaran berikutnya tampil di bawah — cek lagi nanti.', 'Upcoming streams are listed below — check back soon.');
  String get liveUnavailable => _('Live belum tersedia', 'Live is not available');
  String get liveInterrupted => _('Terputus', 'Interrupted');
  String get liveAired => _('Sudah tayang', 'Aired');
  String get liveSoon => _('Segera', 'Soon');
  String get liveTicket => _('Tiket', 'Ticket');
  String get liveFree => _('Gratis', 'Free');
  String get liveTicketHolders => _('Khusus pemegang tiket', 'Ticket holders only');
  String get liveEnded => _('Siaran selesai', 'Stream ended');
  String livePeak(String n) => _('Puncak $n penonton', 'Peak $n viewers');
  String get liveSeeOther => _('Lihat siaran lain', 'See other streams');
  String get liveSignInToWatch => _('Masuk untuk menonton', 'Sign in to watch');
  String get liveRequiresAccount => _('Siaran ini memerlukan akun RAVE (gratis).', 'This stream requires a free RAVE account.');
  String livePartOfEvent(String e) => _('Bagian dari event $e.', 'Part of the event $e.');
  String get liveRequiresTicket => _('Siaran ini memerlukan tiket.', 'This stream requires a ticket.');
  String get liveBuyTicket => _('Beli tiket', 'Buy ticket');
  String get liveNotStarted => _('Belum dimulai', 'Not started yet');
  String liveScheduled(String t) => _('Dijadwalkan $t', 'Scheduled for $t');
  String get liveStartingSoon => _('Segera dimulai', 'Starting soon');
  String get liveAutoPlay => _('Pemutar muncul otomatis saat siaran dimulai.', 'The player appears automatically when the stream starts.');
  String get liveWaiting => _('Menunggu siaran…', 'Waiting for the stream…');
  String get liveReconnecting => _('Menyambung ulang…', 'Reconnecting…');
  String get liveNotFound => _('Siaran tidak ditemukan', 'Stream not found');
  String get liveChat => _('Chat langsung', 'Live chat');
  String get liveChatEmpty => _('Belum ada pesan. Sapa duluan!', 'No messages yet. Say hi!');
  String get liveChatHint => _('Kirim pesan…', 'Send a message…');
  String get liveChatSignIn => _('Masuk untuk ikut chat', 'Sign in to chat');
  String liveSlowmode(int s) => _('Mode lambat: tunggu $s dtk', 'Slow mode: wait ${s}s');
  String liveStarted(String t) => _('Mulai $t', 'Started $t');
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
  String get email => 'Email';
  String get emailHint => _('kamu@contoh.com', 'you@example.com');
  String get sendCode => _('Kirim kode', 'Send code');
  String codeSent(String e) => _('Kode 6 digit dikirim ke $e.', 'A 6-digit code was sent to $e.');
  String get code => _('Kode', 'Code');
  String get signIn => _('Masuk', 'Sign in');
  /// Satu pintu masuk (OTP: akun baru dibuat otomatis) — sama dengan desktop.
  String get signInOrUp => _('Masuk / Daftar', 'Sign in');
  String get authTitle => _('Masuk atau daftar', 'Sign in or sign up');
  String get authBody => _('Cukup email — kami kirim kode 6 digit. Belum punya akun? Akun dibuat otomatis, tanpa kata sandi.', 'Just your email — we send a 6-digit code. New here? Your account is created automatically, no password.');
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
  String get obStart => _('Mulai', 'Get started');
  String get obCityTitle => _('Kamu dari kota mana?', 'Where are you based?');
  String get obCityHint => _('Untuk gig, artis lokal & rekomendasi skena kotamu.', 'For gigs, local artists & your city scene.');
  String get obGenreTitle => _('Genre favoritmu?', 'Your favourite genres?');
  String obGenresShowAll(int n) => _('Lihat semua $n genre', 'Show all $n genres');
  String get obGenresPopularOnly => _('Tampilkan genre populer saja', 'Show popular genres only');
  String obPicked(int n) => n == 0 ? _('Pilih satu atau lebih.', 'Pick one or more.') : _('$n dipilih', '$n selected');
  String get obArtistTitle => _('Pilih 3 artis atau lebih', 'Pick 3 or more artists');
  String obArtistsPicked(int n) => n >= 3 ? _('$n artis dipilih — mantap!', '$n artists picked — nice!') : _('$n/3 dipilih', '$n/3 picked');
  String get obReadyTitle => _('Siap dengar!', 'Ready to listen!');
  String obReadySummary(String c, int g, int a) => _('$c · $g genre · $a artis — berandamu sudah dipersonalisasi.', '$c · $g genres · $a artists — your home is personalised.');
  String get obSkip => _('Lewati', 'Skip');
  String get obGuest => _('Jelajahi dulu', 'Just browse');
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
  // Buat / playlist
  String get create => _('Buat', 'Create');
  String get createPlaylist => 'Playlist';
  String get createPlaylistHint => _('Kumpulkan lagu favoritmu dalam satu playlist.', 'Gather your favourite songs in one playlist.');
  String get namePlaylist => _('Beri nama playlist', 'Name your playlist');
  String get myPlaylist => _('Playlist saya', 'My playlist');
  String get cancel => _('Batal', 'Cancel');
  String get addToPlaylist => _('Tambah ke playlist', 'Add to playlist');
  String get newPlaylist => _('Playlist baru', 'New playlist');
  String addedTo(String p) => _('Ditambahkan ke $p', 'Added to $p');
  String playlistCreated(String p) => _('Playlist “$p” dibuat', 'Playlist “$p” created');
  String get yourLibrary => _('Pustaka Kamu', 'Your Library');
  // Premium
  String get premiumHero1 => _('Musik tetap gratis.', 'Music stays free.');
  String get premiumHero2 => _('Premium untuk sisanya.', 'Premium for the rest.');
  String premiumLead(String price) => _('Kualitas Tinggi (AAC 320) & Lossless/Hi-Res (FLAC), podcast & fiksi eksklusif, tanpa iklan — mulai Rp $price per bulan.',
      'High Quality (AAC 320) & Lossless/Hi-Res (FLAC), exclusive podcasts & fiction, no ads — from Rp $price a month.');
  String get alreadyPremium => _('Kamu sudah pelanggan Premium', 'You are a Premium subscriber');
  String get remindMe => _('Ingatkan saya saat dibuka', 'Remind me when it opens');
  String get remindSaved => _('Siap! Kami kabari saat Premium dibuka.', 'Done! We will tell you when Premium opens.');
  String premiumNote(int trial) => _('Dibuka bertahap setelah closed beta${trial > 0 ? ' · Gratis $trial hari untuk pelanggan pertama' : ''} · Batalkan kapan saja',
      'Rolling out after closed beta${trial > 0 ? ' · $trial days free for early subscribers' : ''} · Cancel anytime');
  String get plansTitle => _('Pilih paket', 'Pick a plan');
  String get mostPopular => _('Paling populer', 'Most popular');
  String get perMonth => _('/bulan', '/month');
  String get planIndividual => _('Individu', 'Individual');
  String get planIndividualWho => _('1 akun', '1 account');
  String get planStudent => _('Pelajar', 'Student');
  String get planStudentWho => _('1 akun terverifikasi kampus', '1 campus-verified account');
  String get planDuo => 'Duo';
  String get planDuoWho => _('2 akun dalam satu rumah', '2 accounts in one home');
  String get allBenefits => _('Semua manfaat Premium', 'All Premium benefits');
  String get hqLossless => 'AAC 320 & Lossless/Hi-Res (FLAC)';
  String get offlineSoon => _('Unduhan offline — segera hadir', 'Offline downloads — coming soon');
  String get studentVerify => _('Verifikasi pelajar & mahasiswa', 'Student verification');
  String get twoAccounts => _('Dua akun Premium terpisah', 'Two separate Premium accounts');
  String get freeVsPremium => _('Gratis vs Premium', 'Free vs Premium');
  String get cmpOnDemand => _('Musik on-demand tanpa batas', 'Unlimited on-demand music');
  String get cmpNormal => _('Kualitas Normal (AAC 160)', 'Normal quality (AAC 160)');
  String get cmpHq => _('AAC 320 & Lossless (FLAC)', 'AAC 320 & Lossless (FLAC)');
  String get cmpLyrics => _('Lirik sinkron & playlist', 'Synced lyrics & playlists');
  String get cmpLive => _('Live streaming konser', 'Live concert streaming');
  String get cmpPodcast => _('Podcast & fiksi premium', 'Premium podcasts & fiction');
  String get cmpNoAds => _('Bebas iklan', 'Ad-free');
  String get offlineSoonNote => _('Segera hadir: unduhan offline di aplikasi ponsel.', 'Coming soon: offline downloads in the mobile app.');
  String get prev => _('Sebelumnya', 'Previous');
  String get next => _('Berikutnya', 'Next');
  String get repeat => _('Ulangi', 'Repeat');
  String get position => _('Posisi lagu', 'Song position');
  String get share => _('Bagikan', 'Share');
  String get linkCopied => _('Tautan disalin', 'Link copied');
  String get noQueue => _('Antrean kosong.', 'Your queue is empty.');
  String get noLyrics => _('Lirik belum tersedia untuk lagu ini.', 'No lyrics for this song yet.');
  String get playingFrom => _('MEMUTAR DARI', 'PLAYING FROM');
  String get previewEnded => _('Pratinjau 30 detik selesai.', '30-second preview ended.');
  String get premiumQuality => _('HQ & Lossless khusus Premium — diputar dengan kualitas standar.', 'HQ & Lossless are Premium only — playing in standard quality.');
  String get premiumEpisode => _('Episode ini khusus Premium.', 'This episode is Premium only.');
  String get streamLost => _('Stream terputus. Ketuk untuk mencoba lagi.', 'Stream interrupted. Tap to retry.');
  String get ad => _('Iklan', 'Ad');
  String get houseAd => 'Dari RAVE';
  String get open => _('Buka', 'Open');
  String get qualityDisabled => _('Kualitas tinggi sedang dinonaktifkan — diputar dengan kualitas standar.', 'High quality is currently disabled — playing in standard quality.');
  String get qualityUnavailable => _('Kualitas yang dipilih belum tersedia untuk lagu ini.', 'The selected quality is not available for this song yet.');
  // Privasi (UU PDP)
  String get privacy => _('Privasi & data', 'Privacy & data');
  String get privacyHint => _('Atur bagaimana RAVE memakai datamu. Bisa diubah kapan saja.', 'Control how RAVE uses your data. Change it anytime.');
  String consentLabel(String p) => switch (p) {
        'marketing' => _('Kabar & promo RAVE', 'RAVE news & promos'),
        'personalization' => _('Rekomendasi yang dipersonalisasi', 'Personalised recommendations'),
        'ads' => _('Iklan yang relevan', 'Relevant ads'),
        _ => _('Berbagi data agregat anonim dengan artis', 'Share anonymous aggregate data with artists'),
      };
  String get privacyPolicy => _('Kebijakan Privasi', 'Privacy Policy');
  String get terms => _('Ketentuan Layanan', 'Terms of Service');
  String get deleteAccount => _('Hapus akun', 'Delete account');
  String get deleteTitle => _('Hapus akun RAVE?', 'Delete your RAVE account?');
  String get deleteBody => _('Akun, pustaka, playlist, dan riwayat dengarmu akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.', 'Your account, library, playlists and listening history will be permanently deleted. This cannot be undone.');
  String get deleteConfirm => _('Ya, hapus permanen', 'Yes, delete permanently');
  String get deleted => _('Akun dihapus.', 'Account deleted.');
  String get skip => _('Lewati', 'Skip');
  String skipIn(int s) => _('Lewati dalam $s', 'Skip in $s');
  String get adWhy => _('Iklan membantu artis tetap dibayar. Premium bebas iklan.', 'Ads keep artists paid. Premium is ad-free.');

  // Pengaturan
  String get account => _('Akun', 'Account');
  String get logout => _('Keluar', 'Sign out');
  String get premiumActive => _('Premium aktif', 'Premium active');
  String get free => _('Gratis (dengan iklan)', 'Free (with ads)');
  String get serverHint => _('Alamat gateway RAVE, mis. https://rave.id. Uji coba lokal: server demo di PC (port 8080).', 'RAVE gateway address, e.g. https://rave.id. Local testing: the demo server on your PC (port 8080).');
  String get serverInvalid => _('Alamat server tidak valid (gunakan http:// atau https://).', 'Invalid server address (use http:// or https://).');
  String get serverSaved => _('Server disimpan.', 'Server saved.');
  String get serverDown => _('Server RAVE tidak terjangkau — mencoba lagi otomatis', 'RAVE server unreachable — retrying automatically');
  String serverUnreachable(String name) => _('$name juga tidak terjangkau.', '$name is unreachable too.');
  String useServer(String name) => _('Pakai $name', 'Use $name');
  String get onboardingOfflineHint => _('Daftar artis butuh koneksi ke server. Coba lagi, pindah server, atau LEWATI dulu — bisa diatur nanti.', 'The artist list needs the server. Retry, switch server, or SKIP for now — you can set it later.');
  String get serverPresets => _('Pilihan server', 'Server presets');
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
