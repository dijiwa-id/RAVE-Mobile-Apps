import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/common.dart';
import '../widgets/media.dart';
import 'login.dart';

class ArtistScreen extends StatefulWidget {
  const ArtistScreen({super.key, required this.id});
  final String id;
  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  bool? following;
  bool more = false;
  final _scroll = ScrollController();
  bool _titled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = _scroll.offset > 250;
      if (t != _titled) setState(() => _titled = t);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadFollow(Artist a) {
    final api = App.read(context).api;
    if (!api.authed || following != null) return;
    api.get('/v1/library/follows/${a.id}').then((j) {
      if (mounted) setState(() => following = j['following'] == true);
    }).catchError((_) {});
  }

  Future<void> _toggleFollow(Artist a) async {
    final app = App.read(context);
    final was = following ?? false;
    setState(() => following = !was);
    try {
      await app.api.request<dynamic>('/v1/library/follows/${a.id}', method: was ? 'DELETE' : 'PUT');
      app.cache.invalidate('/v1/library');
    } catch (e) {
      if (mounted) {
        setState(() => following = was);
        toast(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ApiView<Artist>(
      path: '/v1/catalog/artists/${Uri.encodeComponent(widget.id)}',
      parse: Artist.fromJson,
      loading: const Scaffold(body: Center(child: CircularProgressIndicator(color: Rave.mustard))),
      builder: (context, a, _) {
        _loadFollow(a);
        final top = more ? a.topTracks : a.topTracks.take(5).toList();
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: _titled ? Rave.plum.withValues(alpha: 0.96) : Colors.transparent,
            title: AnimatedOpacity(opacity: _titled ? 1 : 0, duration: const Duration(milliseconds: 150), child: Text(a.name, style: Rave.body(size: 16, weight: FontWeight.w700))),
          ),
          body: CustomScrollView(controller: _scroll, slivers: [
            SliverToBoxAdapter(child: _Header(a: a)),
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: app.player,
                builder: (context, _) {
                  final p = app.player;
                  final inThis = a.topTracks.any((t) => t.id == p.current?.id);
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(children: [
                      if (!app.api.authed)
                        OutlineButton(label: s.follow, onTap: () => requireLogin(context))
                      else if (following != null)
                        OutlineButton(label: following! ? s.following : s.follow, active: following!, onTap: () => _toggleFollow(a)),
                      const Spacer(),
                      if (a.topTracks.isNotEmpty)
                        PlayButton(
                          playing: inThis && p.playing,
                          semantic: s.play,
                          onTap: () => inThis ? p.toggle() : p.playQueue(a.topTracks.map(Playable.fromTrack).toList()),
                        ),
                    ]),
                  );
                },
              ),
            ),
            if (a.topTracks.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.popular)),
              TrackSliver(tracks: top),
              if (a.topTracks.length > 5)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(alignment: Alignment.centerLeft, child: OutlineButton(label: more ? s.showLess : s.seeAll, onTap: () => setState(() => more = !more))),
                  ),
                ),
            ],
            if (a.releases.isNotEmpty)
              SliverToBoxAdapter(
                child: Shelf(title: s.discography, children: [
                  for (final r in a.releases)
                    MediaCard(item: MediaItem(id: r.id, kind: 'release', title: r.title, subtitle: '${r.year} · ${s.kind(r.type)}', href: '/app/album/${r.id}', imageUrl: r.coverUrl)),
                ]),
              ),
            if (a.bio != null && a.bio!.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.about)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(a.bio!, style: Rave.body(size: 14.5, color: Rave.paper.withValues(alpha: 0.85), height: 1.5)),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]),
        );
      },
    );
  }
}

/// Header bergaya poster gig: foto hitam-putih kontras + tinta ungu, stiker terverifikasi, cap kota, label genre.
class _Header extends StatelessWidget {
  const _Header({required this.a});
  final Artist a;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final img = app.api.media(a.coverUrl ?? a.imageUrl);
    return SizedBox(
      height: 340 + MediaQuery.paddingOf(context).top * 0.5,
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Rave.purple),
        if (img != null)
          ColorFiltered(
            colorFilter: const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
            child: Cover(a.coverUrl ?? a.imageUrl),
          ),
        const ColoredBox(color: Color(0x885B2A6E)),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Rave.canvas, Color(0x330E0C0F), Colors.transparent], stops: [0, 0.55, 1])),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              if (a.verified)
                Transform.rotate(
                  angle: -0.05,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(color: Rave.paper, border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.verified_rounded, size: 13, color: Rave.ink),
                      const SizedBox(width: 4),
                      Text(s.verified.toUpperCase(), style: Rave.label(size: 9.5, color: Rave.ink)),
                    ]),
                  ),
                ),
              if (a.city != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: Rave.paper.withValues(alpha: 0.7))),
                  child: Text('⌖ ${a.city!.toUpperCase()}', style: Rave.label(size: 9.5, color: Rave.paper)),
                ),
              for (final g in a.genres.take(3))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 1.5), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(2, 2))]),
                  child: Text(g.toUpperCase(), style: Rave.label(size: 9, color: Rave.ink)),
                ),
            ]),
            const SizedBox(height: 10),
            Text(a.name.toUpperCase(), style: Rave.poster(a.name.length > 14 ? 48 : 64)),
            const SizedBox(height: 6),
            Text('${s.listeners(fmtCompact(a.monthlyListeners, app.settings.locale))} · ${s.followers(fmtCompact(a.followers, app.settings.locale))}',
                style: Rave.body(size: 13, color: Rave.paper.withValues(alpha: 0.85))),
          ]),
        ),
      ]),
    );
  }
}
