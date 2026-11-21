// Kontrak API RAVE (gateway /v1) yang dipakai aplikasi mobile — subset dari apps/web/src/lib/types.ts.

typedef Json = Map<String, dynamic>;

List<T> _list<T>(dynamic v, T Function(Json) f) => (v as List? ?? const []).map((e) => f(e as Json)).toList();

class Me {
  final String id, email, displayName;
  final String? avatarUrl, locale;
  final bool premium, onboarded;
  final String? city;
  /// Tema aplikasi dengar tersimpan di akun: `light` · `dark` · `system` · null (ikut default platform).
  final String? theme;

  /// Data profil lengkap (verifikasi akun). [birthDate] = `YYYY-MM-DD`; [gender] = male|female|other|undisclosed.
  final String? phone, fullName, birthDate, gender, bio;

  /// NIK tersamar dari server (mis. `************3456`) — nilai asli tidak pernah dikirim balik.
  final String? idNumberMasked;
  final List<String> socials;

  /// Badge Verified tampil hanya bila [verified]. [verificationStatus] = NONE|PENDING|VERIFIED|REJECTED — VERIFIED juga
  /// berarti identitas (KYC) disetujui; akun KYC lama bisa VERIFIED tanpa badge sampai data dirinya lengkap.
  final bool verified;
  final String? verifiedAt;
  final String verificationStatus;

  /// Verifikasi 2 langkah (aplikasi authenticator) aktif.
  final bool totpEnabled;

  const Me({
    required this.id,
    required this.email,
    required this.displayName,
    this.avatarUrl,
    this.locale,
    this.premium = false,
    this.onboarded = true,
    this.city,
    this.theme,
    this.phone,
    this.fullName,
    this.birthDate,
    this.gender,
    this.bio,
    this.idNumberMasked,
    this.socials = const [],
    this.verified = false,
    this.verifiedAt,
    this.verificationStatus = 'NONE',
    this.totpEnabled = false,
  });

  /// Toleran terhadap profil tersimpan versi lama (kolom baru tidak ada → bawaan).
  factory Me.fromJson(Json j) {
    final verified = j['verified'] == true;
    final status = j['verification_status'];
    return Me(
      id: j['id'],
      email: j['email'] ?? '',
      displayName: j['display_name'] ?? '',
      avatarUrl: j['avatar_url'],
      locale: j['locale'],
      premium: j['premium'] == true,
      onboarded: j['onboarded'] != false,
      city: j['city'],
      theme: j['theme'] as String?,
      phone: j['phone'] as String?,
      fullName: j['full_name'] as String?,
      birthDate: j['birth_date'] as String?,
      gender: j['gender'] as String?,
      bio: j['bio'] as String?,
      idNumberMasked: j['id_number_masked'] as String?,
      socials: (j['socials'] as List? ?? const []).whereType<String>().toList(),
      verified: verified,
      verifiedAt: j['verified_at'] as String?,
      verificationStatus: status is String && status.isNotEmpty ? status : (verified ? 'VERIFIED' : 'NONE'),
      totpEnabled: j['totp_enabled'] == true || j['mfa_enabled'] == true,
    );
  }
  Json toJson() => {
        'id': id,
        'email': email,
        'display_name': displayName,
        'avatar_url': avatarUrl,
        'locale': locale,
        'premium': premium,
        'onboarded': onboarded,
        'city': city,
        'theme': theme,
        'phone': phone,
        'full_name': fullName,
        'birth_date': birthDate,
        'gender': gender,
        'bio': bio,
        'id_number_masked': idNumberMasked,
        'socials': socials,
        'verified': verified,
        'verified_at': verifiedAt,
        'verification_status': verificationStatus,
        'totp_enabled': totpEnabled,
      };

  Me withTheme(String? t) => Me.fromJson({...toJson(), 'theme': t});
}

class ArtistRef {
  final String id, name, slug;
  const ArtistRef(this.id, this.name, this.slug);
  factory ArtistRef.fromJson(Json j) => ArtistRef(j['id'], j['name'] ?? '', j['slug'] ?? j['id']);
}

