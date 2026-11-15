import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../screens/routes.dart';
import 'common.dart';
import 'media.dart';
import 'motion.dart';

/// Tinggi banner "Mulai di RAVE" — kartu "Pilihan untuk …" setinggi ini juga (web `--gs-h`).
const gsHeight = 272.0;

/// Langkah "Mulai di RAVE" (web components/fan/GettingStarted.tsx): ikon & warna RAVE per langkah.
const _steps = <String, ({IconData icon, Color bg, Color fg})>{
  'play': (icon: Icons.search_rounded, bg: Rave.mustard, fg: Rave.ink),
  'like': (icon: Icons.favorite_rounded, bg: Rave.purple, fg: Rave.paper),
  'playlist': (icon: Icons.queue_music_rounded, bg: Rave.teal, fg: Rave.paper),
  'follow': (icon: Icons.mic_external_on_rounded, bg: Rave.berry, fg: Rave.paper),
  'live': (icon: Icons.sensors_rounded, bg: Rave.plum, fg: Rave.paper),
  'events': (icon: Icons.confirmation_number_rounded, bg: Color(0xFF232025), fg: Rave.paper),
};

/// Urutan langkah yang tampil (Live/Event mengikuti modul platform).
List<String> gsStepIds({required bool liveOn, required bool eventsOn}) => ['play', 'like', 'playlist', 'follow', if (liveOn) 'live', if (eventsOn) 'events'];

/// Banner permanen "Mulai di RAVE": satu kartu per tampilan (geser), "Langkah X dari N", judul Staatliches, CTA +
/// "Tips berikutnya" (langkah terakhir: "Ulang dari awal"), titik halaman. [onCta] menerima id langkah.
class GettingStarted extends StatefulWidget {
  const GettingStarted({super.key, required this.liveOn, required this.eventsOn, required this.onCta, this.covers = const []});
  final bool liveOn, eventsOn;
  final void Function(String step) onCta;
  final List<String> covers;
  @override
  State<GettingStarted> createState() => _GettingStartedState();
}

class _GettingStartedState extends State<GettingStarted> {
  final _ctl = PageController();
  int _index = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (!_ctl.hasClients) return;
    final reduce = MediaQuery.disableAnimationsOf(context);
    reduce ? _ctl.jumpToPage(i) : _ctl.animateToPage(i, duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final ids = gsStepIds(liveOn: widget.liveOn, eventsOn: widget.eventsOn);
    final index = _index.clamp(0, ids.length - 1);
    return Semantics(
      container: true,
      label: s.gsTitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(s.gsTitle.toUpperCase(), style: Rave.poster(28)),
        ),
        SizedBox(
          height: gsHeight + 8,
          // Tepi memudar + paralaks isi kartu terhadap geseran halaman.
          child: FadedEdges(
            width: 24,
            child: PageView.builder(
            controller: _ctl,
            physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
            itemCount: ids.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final last = i == ids.length - 1;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 22, 8),
                child: _StepCard(
                  id: ids[i],
                  kicker: s.gsStepOf(i + 1, ids.length),
                  more: last ? s.gsRestart : s.gsNext,
                  covers: widget.covers,
                  coverOffset: i,
                  onCta: () => widget.onCta(ids[i]),
                  onMore: () => _go(last ? 0 : i + 1),
                  pager: _ctl,
                  index: i,
                ),
              );
            },
          ),
          ),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < ids.length; i++)
            Semantics(
              button: true,
              selected: i == index,
              label: s.gsStepOf(i + 1, ids.length),
              child: GestureDetector(
                onTap: () => _go(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: i == index ? 22 : 8,
                    height: 8,
                    color: i == index ? context.rc.accent : (context.rc.isLight ? const Color(0x33181818) : const Color(0x40FFFFFF)),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.id, required this.kicker, required this.more, required this.onCta, required this.onMore, required this.covers, required this.coverOffset, this.pager, this.index = 0});
  final String id, kicker, more;
  final VoidCallback onCta, onMore;
  final List<String> covers;
  final int coverOffset;
  /// Paralaks: isi bergeser lebih lambat dari kartu, kolase lebih cepat.
  final PageController? pager;
  final int index;

  Widget _px(BuildContext context, Widget child, [double k = 36]) {
    final c = pager;
    if (c == null || RaveMotion.reduced(context)) return child;
    return AnimatedBuilder(
      animation: c,
      child: child,
      builder: (_, child) {
        final page = c.positions.length == 1 && c.position.hasContentDimensions ? (c.page ?? index.toDouble()) : index.toDouble();
        return Transform.translate(offset: Offset((page - index).clamp(-1.0, 1.0) * k, 0), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final m = _steps[id]!;
    final st = app.s.gsStep(id);
    final mustard = m.bg == Rave.mustard;
    return Container(
      decoration: BoxDecoration(color: m.bg, border: Border.all(color: Rave.ink, width: 2), boxShadow: context.rc.hard(6)),
      clipBehavior: Clip.hardEdge,
      child: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 460;
        return Stack(children: [
          const Positioned.fill(child: CustomPaint(painter: HalftonePainter(color: Color(0x1A000000), step: 8, radius: 1))),
          if (wide && covers.isNotEmpty) ..._collage(context, app, box.maxWidth),
          _px(context, Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: wide ? box.maxWidth * 0.58 : double.infinity),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: mustard ? Rave.ink : const Color(0x38000000),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(m.icon, size: 13, color: mustard ? Rave.mustard : m.fg),
                    const SizedBox(width: 6),
                    Text(kicker.toUpperCase(), style: Rave.label(size: 10.5, color: mustard ? Rave.mustard : m.fg)),
                  ]),
                ),
                const SizedBox(height: 12),
                // Judul + isi mengambil sisa tinggi; isi terpotong rapi bila ruang sempit (tak pernah overflow).
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(st.title.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.poster(box.maxWidth < 340 ? 36 : 44, color: m.fg).copyWith(height: 0.9)),
                    const SizedBox(height: 10),
                    Flexible(child: Text(st.body, maxLines: 3, overflow: TextOverflow.ellipsis, style: Rave.body(size: 15, color: m.fg.withValues(alpha: 0.85), height: 1.3))),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Flexible(
                    flex: 3,
                    child: Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onCta,
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: mustard ? Rave.ink : Rave.paper,
                          border: Border.all(color: Rave.ink, width: 2),
                          boxShadow: [BoxShadow(color: mustard ? const Color(0x59000000) : context.rc.shadow, offset: const Offset(3, 3))],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Flexible(child: Text(st.cta, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 15, weight: FontWeight.w800, color: mustard ? Rave.mustard : Rave.ink))),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18, color: mustard ? Rave.mustard : Rave.ink),
                        ]),
                      ),
                    ),
                  ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    flex: 2,
                    child: Semantics(
                    button: true,
                    child: GestureDetector(
                      onTap: onMore,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          more,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Rave.body(size: 14, weight: FontWeight.w800, color: m.fg.withValues(alpha: 0.9)).copyWith(
                            decoration: TextDecoration.underline,
                            decorationThickness: 2,
                            decorationColor: m.fg,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ),
                ]),
              ]),
            ),
          )),
        ]);
      }),
    );
  }

  /// Kolase 3 sampul miring di kanan (hanya kartu lebar, seperti web).
  List<Widget> _collage(BuildContext context, AppState app, double w) {
    final size = (w * 0.4 * 0.46).clamp(110.0, 170.0);
    Widget img(int k) {
      final url = app.api.media(covers[(coverOffset + k) % covers.length]);
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Rave.hover, border: Border.fromBorderSide(BorderSide(color: Rave.ink, width: 2)), boxShadow: [BoxShadow(color: Color(0x73000000), offset: Offset(5, 5))]),
        child: url == null ? null : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover, memCacheWidth: 340, errorWidget: (_, _, _) => const SizedBox()),
      );
    }

    return [
      Positioned(top: 22, right: w * 0.4 * 0.34, child: _px(context, Transform.rotate(angle: -0.14, child: img(0)), -60)),
      Positioned(top: 54, right: 8, child: _px(context, Transform.rotate(angle: 0.12, child: img(1)), -90)),
      Positioned(bottom: -30, right: w * 0.4 * 0.22, child: _px(context, Transform.rotate(angle: -0.035, child: img(2)), -120)),
    ];
  }
}

