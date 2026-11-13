import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/common.dart';
import '../widgets/media.dart';
import 'browse.dart';
import 'routes.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => q = v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.search.toUpperCase(), style: Rave.poster(40)),
              const SizedBox(height: 12),
              TextField(
                controller: _ctl,
                focusNode: _focus,
                onChanged: _changed,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) => setState(() => q = v.trim()),
                style: Rave.body(size: 15, weight: FontWeight.w600, color: Rave.ink),
                decoration: InputDecoration(
                  hintText: s.searchHint,
                  fillColor: Rave.paper,
                  hintStyle: Rave.body(size: 15, color: const Color(0xFF6B6570)),
                  prefixIcon: const Icon(Icons.search_rounded, color: Rave.ink),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, color: Rave.ink),
                          onPressed: () {
                            _ctl.clear();
                            setState(() => q = '');
                          },
                        ),
                ),
              ),
            ]),
          ),
          Expanded(child: q.isEmpty ? const BrowseGrid() : _Results(key: ValueKey(q), q: q)),
        ]),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({super.key, required this.q});
  final String q;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ApiView<SearchResult>(
      path: '/v1/catalog/search',
      query: {'q': q},
      parse: SearchResult.fromJson,
      builder: (context, r, _) {
        if (r.isEmpty) return ListView(children: [EmptyState(s.noResults(q))]);
        final top = r.artists.isNotEmpty ? r.artists.first : null;
        return CustomScrollView(slivers: [
          if (top != null)
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () => openItem(context, 'artist', top.slug),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(children: [
                    Cover(top.imageUrl, size: 72, round: true),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Eyebrow(s.topResult, color: Rave.mustard),
                        const SizedBox(height: 4),
                        Text(top.name.toUpperCase(), style: Rave.poster(28)),
                        Text(s.kind('artist'), style: Rave.body(size: 13, color: Rave.muted)),
                      ]),
                    ),
                    PlayButton(
                      size: 44,
                      playing: false,
                      semantic: s.play,
                      onTap: () {
                        final mine = r.tracks.where((t) => t.artist.id == top.id).map(Playable.fromTrack).toList();
                        mine.isNotEmpty ? app.player.playQueue(mine) : playCollection(context, 'artist', top.slug);
                      },
                    ),
                  ]),
                ),
              ),
            ),
          if (r.tracks.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionTitle(s.songs(r.tracks.length))),
            TrackSliver(tracks: r.tracks),
          ],
          if (r.artists.length > 1)
            SliverToBoxAdapter(
              child: Shelf(title: s.artists, height: 196, children: [
                for (final a in r.artists) MediaCard(item: MediaItem(id: a.slug, kind: 'artist', title: a.name, subtitle: s.kind('artist'), href: '/app/artist/${a.slug}', imageUrl: a.imageUrl)),
              ]),
            ),
          if (r.releases.isNotEmpty)
            SliverToBoxAdapter(
              child: Shelf(title: s.albums, children: [
                for (final x in r.releases) MediaCard(item: MediaItem(id: x.id, kind: 'release', title: x.title, subtitle: '${x.year} · ${x.artist.name}', href: '/app/album/${x.id}', imageUrl: x.coverUrl)),
              ]),
            ),
          if (r.shows.isNotEmpty)
            SliverToBoxAdapter(
              child: Shelf(title: s.podcasts, children: [
                for (final x in r.shows) MediaCard(item: MediaItem(id: x.id, kind: 'show', title: x.title, subtitle: x.publisher, href: '/app/show/${x.id}', imageUrl: x.coverUrl)),
              ]),
            ),
          if (r.episodes.isNotEmpty)
            SliverToBoxAdapter(
              child: Shelf(title: s.episodes, children: [
                for (final e in r.episodes) MediaCard(item: MediaItem(id: e.id, kind: 'episode', title: e.title, subtitle: e.description ?? '', href: '/app/episode/${e.id}', imageUrl: e.coverUrl)),
              ]),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]);
      },
    );
  }
}
