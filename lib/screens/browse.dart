import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import '../widgets/media.dart';
import 'live.dart';
import 'routes.dart';
import 'shell.dart';

/// Kategori "Jelajahi semua" — sumber sama dengan web (`GET /v1/catalog/browse`, apps/web pages/fan/Search.tsx).
class Category {
  final String id, name, href;
  final Color color;
  final String? imageUrl;
  const Category(this.id, this.name, this.href, this.color, this.imageUrl);
  factory Category.fromJson(Json j) => Category(j['id'], j['name'] ?? '', j['href'] ?? '', parseHex(j['color'] as String?) ?? Rave.purple, j['image_url']);
}

Color? parseHex(String? hex) {
  if (hex == null) return null;
  final h = hex.replaceFirst('#', '');
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16);
  return v == null ? null : Color(v);
}

/// Pengaturan publik platform (modul aktif) — `GET /v1/platform/config`, di-cache 5 menit lewat DataCache.
Future<bool> platformFlag(AppState app, String key, {bool fallback = true}) async {
  try {
    final j = await app.cache.load('cfg:platform', () async => await app.api.get('/v1/platform/config') as Object) as Json;
    final v = (j['settings'] as Json?)?[key];
    return v is bool ? v : fallback;
  } catch (_) {
    return fallback;
  }
}

/// Buka `href` aplikasi web (`/app/...`) di layar asli aplikasi — satu pemetaan untuk kategori, kartu, dsb.
void openHref(BuildContext context, String href) {
  final app = App.read(context);
  final u = Uri.parse(href);
  final seg = u.pathSegments.where((x) => x.isNotEmpty).toList();
  final nav = Navigator.of(context);
  Widget? page;
  if (seg.length <= 1 && (seg.isEmpty || seg.first == 'app')) {
    selectShellTab(0);
    return;
  }
  final kind = seg[1];
  final id = seg.length > 2 ? Uri.decodeComponent(seg[2]) : null;
  switch (kind) {
    case 'genre' when id != null:
      page = GenreScreen(id: id);
    case 'podcasts':
      page = PodcastsScreen(fiction: u.queryParameters['kind'] == 'FICTION');
    case 'live':
      page = id == null ? const LiveScreen() : LiveWatchScreen(id: id);
    case 'events':
      // Tiket & checkout belum ada di aplikasi → halaman event web RAVE (sama dengan rak Event di beranda).
      openUrl('${app.settings.server}$href');
      return;
    default:
      if (id != null) {
        openItem(context, kind == 'album' ? 'release' : kind, id);
        return;
      }
  }
  if (page != null) nav.push(MaterialPageRoute<void>(builder: (_) => page!));
}

/// Kisi kategori di tab Cari (kosong). Tile "Live" ditambahkan di depan bila modul live aktif (di web: menu Live).
class BrowseGrid extends StatefulWidget {
  const BrowseGrid({super.key});
  @override
  State<BrowseGrid> createState() => _BrowseGridState();
}

class _BrowseGridState extends State<BrowseGrid> {
  bool podcasts = true, live = true;

  @override
  void initState() {
    super.initState();
    final app = App.read(context);
    platformFlag(app, 'modules.podcasts').then((v) => mounted ? setState(() => podcasts = v) : null);
    platformFlag(app, 'modules.live').then((v) => mounted ? setState(() => live = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return ApiView<List<Category>>(
      path: '/v1/catalog/browse',
      parse: (j) => [for (final x in (j['data'] as List? ?? const [])) Category.fromJson(x as Json)],
      builder: (context, all, _) {
        final cats = [
          if (live) const Category('live', 'Live', '/app/live', Rave.berry, null),
          ...all.where((c) => podcasts || !c.href.startsWith('/app/podcasts')),
        ];
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12), child: Text(s.browseAll.toUpperCase(), style: Rave.poster(24))),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 220, mainAxisExtent: 104, crossAxisSpacing: 12, mainAxisSpacing: 12),
              itemCount: cats.length,
              itemBuilder: (context, i) => _Tile(c: cats[i]),
            ),
          ),
        ]);
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.c});
  final Category c;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: c.name,
        child: Material(
          color: c.color,
          clipBehavior: Clip.hardEdge,
          child: InkWell(
            onTap: () => openHref(context, c.href),
            child: Stack(children: [
              if (c.imageUrl != null)
                Positioned(
                  right: -14,
                  bottom: -8,
                  child: Transform.rotate(
                    angle: 0.44,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 6, offset: Offset(0, 2))]),
                      child: Cover(c.imageUrl, size: 70),
                    ),
                  ),
                )
              else if (c.id == 'live')
                const Positioned(right: 10, bottom: 8, child: Icon(Icons.sensors_rounded, size: 46, color: Color(0xCCFFFFFF))),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 64, 10),
                child: Text(c.name, maxLines: 3, overflow: TextOverflow.ellipsis, style: Rave.body(size: 16.5, weight: FontWeight.w800, height: 1.1)),
              ),
            ]),
          ),
        ),
      );
}