class Track {
  final String id, title;
  final int durationMs, trackNumber;
  final bool explicit, hasLyrics;
  final ArtistRef artist;
  final String releaseId, releaseTitle;
  final String? coverUrl;
  const Track({
    required this.id,
    required this.title,
    required this.durationMs,
    required this.trackNumber,
    required this.explicit,
    required this.hasLyrics,
    required this.artist,
    required this.releaseId,
    required this.releaseTitle,
    this.coverUrl,
  });
  factory Track.fromJson(Json j) {
    final r = (j['release'] as Json?) ?? const {};
    return Track(
      id: j['id'],
      title: j['title'] ?? '',
      durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
      trackNumber: (j['track_number'] as num?)?.toInt() ?? 0,
      explicit: j['explicit'] == true,
      hasLyrics: j['has_lyrics'] == true,
      artist: ArtistRef.fromJson(j['artist'] as Json),
      releaseId: r['id'] ?? '',
      releaseTitle: r['title'] ?? '',
      coverUrl: r['cover_url'],
    );
  }
}

class ReleaseSummary {
  final String id, title, type, releaseDate;
  final String? coverUrl;
  final ArtistRef artist;
  const ReleaseSummary({required this.id, required this.title, required this.type, required this.releaseDate, this.coverUrl, required this.artist});
  factory ReleaseSummary.fromJson(Json j) => ReleaseSummary(
        id: j['id'],
        title: j['title'] ?? '',
        type: j['type'] ?? 'ALBUM',
        releaseDate: j['release_date'] ?? '',
        coverUrl: j['cover_url'],
        artist: ArtistRef.fromJson(j['artist'] as Json),
      );
  String get year => releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '';
}

class Release extends ReleaseSummary {
  final String? label, genre;
  final List<Track> tracks;
  Release({required super.id, required super.title, required super.type, required super.releaseDate, super.coverUrl, required super.artist, this.label, this.genre, required this.tracks});
  factory Release.fromJson(Json j) {
    final s = ReleaseSummary.fromJson(j);
    return Release(id: s.id, title: s.title, type: s.type, releaseDate: s.releaseDate, coverUrl: s.coverUrl, artist: s.artist, label: j['label'], genre: j['genre'], tracks: _list(j['tracks'], Track.fromJson));
  }
}

class ArtistSummary {
  final String id, slug, name;
  final String? imageUrl, city;
  final List<String> genres;
  final bool verified;
  final int monthlyListeners;
  const ArtistSummary({required this.id, required this.slug, required this.name, this.imageUrl, this.city, this.genres = const [], this.verified = false, this.monthlyListeners = 0});
  factory ArtistSummary.fromJson(Json j) => ArtistSummary(
        id: j['id'],
        slug: j['slug'] ?? j['id'],
        name: j['name'] ?? '',
        imageUrl: j['image_url'],
        city: j['city'],
        genres: (j['genres'] as List? ?? const []).cast<String>(),
        verified: j['verified'] == true,
        monthlyListeners: (j['monthly_listeners'] as num?)?.toInt() ?? 0,
      );
}

class Artist extends ArtistSummary {
  final String? bio, coverUrl;
  final int followers;
  final List<Track> topTracks;
  final List<ReleaseSummary> releases;
  Artist({required super.id, required super.slug, required super.name, super.imageUrl, super.city, super.genres, super.verified, super.monthlyListeners, this.bio, this.coverUrl, this.followers = 0, required this.topTracks, required this.releases});
  factory Artist.fromJson(Json j) {
    final s = ArtistSummary.fromJson(j);
    return Artist(
      id: s.id,
      slug: s.slug,
      name: s.name,
      imageUrl: s.imageUrl,
      city: s.city,
      genres: s.genres,
      verified: s.verified,
      monthlyListeners: s.monthlyListeners,
      bio: j['bio'],
      coverUrl: j['cover_url'],
      followers: (j['followers'] as num?)?.toInt() ?? 0,
      topTracks: _list(j['top_tracks'], Track.fromJson),
      releases: _list(j['releases'], ReleaseSummary.fromJson),
    );
  }
}

