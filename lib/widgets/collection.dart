import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';
import 'motion.dart';

/// Kerangka halaman koleksi (album, playlist, podcast): header gradien + sampul besar + judul poster, bilah aksi,
/// lalu isi. App bar menampilkan judul setelah header tergulir.
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
  bool _titled = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final t = _scroll.offset > 260;
      if (t != _titled) setState(() => _titled = t);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final art = (w * 0.58).clamp(160.0, 260.0);
    final rc = context.rc;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        // Latar app bar memudar masuk (tanpa membangun ulang halaman per frame).
        flexibleSpace: AnimatedOpacity(
          opacity: _titled ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: ColoredBox(color: rc.isLight ? rc.base.withValues(alpha: 0.97) : widget.tint.withValues(alpha: 0.96), child: const SizedBox.expand()),
        ),
        title: AnimatedOpacity(
          opacity: _titled ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Text(widget.title, style: Rave.body(size: 16, weight: FontWeight.w700)),
        ),
      ),
      body: CustomScrollView(controller: _scroll, physics: raveVerticalPhysics, slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [rc.isLight ? widget.tint.withValues(alpha: 0.32) : widget.tint, rc.canvas])),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + kToolbarHeight, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Paralaks: sampul bergeser lebih lambat, mengecil & memudar saat digulir; membesar saat ditarik.
              Parallax(
                controller: _scroll,
                drift: 0.45,
                shrink: 0.12,
                fade: true,
                child: Center(
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
              Eyebrow(widget.kind, color: rc.text),
              const SizedBox(height: 6),
              // Judul mengecil menuju app bar.
              Parallax(
                controller: _scroll,
                drift: 0.15,
                shrink: 0.22,
                alignment: Alignment.bottomLeft,
                child: Text(widget.title.toUpperCase(), style: Rave.poster(widget.title.length > 22 ? 32 : 42)),
              ),
              const SizedBox(height: 8),
              DefaultTextStyle(style: Rave.body(size: 13, color: rc.text.withValues(alpha: 0.85)), child: widget.meta),
              const SizedBox(height: 8),
              Row(children: widget.actions),
            ]),
          ),
        ),
        ...widget.slivers,
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }
}