/// Halaman kategori — `GET /v1/catalog/browse/:id` + playlist editorial bertag (apps/web pages/fan/Genre.tsx).
class GenreScreen extends StatelessWidget {
  const GenreScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return Scaffold(
      body: ApiView<_GenreData>(
        path: '/v1/catalog/browse/${Uri.encodeComponent(id)}',
        parse: _GenreData.fromJson,
        builder: (context, d, _) {
          final color = d.color ?? Rave.purple;
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 190,
              backgroundColor: Color.lerp(color, Rave.canvas, 0.35),
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14, end: 16),
                title: Text(d.name.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.poster(30)),
                background: DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [color, Rave.canvas])),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _TaggedPlaylists(tag: id)),
            if (d.artists.isNotEmpty)
              SliverToBoxAdapter(
                child: Shelf(title: s.artists, height: 196, children: [
                  for (final a in d.artists)
                    MediaCard(item: MediaItem(id: a.slug, kind: 'artist', title: a.name, subtitle: a.city ?? s.kind('artist'), href: '/app/artist/${a.slug}', imageUrl: a.imageUrl)),
                ]),
              ),
            if (d.releases.isNotEmpty)
              SliverToBoxAdapter(
                child: Shelf(title: s.releasesTitle, children: [
                  for (final r in d.releases) MediaCard(item: MediaItem(id: r.id, kind: 'release', title: r.title, subtitle: '${r.year} · ${r.artist.name}', href: '/app/album/${r.id}', imageUrl: r.coverUrl)),
                ]),
              ),
            if (d.tracks.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.popularSongs)),
              TrackSliver(tracks: d.tracks),
            ],
            if (d.isEmpty) SliverToBoxAdapter(child: EmptyState(s.noContentInCategory)),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]);
        },
      ),
    );
  }
}

class _GenreData {
  final String name;
  final Color? color;
  final List<ArtistSummary> artists;
  final List<ReleaseSummary> releases;
  final List<Track> tracks;
  const _GenreData(this.name, this.color, this.artists, this.releases, this.tracks);
  factory _GenreData.fromJson(Json j) {
    final c = j['category'] as Json? ?? const {};
    List<T> list<T>(String k, T Function(Json) f) => [for (final x in (j[k] as List? ?? const [])) f(x as Json)];
    return _GenreData(c['name'] ?? '', parseHex(c['color'] as String?), list('artists', ArtistSummary.fromJson), list('releases', ReleaseSummary.fromJson), list('tracks', Track.fromJson));
  }
  bool get isEmpty => artists.isEmpty && releases.isEmpty && tracks.isEmpty;
}

/// Playlist editorial bertag kategori (`GET /v1/library/playlists/featured?tag=`); kosong → disembunyikan.
class _TaggedPlaylists extends StatelessWidget {
  const _TaggedPlaylists({required this.tag});
  final String tag;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return ApiView<List<PlaylistSummary>>(
      path: '/v1/library/playlists/featured',
      query: {'tag': tag},
      loading: const SizedBox.shrink(),
      parse: (j) => [for (final x in (j['data'] as List? ?? const [])) PlaylistSummary.fromJson(x as Json)],
      builder: (context, list, _) => list.isEmpty
          ? const SizedBox.shrink()
          : Shelf(title: s.playlists, children: [
              for (final p in list)
                MediaCard(item: MediaItem(id: p.id, kind: 'playlist', title: p.title, subtitle: p.description ?? s.songs(p.trackCount), href: '/app/playlist/${p.id}', imageUrl: p.coverUrl)),
            ]),
    );
  }
}

/// Podcast & Cerita (`GET /v1/catalog/shows?kind=PODCAST|FICTION`) — tab seperti /app/podcasts di web.
class PodcastsScreen extends StatefulWidget {
  const PodcastsScreen({super.key, this.fiction = false});
  final bool fiction;
  @override
  State<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends State<PodcastsScreen> {
  late bool fiction = widget.fiction;

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return Scaffold(
      appBar: AppBar(title: Text((fiction ? s.storiesTab : s.podcasts).toUpperCase(), style: Rave.poster(26)), backgroundColor: Rave.canvas),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            OutlineButton(label: s.podcasts, active: !fiction, onTap: () => setState(() => fiction = false)),
            const SizedBox(width: 8),
            OutlineButton(label: s.storiesTab, active: fiction, onTap: () => setState(() => fiction = true)),
          ]),
        ),
        Expanded(
          child: ApiView<List<Show>>(
            key: ValueKey(fiction),
            path: '/v1/catalog/shows',
            query: {'kind': fiction ? 'FICTION' : 'PODCAST'},
            parse: (j) => [for (final x in (j['data'] as List? ?? const [])) Show.fromJson(x as Json)],
            builder: (context, shows, _) => shows.isEmpty
                ? ListView(children: [EmptyState(s.noContentInCategory)])
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisExtent: 236),
                    itemCount: shows.length,
                    itemBuilder: (_, i) {
                      final x = shows[i];
                      return LayoutBuilder(
                        builder: (context, c) => MediaCard(
                          width: c.maxWidth,
                          item: MediaItem(id: x.id, kind: 'show', title: x.title, subtitle: x.publisher, href: '/app/show/${x.id}', imageUrl: x.coverUrl),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ]),
    );
  }
}
