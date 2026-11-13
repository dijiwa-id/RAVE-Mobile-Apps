import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import 'common.dart';
import 'links.dart';
import 'media.dart';

/// Rak beranda tambahan — sumber data sama dengan beranda web (apps/web pages/fan/Home.tsx):
/// riwayat dengar, playlist editorial RAVE, dan event terdekat. Gagal dimuat → rak disembunyikan
/// (feed utama tetap tampil; banner koneksi yang memberi tahu bila server tak terjangkau).
class _Loader<T> extends StatefulWidget {
  const _Loader({required this.path, required this.parse, required this.builder, this.query});
  final String path;
  final Map<String, String>? query;
  final T Function(Json) parse;
  final Widget Function(BuildContext, T) builder;
  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  T? data;
  String get key => widget.query == null ? widget.path : '${widget.path}?${Uri(queryParameters: widget.query).query}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_Loader<T> old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.query?.toString() != widget.query?.toString()) _load();
  }

  Future<void> _load() async {
    final app = App.read(context);
    final cached = app.cache.peek(key);
    if (cached is T) setState(() => data = cached);
    try {
      final v = await app.cache.load(key, () async => widget.parse(await app.api.get(widget.path, query: widget.query)) as Object);
      if (mounted) setState(() => data = v as T);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => data == null ? const SizedBox.shrink() : widget.builder(context, data as T);
}

/// "Diputar baru-baru ini" (GET /v1/library/history): ketuk = putar riwayat mulai lagu itu.
class RecentlyPlayedShelf extends StatelessWidget {
  const RecentlyPlayedShelf({super.key});
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    if (!app.api.authed) return const SizedBox.shrink();
    return _Loader<List<Track>>(
      path: '/v1/library/history',
      parse: (j) {
        final seen = <String>{};
        return [
          for (final x in (j['data'] as List? ?? const []))
            if (seen.add((x as Json)['id'] as String)) Track.fromJson(x),
        ].take(12).toList();
      },
      builder: (context, tracks) => tracks.isEmpty
          ? const SizedBox.shrink()
          : Shelf(
              title: app.s.recentlyPlayed,
              children: [
                for (var i = 0; i < tracks.length; i++)
                  _Card(
                    title: tracks[i].title,
                    subtitle: tracks[i].artist.name,
                    image: tracks[i].coverUrl,
                    onTap: () => app.player.playQueue(tracks.map(Playable.fromTrack).toList(), i),
                  ),
              ],
            ),
    );
  }
}

/// "Playlist pilihan RAVE" (GET /v1/library/playlists/featured).
class FeaturedPlaylistsShelf extends StatelessWidget {
  const FeaturedPlaylistsShelf({super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return _Loader<List<Json>>(
      path: '/v1/library/playlists/featured',
      parse: (j) => (j['data'] as List? ?? const []).cast<Json>(),
      builder: (context, list) => list.isEmpty
          ? const SizedBox.shrink()
          : Shelf(title: s.featuredPlaylists, children: [
              for (final p in list.take(12))
                MediaCard(
                  item: MediaItem(
                    id: p['id'],
                    kind: 'playlist',
                    title: p['title'] ?? '',
                    subtitle: (p['description'] as String?) ?? s.songs((p['track_count'] as num?)?.toInt() ?? 0),
                    href: '/app/playlist/${p['id']}',
                    imageUrl: p['cover_url'],
                  ),
                ),
            ]),
    );
  }
}

/// Event terdekat (GET /v1/ticketing/events?city=…). Tiket dibeli di web RAVE (checkout & QR belum ada di aplikasi).
class EventsShelf extends StatelessWidget {
  const EventsShelf({super.key, this.city});
  final String? city;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return _Loader<List<Json>>(
      path: '/v1/ticketing/events',
      query: {'limit': '10', 'city': ?city},
      parse: (j) => (j['data'] as List? ?? const []).cast<Json>(),
      builder: (context, list) => list.isEmpty
          ? const SizedBox.shrink()
          : Shelf(title: city == null ? s.upcomingEvents : s.eventsIn(city!), height: 232, children: [
              for (final e in list.take(12))
                _Card(
                  eyebrow: _date(e['starts_at'] as String?, app.settings.locale),
                  title: e['title'] ?? '',
                  subtitle: [e['venue_name'], e['city']].whereType<String>().where((x) => x.isNotEmpty).join(', '),
                  image: e['poster_url'],
                  onTap: () => openUrl('${app.settings.server}/app/events/${Uri.encodeComponent('${e['slug']}')}'),
                ),
            ]),
    );
  }

  static String _date(String? iso, String locale) {
    final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    const idM = ['JAN', 'FEB', 'MAR', 'APR', 'MEI', 'JUN', 'JUL', 'AGU', 'SEP', 'OKT', 'NOV', 'DES'];
    const enM = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return '${d.day} ${(locale == 'en' ? enM : idM)[d.month - 1]} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.subtitle, required this.image, required this.onTap, this.eyebrow});
  final String title, subtitle;
  final String? image, eyebrow;
  final VoidCallback onTap;
  static const width = 148.0;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Cover(image, size: width - 12),
              const SizedBox(height: 8),
              if (eyebrow != null && eyebrow!.isNotEmpty) Text(eyebrow!, style: Rave.label(size: 10.5, color: Rave.mustard)),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, color: Rave.muted)),
            ]),
          ),
        ),
      );
}
