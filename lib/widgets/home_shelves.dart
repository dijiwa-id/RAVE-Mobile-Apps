import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import 'common.dart';
import 'getting_started.dart';
import 'motion.dart';
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
  bool _failed = false;
  String get key => widget.query == null ? widget.path : '${widget.path}?${Uri(queryParameters: widget.query).query}';

  @override
  void initState() {
    super.initState();
    final cached = App.read(context).cache.peek(key);
    if (cached is T) data = cached;
    _load();
  }

  @override
  void didUpdateWidget(_Loader<T> old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.query?.toString() != widget.query?.toString()) _load();
  }

  Future<void> _load() async {
    final app = App.read(context);
    try {
      final v = await app.cache.load(key, () async => widget.parse(await app.api.get(widget.path, query: widget.query)) as Object);
      if (mounted) setState(() => (data = v as T, _failed = false));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  // Memuat → kerangka rak shimmer; gagal → disembunyikan; ada data → rak (muncul dengan animasi masuk).
  @override
  Widget build(BuildContext context) => data != null
      ? Entrance(id: 'shelf:$key', child: widget.builder(context, data as T))
      : _failed
          ? const SizedBox.shrink()
          : ShelfSkeleton(cardWidth: shelfCardWidth(context));
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
                    playKey: 'track:${tracks[i].id}',
                    onTap: () => app.player.playQueue(tracks.map(Playable.fromTrack).toList(), i),
                  ),
              ],
            ),
    );
  }
}

/// "Pilihan untuk {nama}" — tile penuh setinggi banner Mulai di RAVE (web `MiniShelf tiles` + `PickTile`),
/// memakai playlist editorial (GET /v1/library/playlists/featured). Kosong → tidak tampil.
class PicksShelf extends StatelessWidget {
  const PicksShelf({super.key});
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final name = app.api.user?.displayName.trim().split(' ').first ?? '';
    return _Loader<List<Json>>(
      path: '/v1/library/playlists/featured',
      parse: (j) => (j['data'] as List? ?? const []).cast<Json>(),
      builder: (context, list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final w = MediaQuery.sizeOf(context).width;
        final tile = ((w - 16) / (w >= 600 ? 2.6 : 1.6)).clamp(200.0, 360.0);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 28, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text((name.isEmpty ? s.madeForGuest : s.madeFor(name)).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.poster(28)),
            ]),
          ),
          SizedBox(
            height: gsHeight + 8,
            child: RaveHorizontalList(snapExtent: tile + 14, padding: const EdgeInsets.only(left: 16, right: 8), children: [
              for (final p in list.take(8))
                PickTile(
                  id: p['id'] as String,
                  title: (p['title'] ?? '') as String,
                  subtitle: (p['description'] as String?) ?? s.songs((p['track_count'] as num?)?.toInt() ?? 0),
                  image: p['cover_url'] as String?,
                  width: tile,
                ),
            ]),
          ),
        ]);
      },
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
  const EventsShelf({super.key, this.city, this.emptyText});
  final String? city;
  /// Tampilkan catatan ini bila tidak ada event (tab Event); null = rak disembunyikan.
  final String? emptyText;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return _Loader<List<Json>>(
      path: '/v1/ticketing/events',
      query: {'limit': '10', 'city': ?city},
      parse: (j) => (j['data'] as List? ?? const []).cast<Json>(),
      builder: (context, list) => list.isEmpty
          ? (emptyText == null ? const SizedBox.shrink() : FilterEmptyNote(emptyText!))
          : Shelf(title: city == null ? s.upcomingEvents : s.eventsIn(city!), height: shelfCardWidth(context) + 90, children: [
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
  const _Card({required this.title, required this.subtitle, required this.image, required this.onTap, this.eyebrow, this.playKey});
  final String title, subtitle;
  final String? image, eyebrow;
  final VoidCallback onTap;
  /// Kartu lagu: tombol putar/jeda (ketuk kartu = putar dari sini).
  final String? playKey;
  @override
  Widget build(BuildContext context) {
    final width = shelfCardWidth(context);
    final app = App.of(context);
    return Pressable(child: SizedBox(
      width: width,
      child: ListenableBuilder(
        listenable: app.player,
        builder: (context, _) {
          final active = app.player.isActive(playKey);
          return InkWell(
            onTap: active ? app.player.toggle : onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    border: Border.all(color: Rave.ink, width: 2),
                    boxShadow: [BoxShadow(color: active ? Rave.mustard : context.rc.shadow, offset: active ? const Offset(5, 5) : const Offset(3, 3))],
                  ),
                  child: Stack(children: [
                    Cover(image, size: width - 18),
                    if (playKey != null) Positioned(right: 8, bottom: 8, child: PlayFab(size: 40, playKey: playKey, semantic: '${app.s.play} $title', onPlay: onTap)),
                  ]),
                ),
                const SizedBox(height: 10),
                if (eyebrow != null && eyebrow!.isNotEmpty) Text(eyebrow!, style: Rave.label(size: 10.5, color: context.rc.accent)),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700, color: active ? context.rc.accent : context.rc.text)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, color: context.rc.muted)),
              ]),
            ),
          );
        },
      ),
    ));
  }
}

/// Catatan "tidak ada yang bisa ditampilkan" untuk chip beranda (web: kotak bergaris kiri mustard).
class FilterEmptyNote extends StatelessWidget {
  const FilterEmptyNote(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.rc.isLight ? context.rc.card : const Color(0x0AFFFFFF),
          border: Border(left: BorderSide(color: context.rc.isLight ? Rave.purple : Rave.mustard, width: 2)),
        ),
        child: Text(text, style: Rave.body(size: 13.5, color: context.rc.muted)),
      );
}
