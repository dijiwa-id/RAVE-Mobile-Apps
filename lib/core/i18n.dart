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
  String get recentlyPlayed => _('Baru kamu putar', 'Recently played');
  String get featuredPlaylists => _('Playlist pilihan RAVE', 'RAVE featured playlists');
  String get upcomingEvents => _('Event mendatang', 'Upcoming events');
  String eventsIn(String city) => _('Event di $city', 'Events in $city');

  // Jelajahi & kategori (sama dengan /app/search & /app/genre di web)
  String get browseAll => _('Jelajahi semua', 'Browse all');
  String get popularSongs => _('Lagu populer', 'Popular songs');
  String get releasesTitle => _('Rilisan', 'Releases');
  String get noContentInCategory => _('Kategori ini masih kosong — coba intip yang lain.', 'Nothing here yet — try another category.');
  String get storiesTab => _('Cerita & Fiksi', 'Stories & Fiction');

  // Live (sama dengan /app/live di web)
  String get live => 'Live';
  String get showAll => _('Lihat semua', 'Show all');
  String get liveNow => _('Sedang live', 'Live now');
  String get liveNowEyebrow => _('Sedang tayang', 'On air now');
  String get liveUpcoming => _('Akan datang', 'Upcoming');
  String get livePast => _('Siaran sebelumnya', 'Past streams');
  String get liveNoScheduled => _('Belum ada siaran terjadwal. Cek lagi nanti ya.', 'No streams scheduled yet. Check back soon.');
  String get liveNobody => _('Lagi sepi, belum ada yang live', 'Nobody’s live right now');
  String get liveNobodyBody => _('Jadwal siaran berikutnya ada di bawah.', 'Upcoming streams are listed below.');
  String get liveUnavailable => _('Live lagi istirahat dulu', 'Live is taking a break');
  String get liveInterrupted => _('Terputus', 'Interrupted');
  String get liveAired => _('Sudah tayang', 'Aired');
  String get liveSoon => _('Segera', 'Soon');
  String get liveTicket => _('Tiket', 'Ticket');
  String get liveFree => _('Gratis', 'Free');
  String get liveTicketHolders => _('Khusus pemegang tiket', 'Ticket holders only');
  String get liveEnded => _('Siaran selesai', 'Stream ended');
  String livePeak(String n) => _('Puncak $n penonton', 'Peak of $n viewers');
  String get liveSeeOther => _('Lihat siaran lain', 'See other streams');
  String get liveSignInToWatch => _('Masuk untuk menonton', 'Sign in to watch');
  String get liveRequiresAccount => _('Siaran ini butuh akun RAVE — daftar gratis kok.', 'This stream needs a RAVE account — it’s free.');
  String livePartOfEvent(String e) => _('Bagian dari event $e.', 'Part of the event $e.');
  String get liveRequiresTicket => _('Siaran ini butuh tiket.', 'This stream needs a ticket.');
  String get liveBuyTicket => _('Beli tiket', 'Buy ticket');
  String get liveNotStarted => _('Belum dimulai', 'Not started yet');
  String liveScheduled(String t) => _('Dijadwalkan $t', 'Scheduled for $t');
  String get liveStartingSoon => _('Segera dimulai', 'Starting soon');
  String get liveAutoPlay => _('Pemutar muncul sendiri begitu siaran mulai.', 'The player shows up as soon as the stream starts.');
  String get liveWaiting => _('Menunggu siaran…', 'Waiting for the stream…');
  String get liveReconnecting => _('Menyambung ulang…', 'Reconnecting…');
  String get liveNotFound => _('Siarannya nggak ketemu', 'Couldn’t find that stream');
  String get liveChat => _('Chat langsung', 'Live chat');
  String get liveChatEmpty => _('Belum ada pesan. Sapa duluan, yuk!', 'No messages yet. Say hi!');
  String get liveChatHint => _('Kirim pesan…', 'Send a message…');
  String get liveChatSignIn => _('Masuk untuk ikut chat', 'Sign in to chat');
  String liveSlowmode(int s) => _('Mode lambat — tunggu $s dtk', 'Slow mode — wait ${s}s');
  String liveStarted(String t) => _('Mulai $t', 'Started $t');
  String get search => _('Cari', 'Search');
  String get library => _('Koleksi', 'Collection');
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
  String codeSent(String e) => _('Kode 6 digit sudah dikirim ke $e. Cek inbox (atau folder spam) ya.', 'We sent a 6-digit code to $e. Check your inbox (or spam).');
  String get code => _('Kode', 'Code');
  String get signIn => _('Masuk', 'Sign in');
  /// Satu pintu masuk (OTP: akun baru dibuat otomatis) — sama dengan desktop.
  String get signInOrUp => _('Masuk / Daftar', 'Sign in / Sign up');
  String get authTitle => _('Masuk atau daftar', 'Sign in or sign up');
  String get logIn => _('Masuk', 'Sign in');
  String get signUp => _('Daftar', 'Sign up');
  String get signUpTitle => _('Daftar gratis', 'Sign up free');
  String get settingsGuestTitle => _('Masuk dulu buat atur RAVE', 'Sign in to set up RAVE');
  String get settingsGuestBody => _('Kualitas audio, tema, notifikasi, dan privasi tersimpan di akunmu. Masuk atau daftar gratis, cuma sebentar.',
      'Audio quality, theme, notifications and privacy live in your account. Sign in or sign up free — it only takes a sec.');
  String get premiumAudioTitle => _('Kualitas audio tinggi & Equalizer', 'Higher audio quality & Equalizer');
  String get premiumAudioBody => _('AAC 320, Lossless FLAC, dan equalizer 6-band ada di Premium.', 'AAC 320, Lossless FLAC and a 6-band equalizer come with Premium.');
  String get authBody => _('Cukup email — kami kirim kode 6 digit. Baru di sini? Akunmu langsung dibuat, tanpa kata sandi.', 'Just your email — we’ll send a 6-digit code. New here? We’ll set up your account, no password needed.');
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
  String obPicked(int n) => n == 0 ? _('Pilih satu atau lebih.', 'Pick one or more.') : _('$n dipilih', '$n picked');
  String get obArtistTitle => _('Pilih 3 artis atau lebih', 'Pick 3 or more artists');
  String obArtistsPicked(int n) => n >= 3 ? _('$n artis dipilih — mantap!', '$n artists picked — nice!') : _('$n/3 dipilih', '$n/3 picked');
  String get obReadyTitle => _('Siap dengar!', 'Ready to listen!');
  String obReadySummary(String c, int g, int a) => _('$c · $g genre · $a artis — berandamu sudah dipersonalisasi.', '$c · $g genres · $a artists — your home is personalised.');
  String get obSkip => _('Lewati', 'Skip');
  String get obGuest => _('Jelajahi dulu', 'Just browse');
  String get haveAccount => _('Sudah punya akun? Masuk', 'Already have an account? Sign in');
  String get guest => _('Tamu', 'Guest');
  String get guestTitle => _('Masuk dulu, yuk', 'Sign in to keep going');
  String get guestBody => _('Simpan lagu favorit, rakit koleksimu, ikuti artis, dan dengar lagu penuh — gratis.', 'Save favourites, build your collection, follow artists and hear full songs — free.');
  String get guestBanner => _('Kamu lagi dengar sebagai tamu — cuma cuplikan 30 detik. Daftar gratis buat lagu penuh.', 'You’re listening as a guest — 30-second previews only. Sign up free for full songs.');

  // Umum
  String get play => _('Putar', 'Play');
  String get pause => _('Jeda', 'Pause');
  String get shuffle => _('Acak', 'Shuffle');
  String get follow => _('Ikuti', 'Follow');
  String get following => _('Mengikuti', 'Following');
  String get save => _('Simpan', 'Save');
  String get saved => _('Tersimpan', 'Saved');
  String get retry => _('Coba lagi', 'Try again');
  String get offline => _('Nggak bisa nyambung ke RAVE. Cek koneksimu, lalu coba lagi ya.', 'Can’t reach RAVE. Check your connection and try again.');
  String get empty => _('Masih kosong di sini. Yuk, mulai isi!', 'Nothing here yet. Let’s fill it up!');
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
  String addedQueue(String t) => _('$t masuk antrean', '$t added to queue');
  String get like => _('Sukai', 'Like');
  String get unlike => _('Hapus dari Lagu yang Disukai', 'Remove from Liked Songs');
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
  String get searchHint => _('Mau dengar apa?', 'What do you want to listen to?');
  String get browse => _('Jelajahi', 'Browse');
  String get topResult => _('Hasil teratas', 'Top result');
  String get artists => _('Artis', 'Artists');
  String get albums => _('Album', 'Albums');
  String get podcasts => 'Podcast';
  String noResults(String q) => _('Nggak ketemu apa-apa untuk “$q”. Coba kata lain?', 'Nothing found for “$q”. Try another word?');

  // Koleksi
  String get playlists => 'Playlist';
  String get emptyArtists => _('Belum ada artis yang kamu ikuti', 'No artists followed yet');
  String get emptyArtistsBody => _('Temukan band favoritmu, lalu ketuk Ikuti biar nggak ketinggalan rilisan barunya.', 'Find a band you love and tap Follow so you never miss a release.');
  String get emptyAlbums => _('Belum ada album tersimpan', 'No saved albums yet');
  String get emptyAlbumsBody => _('Simpan album yang kamu suka biar gampang diputar lagi.', 'Save albums you love so they’re easy to play again.');
  String get emptyPlaylist => _('Playlist ini masih kosong', 'This playlist is empty');
  String get emptyPlaylistBody => _('Cari lagu, lalu tambahkan lewat menu ⋮ di barisnya.', 'Find a song, then add it from the ⋮ menu on its row.');
  String get findMusic => _('Cari musik', 'Find music');
  String likedSub(int n) => 'Playlist · ${songs(n)}';

  // Pemutar
  String get nowPlaying => _('Sedang Diputar', 'Now Playing');
  String get queue => _('Antrean', 'Queue');
  String get lyrics => _('Lirik', 'Lyrics');
  String get nextUp => _('Berikutnya', 'Next up');
  // Buat / playlist
  String get create => _('Buat', 'Create');
  String get createPlaylist => 'Playlist';
  String get createPlaylistHint => _('Kumpulin lagu favoritmu dalam satu playlist.', 'Gather your favourite songs in one playlist.');
  String get namePlaylist => _('Kasih nama playlist', 'Name your playlist');
  String get myPlaylist => _('Playlist-ku', 'My playlist');
  String get cancel => _('Batal', 'Cancel');
  String get addToPlaylist => _('Tambah ke playlist', 'Add to playlist');
  String get newPlaylist => _('Playlist baru', 'New playlist');
  String addedTo(String p) => _('Ditambahkan ke $p', 'Added to $p');
  String playlistCreated(String p) => _('Playlist “$p” dibuat', 'Playlist “$p” created');
  String get yourLibrary => _('Koleksi Kamu', 'Your Collection');
  // Premium
  String get premiumHero1 => _('Musik tetap gratis.', 'Music stays free.');
  String get premiumHero2 => _('Premium untuk sisanya.', 'Premium for the rest.');
  String premiumLead(String price) => _('Kualitas Tinggi (AAC 320) & Lossless/Hi-Res (FLAC), podcast & fiksi eksklusif, tanpa iklan — mulai Rp $price per bulan.',
      'High Quality (AAC 320) & Lossless/Hi-Res (FLAC), exclusive podcasts & fiction, no ads — from Rp $price a month.');
  String get alreadyPremium => _('Kamu sudah Premium', 'You’re on Premium');
  String get remindMe => _('Kabari aku', 'Notify me');
  String get remindSaved => _('Siap! Kami kabari begitu Premium dibuka.', 'You’re on the list — we’ll let you know when Premium opens.');
  String premiumNote(int trial) => _('Dibuka bertahap setelah closed beta${trial > 0 ? ' · Gratis $trial hari untuk pelanggan pertama' : ''} · Bisa berhenti kapan saja',
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
  String get noQueue => _('Antrean masih kosong. Putar sesuatu, nanti lagu berikutnya muncul di sini.', 'Your queue is empty. Play something and what’s next shows up here.');
  String get noLyrics => _('Liriknya belum ada. Nikmati musiknya dulu ya.', 'No lyrics for this one yet — just enjoy the music.');
  String get playingFrom => _('MEMUTAR DARI', 'PLAYING FROM');
  String get previewEnded => _('Cuplikan 30 detik selesai. Daftar gratis buat lanjut dengar.', 'That’s the 30-second preview. Sign up free to keep listening.');
  String get premiumQuality => _('HQ & Lossless ada di Premium — sekarang diputar kualitas standar.', 'HQ & Lossless come with Premium — playing in standard quality for now.');
  String get premiumEpisode => _('Episode ini khusus Premium.', 'This episode is Premium-only.');
  String get streamLost => _('Putaran terputus. Ketuk buat coba lagi.', 'Playback dropped. Tap to try again.');
  String get ad => _('Iklan', 'Ad');
  String get houseAd => 'Dari RAVE';
  String get open => _('Buka', 'Open');
  String get qualityDisabled => _('Kualitas tinggi lagi dimatikan — sekarang diputar kualitas standar.', 'High quality is switched off for now — playing in standard quality.');
  String get qualityUnavailable => _('Kualitas pilihanmu belum tersedia untuk lagu ini.', 'Your chosen quality isn’t available for this song yet.');
  // Privasi (UU PDP)
  String get privacy => _('Privasi & data', 'Privacy & data');
  String get privacyHint => _('Atur cara RAVE memakai datamu. Bisa kamu ubah kapan saja.', 'Choose how RAVE uses your data. You can change this anytime.');
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
  String get deleteBody => _('Akun, koleksi, playlist, dan riwayat dengarmu akan dihapus permanen. Ini tidak bisa dibatalkan.', 'Your account, collection, playlists and listening history will be permanently deleted. This can’t be undone.');
  String get deleteConfirm => _('Ya, hapus permanen', 'Yes, delete permanently');
  String get deleted => _('Akunmu sudah dihapus.', 'Your account has been deleted.');
  String get skip => _('Lewati', 'Skip');
  String skipIn(int s) => _('Lewati dalam $s', 'Skip in $s');
  String get adWhy => _('Iklan bantu artis tetap dibayar. Premium bebas iklan.', 'Ads help keep artists paid. Premium is ad-free.');

  // Pengaturan
  String get account => _('Akun', 'Account');
  String get logout => _('Keluar', 'Sign out');
  String get premiumActive => _('Premium aktif', 'Premium active');
  String get free => _('Gratis (dengan iklan)', 'Free (with ads)');
  String get serverHint => _('Alamat gateway RAVE, mis. https://rave.id. Buat uji lokal: server demo di PC (port 8080).', 'RAVE gateway address, e.g. https://rave.id. For local testing: the demo server on your PC (port 8080).');
  String get serverInvalid => _('Alamat server belum pas — awali dengan http:// atau https://.', 'That server address doesn’t look right — start it with http:// or https://.');
  String get serverSaved => _('Server tersimpan.', 'Server saved.');
  String get serverDown => _('RAVE belum tersambung — kami coba lagi otomatis', 'Can’t reach RAVE — retrying automatically');
  String serverUnreachable(String name) => _('$name juga belum bisa dihubungi.', 'Can’t reach $name either.');
  String useServer(String name) => _('Pakai $name', 'Use $name');
  String get onboardingOfflineHint => _('Daftar artis butuh koneksi ke server. Coba lagi, ganti server, atau LEWATI dulu — bisa diatur nanti.', 'The artist list needs a connection. Try again, switch server, or SKIP for now — you can set it later.');
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
  String get dataSaverHint => _('Selalu putar kualitas rendah (64 kbps) — hemat kuota seluler.', 'Always stream in low quality (64 kbps) — easy on mobile data.');
  String version(String v) => 'RAVE Mobile $v · © 2026 RAVE · dijiwa.id';

  // ---- Beranda: chip & Mulai di RAVE (sama dengan web Home.tsx / GettingStarted.tsx) ----
  String get chipsLabel => _('Saring beranda', 'Filter home');
  String chip(String k) => switch (k) {
        'music' => _('Musik', 'Music'),
        'artists' => _('Artis', 'Artists'),
        'podcasts' => 'Podcast',
        'live' => 'Live',
        'events' => _('Event', 'Events'),
        _ => _('Semua', 'All'),
      };
  String get filterEmpty => _('Belum ada yang bisa ditampilkan di sini. Coba kategori lain.', 'Nothing to show here yet. Try another category.');
  String get gsTitle => _('Mulai di RAVE', 'Getting started');
  String gsStepOf(int i, int n) => _('Langkah $i dari $n', 'Step $i of $n');
  String get gsNext => _('Tips berikutnya', 'Next tip');
  String get gsRestart => _('Ulang dari awal', 'Start over');
  ({String title, String body, String cta}) gsStep(String k) => switch (k) {
        'play' => (title: _('Mulai memutar', 'Start playing'), body: _('Cari, jelajahi, dan putar artis DIY & indie favoritmu.', 'Search, browse and play your favourite DIY & indie artists.'), cta: _('Cari', 'Search')),
        'like' => (title: _('Simpan yang kena', 'Save what hits'), body: _('Tekan ♥ di pemutar — lagunya terkumpul di Lagu yang Disukai.', 'Tap ♥ in the player — songs collect in Liked Songs.'), cta: _('Lagu Disukai', 'Liked Songs')),
        'playlist' => (title: _('Rakit mixtape', 'Make a mixtape'), body: _('Bikin playlist sendiri dan atur urutannya sesuka hati.', 'Build your own playlists and order them however you like.'), cta: _('Buka Koleksi', 'Open Collection')),
        'follow' => (title: _('Ikuti artis', 'Follow artists'), body: _('Dapat kabar rilis baru dan jadwal manggung lebih dulu.', 'Hear about new releases and gig dates first.'), cta: _('Lihat artis', 'See artists')),
        'live' => (title: _('Nonton live', 'Watch live'), body: _('Sesi live dari studio & panggung, langsung dari artisnya.', 'Live sessions from studios & stages, straight from the artists.'), cta: _('Buka Live', 'Open Live')),
        _ => (title: _('Datang ke gig', 'Go to a gig'), body: _('Temukan event di kotamu dan amankan tiketnya di sini.', 'Find events in your city and grab tickets right here.'), cta: _('Lihat event', 'See events')),
      };
  String madeFor(String name) => _('Pilihan untuk $name', 'Picks for $name');
  String get madeForGuest => _('Pilihan RAVE', 'RAVE picks');
  String get nowOnAir => _('Sedang Diputar', 'Now Playing');
  String get paused => _('Dijeda', 'Paused');

  // ---- Umpan balik: stiker toast & dialog konfirmasi (web components/ui ToastCard/confirmDialog) ----
  String get toastOk => _('Beres!', 'Done!');
  String get toastErr => _('Waduh', 'Oops');
  String get toastInfo => _('Catat', 'Heads up');
  String get close => _('Tutup', 'Close');
  String get undo => _('Urungkan', 'Undo');
  String get confirmKicker => _('Konfirmasi', 'Confirm');
  String get likedToast => _('Masuk ke Lagu yang Disukai', 'Added to Liked Songs');
  String get unlikedToast => _('Dihapus dari Lagu yang Disukai', 'Removed from Liked Songs');
  String followedToast(String n) => _('Kamu sekarang mengikuti $n', "You're now following $n");
  String unfollowedToast(String n) => _('Berhenti mengikuti $n', 'Unfollowed $n');
  String get savedToast => _('Disimpan ke Koleksi Kamu', 'Saved to Your Collection');
  String get unsavedToast => _('Dihapus dari Koleksi Kamu', 'Removed from Your Collection');
  String get pullToRefresh => _('Tarik untuk segarkan', 'Pull to refresh');
  String get releaseToRefresh => _('Lepas untuk segarkan', 'Release to refresh');
  String get refreshing => _('Lagi disegarkan…', 'Refreshing…');
  String get nowSpinning => _('Pita berputar', 'Now spinning');
  String get shuffleOn => _('Acak aktif — urutan dikocok', 'Shuffle on — order mixed up');
  String get shuffleOff => _('Acak dimatikan', 'Shuffle off');
  String get repeatAllToast => _('Ulangi semua', 'Repeat all');
  String get repeatOneToast => _('Ulangi satu lagu', 'Repeat one song');
  String get repeatOffToast => _('Ulangi dimatikan', 'Repeat off');
  String get deletePlaylist => _('Hapus playlist', 'Delete playlist');
  String get deletePlaylistTitle => _('Hapus playlist?', 'Delete playlist?');
  String deletePlaylistBody(String t, int n) => _('“$t” (${songs(n)}) akan dihapus dari Koleksi Kamu dan tidak bisa dikembalikan. Lagu-lagunya tetap ada di RAVE.',
      '“$t” (${songs(n)}) will be removed from Your Collection and can’t be restored. The songs stay on RAVE.');
  String playlistDeleted(String t) => _('“$t” sudah dihapus', '“$t” deleted');
  String get genericError => _('Waduh, ada yang error. Coba lagi ya.', 'Oops, something went wrong — try again?');
  String get losslessPending => _('Versi Lossless lagu ini lagi disiapkan — sementara diputar AAC 320.', 'The Lossless version is on its way — playing AAC 320 for now.');
  String get losslessPendingShort => _('Lossless disiapkan · AAC 320', 'Lossless on the way · AAC 320');

  // ---- Pengaturan (web pages/fan/Settings.tsx) ----
  String get searchSettings => _('Cari pengaturan', 'Search settings');
  String noSettings(String q) => _('Nggak ada pengaturan untuk “$q”', 'No settings match “$q”');
  String section(String k) => switch (k) {
        'account' => _('Akun', 'Account'),
        'language' => _('Bahasa', 'Language'),
        'audio' => _('Kualitas audio', 'Audio quality'),
        'eq' => 'Equalizer',
        'library' => _('Koleksi', 'Collection'),
        'display' => _('Tampilan', 'Display'),
        'playback' => _('Pemutaran', 'Playback'),
        'premium' => 'Premium',
        'notifications' => _('Notifikasi', 'Notifications'),
        'privacy' => _('Privasi', 'Privacy'),
        'danger' => _('Zona bahaya', 'Danger zone'),
        _ => _('Lainnya', 'Other'),
      };
  String get languageRow => _('Bahasa aplikasi', 'App language');
  String get languageRowHint => _('Langsung berlaku & tersimpan di akunmu.', 'Applies right away & saves to your account.');
  String get emailRow => _('Email akun', 'Account email');
  String get emailRowHint => _('Dipakai buat masuk dengan kode OTP.', 'Used to sign in with a one-time code.');
  String get qualityRowHint => _('Berlaku mulai lagu berikutnya.', 'Kicks in from the next song.');
  String qDesc(String k) => switch (k) {
        'low' => _('AAC 64 kbps — paling irit kuota', 'AAC 64 kbps — uses the least data'),
        'normal' => 'AAC 160 kbps',
        'high' => 'AAC 320 kbps',
        'lossless' => _('FLAC — enaknya pakai Wi-Fi', 'FLAC — best on Wi-Fi'),
        _ => _('Menyesuaikan jaringan (disarankan)', 'Adapts to your network (recommended)'),
      };
  String losslessCap(String res) => _('FLAC hingga $res${res.startsWith('24-bit/96') ? ' (Hi-Res)' : ''} — enaknya pakai Wi-Fi', 'FLAC up to $res${res.startsWith('24-bit/96') ? ' (Hi-Res)' : ''} — best on Wi-Fi');
  String freeQualityNote(String q) => _('Akun Gratis diputar sampai $q.', 'Free accounts play up to $q.');
  String get premiumQualityCta => _('Lihat Premium', 'See Premium');
  String get normalizeRow => _('Normalisasi volume', 'Volume normalisation');
  String get normalizeHint => _('Volume semua lagu & podcast dibuat setara, pakai data loudness RAVE.', 'Keeps songs & podcasts at the same volume, using RAVE loudness data.');
  String get eqRow => 'Equalizer';
  String get eqHint => _('Atur karakter suara biar pas di speaker atau headphone-mu. Tersimpan di perangkat ini.', 'Tune the sound to suit your speakers or headphones. Saved on this device.');
  String eqPreset(String k) => switch (k) {
        'bass' => 'Bass boost',
        'vocal' => _('Vokal', 'Vocal'),
        'acoustic' => _('Akustik', 'Acoustic'),
        'electronic' => _('Elektronik', 'Electronic'),
        'treble' => 'Treble',
        'custom' => _('Kustom', 'Custom'),
        _ => _('Datar', 'Flat'),
      };
  String get eqPremium => _('Equalizer ada di Premium.', 'The Equalizer comes with Premium.');
  String get eqPremiumCta => _('Buka di Premium', 'Unlock with Premium');
  String get eqReset => _('Atur ulang', 'Reset');
  String get eqOffNote => _('Nyalakan Equalizer dulu buat ubah kurvanya.', 'Turn the Equalizer on to edit the curve.');
  String get eqWaiting => _('Putar satu lagu dulu, nanti pita Equalizer perangkatmu muncul.', 'Play a song first to load your device’s Equalizer bands.');
  String get eqUnavailable => _('Equalizer belum didukung di perangkat ini — musik tetap jalan normal.', 'The Equalizer isn’t supported on this device — playback works as usual.');
  String get compactRow => _('Koleksi ringkas', 'Compact collection');
  String get compactHint => _('Baris Koleksi lebih rapat, sampulnya kecil.', 'Tighter Collection rows with small covers.');
  String get themeRow => _('Tema', 'Theme');
  String get themeHint => _('Gelap klasik RAVE atau Terang ala poster kertas berwarna. Tersimpan di akunmu — ikut ke web & desktop.',
      'Classic RAVE dark or a colourful paper-poster light. Saved to your account — follows you to web & desktop.');
  String get themeHintGuest => _('Gelap klasik RAVE atau Terang ala poster kertas berwarna. Tersimpan di perangkat ini.', 'Classic RAVE dark or a colourful paper-poster light. Saved on this device.');
  String get themeLocked => _('Tema diatur oleh admin platform.', 'The theme is set by the platform admin.');
  String themeName(String k) => switch (k) {
        'light' => _('Terang', 'Light'),
        'system' => _('Ikuti sistem', 'Match system'),
        _ => _('Gelap', 'Dark'),
      };
  String get vinylRow => _('Animasi piringan', 'Vinyl animation');
  String get vinylHint => _('Piringan hitam menyembul & berputar di layar Sedang Diputar.', 'The record slides out and spins on the Now Playing screen.');
  String get notifIntro => _('Notifikasi di aplikasi selalu tersimpan. Pilih kanal tambahan per kategori.', 'In-app notifications are always kept. Pick extra channels per category.');
  String get notifFailed => _('Preferensi notifikasi gagal dimuat. Coba lagi sebentar lagi.', 'Couldn’t load notification settings. Try again in a bit.');
  ({String name, String desc}) notifCategory(String k) => switch (k) {
        'event' => (name: _('Event & live', 'Events & live'), desc: _('Manggung dekatmu, siaran live, dan tiket.', 'Gigs near you, live streams, and tickets.')),
        'release' => (name: _('Rilis baru', 'New releases'), desc: _('Lagu & album baru dari artis yang kamu ikuti.', 'New songs & albums from artists you follow.')),
        'payment' => (name: _('Pembayaran', 'Payments'), desc: _('Status pembayaran, pengembalian dana, dan pencairan.', 'Payment status, refunds, and payouts.')),
        'booking' => (name: 'Booking', desc: _('Inquiry, offer, dan status booking (artis & promotor).', 'Inquiries, offers, and booking status (artists & promoters).')),
        'system' => (name: _('Akun & sistem', 'Account & system'), desc: _('Keamanan akun, verifikasi, dan pengumuman penting.', 'Account security, verification, and important announcements.')),
        _ => (name: _('Sosial', 'Social'), desc: _('Aktivitas pengikut & playlist kolaborasi.', 'Follower activity & collaborative playlists.')),
      };
  String get dangerNote => _('Tindakan di sini permanen.', 'Actions here are permanent.');
  String get signInForSetting => _('Masuk dulu buat ubah ini.', 'Sign in to change this.');
}
