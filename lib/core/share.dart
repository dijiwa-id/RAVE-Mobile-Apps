import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'models.dart';

/// Bagikan lagu ke Instagram, X & Facebook — kontrak bersama server (`packages/domain/src/share.ts`), web & desktop.
/// Teks, tagar & tautan intent X/Facebook dibangun server (template Super Admin) agar semua klien konsisten.

const sharePlatforms = ['instagram', 'x', 'facebook'];

/// Platform yang dicatat statistiknya: tiga media sosial + salin tautan + share sheet sistem.
const shareEventPlatforms = [...sharePlatforms, 'copy', 'system'];

class SharePlatformLink {
  const SharePlatformLink(this.id, this.url);
  final String id;

  /// Tautan intent siap buka (X/Facebook). Instagram = null → klien membuat kartu cerita.
  final String? url;
}

/// Data siap pakai untuk lembar bagikan (`GET /v1/catalog/tracks/:id/share`).
class TrackShare {
  const TrackShare({
    required this.trackId,
    required this.title,
    required this.artist,
    required this.url,
    required this.text,
    this.hashtags = const [],
    this.imageUrl,
    this.platforms = const [],
  });

  final String trackId, title, artist, url, text;
  final List<String> hashtags;
  final String? imageUrl;
  final List<SharePlatformLink> platforms;

  /// Teks + tautan untuk salin / share sheet sistem.
  String get fullText => text.isEmpty ? url : '$text $url';

  /// Tautan tanpa skema (untuk kartu cerita).
  String get shortUrl => url.replaceFirst(RegExp(r'^https?://'), '');

  /// Parser toleran: platform tak dikenal/duplikat dibuang, X/Facebook tanpa URL http(s) dibuang
  /// (tak bisa dibuka), field wajib kosong → [FormatException].
  factory TrackShare.fromJson(Json j) {
    String str(String k) => j[k] is String ? j[k] as String : '';
    final url = str('url');
    if (url.isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) throw const FormatException('share.url');
    final seen = <String>{};
    final platforms = <SharePlatformLink>[];
    for (final p in j['platforms'] is List ? j['platforms'] as List : const []) {
      if (p is! Map) continue;
      final id = p['id'];
      final u = p['url'];
      if (id is! String || !sharePlatforms.contains(id) || !seen.add(id)) continue;
      final link = u is String && (u.startsWith('https://') || u.startsWith('http://')) ? u : null;
      if (id != 'instagram' && link == null) continue;
      platforms.add(SharePlatformLink(id, id == 'instagram' ? null : link));
    }
    platforms.sort((a, b) => sharePlatforms.indexOf(a.id).compareTo(sharePlatforms.indexOf(b.id)));
    final img = j['image_url'];
    return TrackShare(
      trackId: str('track_id'),
      title: str('title'),
      artist: str('artist'),
      url: url,
      text: str('text'),
      hashtags: [for (final h in j['hashtags'] is List ? j['hashtags'] as List : const []) if (h is String && h.isNotEmpty) h],
      imageUrl: img is String && img.isNotEmpty ? img : null,
      platforms: platforms,
    );
  }
}

/// Pengaturan publik Super Admin (`/v1/platform/config` → `settings.share.*`). Kunci hilang (server lama) = bawaan aktif.
class ShareFlags {
  const ShareFlags({this.enabled = true, this.instagram = true, this.x = true, this.facebook = true});
  final bool enabled, instagram, x, facebook;

  factory ShareFlags.fromConfig(Json cfg) {
    bool f(String k) => cfg[k] is bool ? cfg[k] as bool : true;
    return ShareFlags(enabled: f('share.enabled'), instagram: f('share.instagram_enabled'), x: f('share.x_enabled'), facebook: f('share.facebook_enabled'));
  }

  bool allows(String platform) => enabled && switch (platform) { 'instagram' => instagram, 'x' => x, 'facebook' => facebook, _ => true };
}

/// Platform yang ditampilkan di lembar: hanya yang dikirim server DAN tidak dimatikan di config yang dimuat aplikasi.
List<SharePlatformLink> visiblePlatforms(TrackShare s, ShareFlags flags) => [for (final p in s.platforms) if (flags.allows(p.id)) p];

/// Hasil memuat data bagikan.
sealed class ShareLoad {
  const ShareLoad();
}

class ShareReady extends ShareLoad {
  const ShareReady(this.share);
  final TrackShare share;
}

/// Fitur dimatikan / lagu tidak tayang / server belum mendukung (404) — "belum tersedia".
class ShareUnavailable extends ShareLoad {
  const ShareUnavailable();
}

/// Offline / galat server sementara — bisa dicoba lagi.
class ShareFailed extends ShareLoad {
  const ShareFailed();
}

/// Cache data bagikan per lagu (per server): berhasil 10 menit, "belum tersedia" 2 menit, galat tidak di-cache.
/// Permintaan paralel untuk lagu yang sama digabung.
class ShareRepo {
  ShareRepo(this._fetch, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final Future<Json> Function(String trackId) _fetch;
  final DateTime Function() _now;
  final _cache = <String, ({ShareLoad value, DateTime at})>{};
  final _inflight = <String, Future<ShareLoad>>{};
  static const okTtl = Duration(minutes: 10), missTtl = Duration(minutes: 2);

  static final _byServer = <String, ShareRepo>{};

  /// Satu repo per alamat server (ganti server → cache terpisah).
  static ShareRepo of(Api api) => _byServer[api.base] ??= _testOverride ?? ShareRepo((id) => api.get('/v1/catalog/tracks/${Uri.encodeComponent(id)}/share'));

  static ShareRepo? _testOverride;

  /// Uji: semua server memakai repo ini (null = kembali normal).
  @visibleForTesting
  static set debugOverride(ShareRepo? r) {
    _testOverride = r;
    _byServer.clear();
  }

  ShareLoad? peek(String trackId) {
    final c = _cache[trackId];
    if (c == null) return null;
    final ttl = c.value is ShareReady ? okTtl : missTtl;
    return _now().difference(c.at) < ttl ? c.value : null;
  }

  Future<ShareLoad> load(String trackId) {
    final hit = peek(trackId);
    if (hit != null) return Future.value(hit);
    return _inflight[trackId] ??= () async {
      ShareLoad r;
      try {
        r = ShareReady(TrackShare.fromJson(await _fetch(trackId)));
      } on ApiError catch (e) {
        r = e.status == 404 || e.status == 405 ? const ShareUnavailable() : const ShareFailed();
      } on FormatException {
        r = const ShareUnavailable();
      } catch (_) {
        r = const ShareFailed();
      }
      if (r is! ShareFailed) _cache[trackId] = (value: r, at: _now());
      return r;
    }()
        // Callback ber-blok: `=> _inflight.remove(..)` mengembalikan Future ini sendiri → menunggu dirinya (macet).
        .whenComplete(() {
      _inflight.remove(trackId);
    });
  }
}

/// Catat aksi bagikan (statistik Super Admin). Fire-and-forget: tidak pernah memblokir atau memunculkan galat.
void recordShare(Api api, String trackId, String platform) {
  if (!shareEventPlatforms.contains(platform)) return;
  unawaited(api
      .request<dynamic>('/v1/catalog/tracks/${Uri.encodeComponent(trackId)}/share',
          method: 'POST', body: {'platform': platform, 'client': 'android'}, timeout: const Duration(seconds: 10))
      .then<void>((_) {}, onError: (Object _) {}));
}
