import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/feedback.dart';
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
      if (mounted) showToast(context, was ? app.s.unfollowedToast(a.name) : app.s.followedToast(a.name), kind: was ? ToastKind.info : ToastKind.ok, image: a.imageUrl);
    } catch (e) {
      if (mounted) {
        setState(() => following = was);
        toastError(context, e);
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
      loading: const Scaffold(body: SafeArea(child: ListSkeleton())),
      builder: (context, a, _) {
        _loadFollow(a);
        final top = more ? a.topTracks : a.topTracks.take(5).toList();
        return Scaffold(
          extendBodyBehindAppBar: true,
          // App bar & judul muncul BERTAHAP mengikuti gulir (bukan berganti mendadak di satu titik).
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AnimatedBuilder(
              animation: _scroll,
              builder: (context, _) {
                final top = MediaQuery.paddingOf(context).top;
                final o = _scroll.hasClients && _scroll.positions.length == 1 ? _scroll.offset : 0.0;
                // Bilah terisi saat sisa header ≈ setinggi app bar; judul menyusul sedikit kemudian.
                final end = _Header.heightFor(context) - kToolbarHeight - top;
                final bg = Curves.easeOut.transform(((o - (end - 110)) / 110).clamp(0.0, 1.0));
                final title = Curves.easeOut.transform(((o - (end - 40)) / 60).clamp(0.0, 1.0));
                return AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Rave.plum.withValues(alpha: 0.97 * bg),
                      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06 * bg))),
                    ),
                    child: const SizedBox.expand(),
                  ),
                  // Header poster gig selalu gelap (kedua tema) → ikon & bilah status terang.
                  foregroundColor: Rave.paper,
                  systemOverlayStyle: Rave.overlayFor(Brightness.dark),
                  title: Opacity(
                    opacity: title,
                    child: Transform.translate(offset: Offset(0, 8 * (1 - title)), child: Text(a.name, style: Rave.body(size: 16, weight: FontWeight.w700, color: Rave.paper))),
                  ),
                );
              },
            ),
          ),
          body: CustomScrollView(controller: _scroll, physics: raveVerticalPhysics, slivers: [
            SliverToBoxAdapter(child: DarkZone(child: _Header(a: a, scroll: _scroll))),
            SliverToBoxAdapter(
              child: ListenableBuilder(
                listenable: app.player,
                builder: (context, _) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: Row(children: [
                      if (!app.api.authed)
                        OutlineButton(label: s.follow, onTap: () => requireLogin(context))
                      else if (following != null)
                        OutlineButton(label: following! ? s.following : s.follow, active: following!, onTap: () => _toggleFollow(a)),
                      const Spacer(),
                      if (a.topTracks.isNotEmpty)
                        PlayFab(
                          size: 56,
                          playKey: 'artist:${a.slug}',
                          semantic: s.play,
                          onPlay: () => playCollectionNow(context, a.topTracks.map(Playable.fromTrack).toList(), 'artist:${a.slug}', title: a.name, image: a.imageUrl),
                        ),
                    ]),
                  );
                },
              ),
            ),
            if (a.topTracks.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionTitle(s.popular)),
              TrackSliver(tracks: top, contextKey: 'artist:${a.slug}'),
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
                  child: Text(a.bio!, style: Rave.body(size: 14.5, color: context.rc.text.withValues(alpha: 0.85), height: 1.5)),
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
/// Saat digulir: foto bergeser lebih lambat (paralaks) dengan zoom halus DI DALAM header (dipotong, tidak menutupi
/// konten), lapisan gelap menebal sehingga header melebur ke halaman, dan teks memudar bersama tanpa saling tumpuk.
class _Header extends StatelessWidget {
  const _Header({required this.a, this.scroll});
  final Artist a;
  final ScrollController? scroll;

  static double heightFor(BuildContext context) => 340 + MediaQuery.paddingOf(context).top * 0.5;

  @override
  Widget build(BuildContext context) {
    final h = heightFor(context);
    final sc = scroll;
    if (sc == null || RaveMotion.reduced(context)) return SizedBox(height: h, child: _layers(context, 0, h));
    return SizedBox(
      height: h,
      child: AnimatedBuilder(
        animation: sc,
        builder: (context, _) => _layers(context, sc.hasClients && sc.positions.length == 1 ? sc.offset : 0.0, h),
      ),
    );
  }

  Widget _layers(BuildContext context, double o, double h) {
    final app = App.of(context);
    final s = app.s;
    final img = app.api.media(a.coverUrl ?? a.imageUrl);
    final t = (o / h).clamp(0.0, 1.0); // 0 = header utuh, 1 = header habis tergulir
    final pull = o < 0 ? -o : 0.0; // tarik melewati atas (overscroll)
    // Foto: tertinggal 40% dari gulir + zoom 6% (lembut); tarik ke bawah → membesar dari atas.
    final imgShift = o > 0 ? o * 0.4 : 0.0;
    final double imgScale = o < 0 ? 1.0 + min(pull / 500, 0.18) : 1.0 + 0.06 * t;
    // Teks: memudar lebih awal (selesai di ~45% tinggi header) & bergeser sedikit lebih lambat dari halaman.
    final fade = Curves.easeOut.transform((1 - o / (h * 0.45)).clamp(0.0, 1.0));
    final textShift = o > 0 ? o * 0.25 : 0.0;
    return ClipRect(
      child: Stack(fit: StackFit.expand, children: [
        const ColoredBox(color: Rave.purple),
        if (img != null)
          Transform.translate(
            offset: Offset(0, imgShift),
            child: Transform.scale(
              scale: imgScale,
              alignment: o < 0 ? Alignment.topCenter : Alignment.center,
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
                child: Cover(a.coverUrl ?? a.imageUrl),
              ),
            ),
          ),
        const ColoredBox(color: Color(0x885B2A6E)),
        // Gradasi bawah lebih panjang & bertahap agar foto melebur halus ke latar halaman.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Rave.canvas, Color(0xCC0E0C0F), Color(0x550E0C0F), Color(0x000E0C0F)],
              stops: [0, 0.22, 0.55, 1],
            ),
          ),
        ),
        // Gradasi atas tipis agar ikon kembali & bilah status selalu terbaca di atas foto terang.
        const Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x660E0C0F), Color(0x000E0C0F)]))),
          ),
        ),
        // Saat digulir header perlahan menggelap → transisi lembut ke konten & app bar.
        if (t > 0) ColoredBox(color: Rave.canvas.withValues(alpha: 0.65 * Curves.easeIn.transform(t))),
        Positioned(
          left: 16,
          right: 16,
          bottom: 14 - textShift,
          child: Opacity(
            opacity: fade,
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
              Text(a.name.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.poster(a.name.length > 14 ? 48 : 64)),
              const SizedBox(height: 6),
              Text('${s.listeners(fmtCompact(a.monthlyListeners, app.settings.locale))} · ${s.followers(fmtCompact(a.followers, app.settings.locale))}',
                  style: Rave.body(size: 13, color: Rave.paper.withValues(alpha: 0.85))),
            ]),
          ),
        ),
      ]),
    );
  }
}
