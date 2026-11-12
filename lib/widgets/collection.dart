import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'common.dart';

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
  });
  final String kind, title;
  final String? cover;
  final Widget? art;
  final Widget meta;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Color tint;
  final bool round;

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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: _titled ? widget.tint.withValues(alpha: 0.96) : Colors.transparent,
        title: AnimatedOpacity(
          opacity: _titled ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Text(widget.title, style: Rave.body(size: 16, weight: FontWeight.w700)),
        ),
      ),
      body: CustomScrollView(controller: _scroll, slivers: [
        SliverToBoxAdapter(
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [widget.tint, Rave.canvas])),
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + kToolbarHeight, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: DecoratedBox(
                  decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 12))]),
                  child: widget.art ?? Cover(widget.cover, size: art, round: widget.round),
                ),
              ),
              const SizedBox(height: 20),
              Eyebrow(widget.kind, color: Rave.paper),
              const SizedBox(height: 6),
              Text(widget.title.toUpperCase(), style: Rave.poster(widget.title.length > 22 ? 32 : 42)),
              const SizedBox(height: 8),
              DefaultTextStyle(style: Rave.body(size: 13, color: Rave.paper.withValues(alpha: 0.85)), child: widget.meta),
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