class PlaylistSummary {
  final String id, title;
  final String? description, coverUrl, ownerName, ownerId;
  final int trackCount;
  const PlaylistSummary({required this.id, required this.title, this.description, this.coverUrl, this.ownerName, this.ownerId, this.trackCount = 0});
  factory PlaylistSummary.fromJson(Json j) {
    final o = j['owner'] as Json?;
    return PlaylistSummary(
      id: j['id'],
      title: j['title'] ?? '',
      description: j['description'],
      coverUrl: j['cover_url'],
      ownerName: o?['display_name'] ?? o?['name'],
      ownerId: o?['id'],
      trackCount: (j['track_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class EpisodeEmbed {
  final String provider, src, kind;
  final int height;
  const EpisodeEmbed({required this.provider, required this.src, required this.kind, required this.height});
  static EpisodeEmbed? fromJson(Object? j) {
    if (j is! Map) return null;
    final src = j['src'];
    // Hanya https — server sudah memvalidasi host; ini pengaman tambahan di klien.
    if (src is! String || !src.startsWith('https://')) return null;
    return EpisodeEmbed(provider: '${j['provider'] ?? ''}', src: src, kind: j['kind'] == 'video' ? 'video' : 'audio', height: (j['height'] as num?)?.toInt() ?? 166);
  }
}

class Episode {
  final String id, showId, title;
  final String? description, coverUrl;
  final int durationMs;
  final String publishedAt;
  final bool premium;
  /// Episode embed (iframe platform lain): diputar di [EmbedPlayer], bukan pemutar RAVE.
  final EpisodeEmbed? embed;
  bool get isEmbed => embed != null;
  const Episode({required this.id, required this.showId, required this.title, this.description, this.coverUrl, required this.durationMs, required this.publishedAt, this.premium = false, this.embed});
  factory Episode.fromJson(Json j) => Episode(
        id: j['id'],
        showId: j['show_id'] ?? '',
        title: j['title'] ?? '',
        description: j['description'],
        coverUrl: j['cover_url'],
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
        publishedAt: j['published_at'] ?? '',
        premium: j['is_premium'] == true,
        embed: j['source'] == 'embed' ? EpisodeEmbed.fromJson(j['embed']) : null,
      );
}

class Show {
  final String id, title, publisher, category;
  final String? description, coverUrl;
  final bool contentWarning;
  final List<Episode> episodes;
  const Show({required this.id, required this.title, required this.publisher, required this.category, this.description, this.coverUrl, this.contentWarning = false, this.episodes = const []});
  factory Show.fromJson(Json j) => Show(
        id: j['id'],
        title: j['title'] ?? '',
        publisher: j['publisher'] ?? '',
        category: j['category'] ?? '',
        description: j['description'],
        coverUrl: j['cover_url'],
        contentWarning: j['content_warning'] == true,
        episodes: _list(j['episodes'], Episode.fromJson),
      );
}

/// Kartu beranda (quick picks & rak).
class MediaItem {
  final String id, kind, title, subtitle, href;
  final String? imageUrl;
  const MediaItem({required this.id, required this.kind, required this.title, required this.subtitle, required this.href, this.imageUrl});
  factory MediaItem.fromJson(Json j) => MediaItem(id: j['id'], kind: j['kind'] ?? '', title: j['title'] ?? '', subtitle: j['subtitle'] ?? '', href: j['href'] ?? '', imageUrl: j['image_url']);

  /// `/app/artist/:slug` → slug (endpoint artis menerima id atau slug).
  String get targetId {
    final m = RegExp(r'^/app/[a-z]+/([^/?#]+)').firstMatch(href);
    return m != null ? Uri.decodeComponent(m.group(1)!) : id;
  }
}

class HomeData {
  final List<MediaItem> quickPicks;
  final List<({String id, String title, String kind, List<MediaItem> items})> sections;
  const HomeData(this.quickPicks, this.sections);
  factory HomeData.fromJson(Json j) => HomeData(
        _list(j['quick_picks'], MediaItem.fromJson),
        (j['sections'] as List? ?? const [])
            .map((s) => (id: s['id'] as String, title: s['title'] as String, kind: s['kind'] as String, items: _list(s['items'], MediaItem.fromJson)))
            .toList(),
      );
}

class SearchResult {
  final List<ArtistSummary> artists;
  final List<Track> tracks;
  final List<ReleaseSummary> releases;
  final List<Show> shows;
  final List<Episode> episodes;
  const SearchResult(this.artists, this.tracks, this.releases, this.shows, [this.episodes = const []]);
  factory SearchResult.fromJson(Json j) => SearchResult(_list(j['artists'], ArtistSummary.fromJson), _list(j['tracks'], Track.fromJson), _list(j['releases'], ReleaseSummary.fromJson),
      _list(j['shows'], Show.fromJson), _list(j['episodes'], Episode.fromJson));
  bool get isEmpty => artists.isEmpty && tracks.isEmpty && releases.isEmpty && shows.isEmpty && episodes.isEmpty;
}

class LibrarySummary {
  final int likedCount;
  final List<PlaylistSummary> playlists;
  final List<String> followedArtists, savedReleases;
  const LibrarySummary(this.likedCount, this.playlists, this.followedArtists, this.savedReleases);
  factory LibrarySummary.fromJson(Json j) => LibrarySummary(
        (j['liked_count'] as num?)?.toInt() ?? 0,
        _list(j['playlists'], PlaylistSummary.fromJson),
        (j['followed_artists'] as List? ?? const []).cast<String>(),
        (j['saved_releases'] as List? ?? const []).cast<String>(),
      );
}

class LyricLine {
  final int timeMs;
  final String text;
  const LyricLine(this.timeMs, this.text);
}

class Lyrics {
  final bool synced;
  final List<LyricLine> lines;
  const Lyrics(this.synced, this.lines);
  factory Lyrics.fromJson(Json j) =>
      Lyrics(j['synced'] == true, (j['lines'] as List? ?? const []).map((l) => LyricLine((l['time_ms'] as num?)?.toInt() ?? 0, l['text'] ?? '')).toList());
}

class PlaybackSession {
  final String sessionId, streamUrl, codecLabel;
  final String? qualityCapped;
  final bool previewOnly;
  final int? previewMs;
  final int durationMs;
  /// Koreksi loudness per lagu dari server (dB) untuk normalisasi volume.
  final double? loudnessGainDb;
  /// Lossless diminta tetapi versi FLAC sedang disiapkan (diputar AAC 320 sementara).
  final bool losslessPending;
  const PlaybackSession({
    required this.sessionId,
    required this.streamUrl,
    required this.codecLabel,
    this.qualityCapped,
    this.previewOnly = false,
    this.previewMs,
    this.durationMs = 0,
    this.loudnessGainDb,
    this.losslessPending = false,
  });
  factory PlaybackSession.fromJson(Json j) => PlaybackSession(
        sessionId: j['session_id'],
        streamUrl: j['stream_url'],
        codecLabel: j['codec_label'] ?? '',
        qualityCapped: j['quality_capped'],
        previewOnly: j['preview_only'] == true,
        previewMs: (j['preview_ms'] as num?)?.toInt(),
        durationMs: (j['duration_ms'] as num?)?.toInt() ?? 0,
        loudnessGainDb: (j['loudness_gain_db'] as num?)?.toDouble(),
        losslessPending: j['lossless_pending'] == true,
      );
}

class AdCreative {
  final String impressionId, type, advertiser, title;
  final String? body, imageUrl, audioUrl, clickUrl, ctaLabel;
  final int durationS;
  final int? skippableAfterS;
  /// Promosi internal RAVE → label "Dari RAVE", bukan "Iklan" (BRD §7.9 / ADS-04).
  final bool isHouse;
  const AdCreative({
    required this.impressionId,
    required this.type,
    required this.advertiser,
    required this.title,
    this.body,
    this.imageUrl,
    this.audioUrl,
    this.clickUrl,
    this.ctaLabel,
    required this.durationS,
    this.skippableAfterS,
    this.isHouse = false,
  });
  factory AdCreative.fromJson(Json j) => AdCreative(
        impressionId: j['impression_id'],
        type: j['type'] ?? 'display',
        advertiser: j['advertiser'] ?? '',
        title: j['title'] ?? '',
        body: j['body'],
        imageUrl: j['image_url'],
        audioUrl: j['audio_url'],
        clickUrl: j['click_url'],
        ctaLabel: j['cta_label'],
        durationS: (j['duration_s'] as num?)?.toInt() ?? 15,
        skippableAfterS: (j['skippable_after_s'] as num?)?.toInt(),
        isHouse: j['is_house'] == true || j['label'] == 'Dari RAVE',
      );
}
