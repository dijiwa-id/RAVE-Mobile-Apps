import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';
import 'motion.dart';

/// Kerangka halaman koleksi (album, playlist, podcast): header gradien + sampul besar + judul poster, bilah aksi,
/// lalu isi. Interaksi gulir sama dengan halaman Artis: sampul mengecil & memudar DI TEMPATNYA (tidak bergeser
/// menimpa teks di bawahnya), judul besar memudar saat masuk ke bawah app bar, lalu latar & judul kecil app bar
/// muncul bertahap ([CollapsingAppBar]).
class CollectionPage extends StatefulWidget {
  const CollectionPage({
    super.key,
    required this.kind,
    required this.title,
    this.cover,
    this.art,
    required this.meta,
    required this.actions,
    required this.slivers,
    this.tint = Rave.purple,
    this.round = false,
    this.placeholderIcon,
  });
  final String kind, title;
  final String? cover;
  final Widget? art;
  final Widget meta;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Color tint;
  final bool round;
  final IconData? placeholderIcon;

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final art = (w * 0.58).clamp(160.0, 260.0);
    // Tinggi sampul (sampul kustom [CollectionPage.art] berukuran 220).
    final artH = widget.art != null ? 220.0 : art;
    final rc = context.rc;
    final reduced = RaveMotion.reduced(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Latar app bar menutup sampul saat sampul hampir habis memudar; judul kecil muncul setelah judul besar
      // masuk ke bawah app bar (judul besar dimulai ±artH + 20 dari atas isi).
      appBar: CollapsingAppBar(
        controller: _scroll,
        title: widget.title,
        color: rc.isLight ? rc.base.withValues(alpha: 0.97) : widget.tint.withValues(alpha: 0.96),
        background: (artH * 0.45, artH * 0.9),
        titleRange: (artH + 30, artH + 90),
        titleStyle: Rave.body(size: 16, weight: FontWeight.w700),
      ),
      body: CustomScrollView(controller: _scroll, physics: raveVerticalPhysics, slivers: [
        SliverToBoxAdapter(
          child: ClipRect(
            child: Container(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [rc.isLight ? widget.tint.withValues(alpha: 0.32) : widget.tint, rc.canvas])),
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + kToolbarHeight, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _scrolled(
                  reduced,
                  // Sampul: mengecil (maks 18%) berporos di tepi BAWAH & memudar habis sebelum tertutup app bar,
                  // tanpa bergeser turun → tidak pernah menimpa label/judul. Ditarik melewati atas → membesar ke atas.
                  (o, child) {
                    final t = (o / artH).clamp(0.0, 1.0);
                    final double scale = o < 0 ? 1 + min(-o / 500, 0.18) : 1 - 0.18 * t;
                    return Opacity(
                      opacity: Curves.easeOut.transform((1 - o / (artH * 0.85)).clamp(0.0, 1.0)),
                      child: Transform.scale(scale: scale, alignment: Alignment.bottomCenter, child: child),
                    );
                  },
                  Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(boxShadow: [if (!rc.isLight) const BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12))]),
                      child: widget.art ??
                          DecoratedBox(
                            decoration: BoxDecoration(border: Border.all(color: Rave.ink, width: 2), boxShadow: rc.hard(6)),
                            child: Cover(widget.cover, size: art, round: widget.round, placeholderIcon: widget.placeholderIcon),
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Label & judul besar bergulir bersama halaman (tanpa transform) lalu memudar saat masuk ke bawah app bar.
                _scrolled(
                  reduced,
                  (o, child) => Opacity(opacity: Curves.easeOut.transform((1 - (o - (artH - 10)) / 70).clamp(0.0, 1.0)), child: child),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Eyebrow(widget.kind, color: rc.text),
                    const SizedBox(height: 6),
                    Text(widget.title.toUpperCase(), style: Rave.poster(widget.title.length > 22 ? 32 : 42)),
                  ]),
                ),
                const SizedBox(height: 8),
                DefaultTextStyle(style: Rave.body(size: 13, color: rc.text.withValues(alpha: 0.85)), child: widget.meta),
                const SizedBox(height: 8),
                Row(children: widget.actions),
              ]),
            ),
          ),
        ),
        ...widget.slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }

  /// Bungkus [child] dengan efek bergantung offset gulir; anak di-cache (hanya transform/opacity yang dibangun ulang).
  /// Kurangi gerakan → statis.
  Widget _scrolled(bool reduced, Widget Function(double o, Widget child) effect, Widget child) {
    if (reduced) return child;
    return RepaintBoundary(
      child: AnimatedBuilder(animation: _scroll, child: child, builder: (context, child) => effect(scrollOffsetOf(_scroll), child!)),
    );
  }
}