/// Tile "Pilihan untuk …" (web `PickTile`): sampul mengisi kartu setinggi banner, judul & subjudul di bawah dengan
/// gradasi, tombol putar/jeda kotak RAVE. Diputar → bayangan mustard.
class PickTile extends StatelessWidget {
  const PickTile({super.key, required this.id, required this.title, this.subtitle, this.image, required this.width});
  final String id, title;
  final String? subtitle, image;
  final double width;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final key = 'playlist:$id';
    final url = app.api.media(image);
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final active = app.player.isActive(key);
        return Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 14, 8),
          child: GestureDetector(
            onTap: () => openItem(context, 'playlist', id),
            child: Pressable(scale: 0.97, child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: width,
              height: gsHeight,
              decoration: BoxDecoration(
                color: Rave.hover,
                border: Border.all(color: Rave.ink, width: 2),
                boxShadow: [BoxShadow(color: active ? Rave.mustard : context.rc.shadow, offset: active ? const Offset(6, 6) : const Offset(5, 5))],
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(fit: StackFit.expand, children: [
                if (url != null)
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    memCacheWidth: (width * MediaQuery.devicePixelRatioOf(context)).round(),
                    errorWidget: (_, _, _) => const _PickFallback(),
                  )
                else
                  const _PickFallback(),
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xEB0E0C0F)], stops: [0.35, 1])),
                ),
                Positioned(
                  left: 14,
                  right: 12,
                  bottom: 14,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 18, weight: FontWeight.w800, color: active ? Rave.mustard : Rave.paper)),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: Rave.paper.withValues(alpha: 0.75))),
                        ],
                      ]),
                    ),
                    const SizedBox(width: 10),
                    PlayFab(size: 40, playKey: key, semantic: '${app.s.play} $title', onPlay: () => playMedia(context, 'playlist', id)),
                  ]),
                ),
              ]),
            )),
          ),
        );
      },
    );
  }
}

class _PickFallback extends StatelessWidget {
  const _PickFallback();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.plum])),
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: HalftonePainter(color: Color(0x26FFFFFF), step: 8, radius: 1)),
          Center(child: Icon(Icons.queue_music_rounded, size: 64, color: Color(0x99F4C21F))),
        ]),
      );
}
