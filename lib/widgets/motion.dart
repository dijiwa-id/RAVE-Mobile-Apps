import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Gerak RAVE: terasa seperti stiker & tape deck (tekan-amblas, pegas, tepi pita memudar) — ringan & aman:
/// tidak membangun ulang pohon besar per frame (child di-cache, transform/opacity saja), RepaintBoundary di
/// area yang beranimasi, controller selalu di-dispose, dan "kurangi gerakan" → tampil langsung tanpa animasi.
abstract final class RaveMotion {
  /// Animasi tak berujung (shimmer kerangka). Dimatikan di uji agar `pumpAndSettle` selesai.
  static bool infinite = true;

  /// Pengguna meminta gerak dikurangi (Android: hapus animasi / navigasi aksesibel).
  static bool reduced(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    return mq != null && (mq.disableAnimations || mq.accessibleNavigation);
  }

  static const spring = Curves.easeOutBack;
  static const quick = Duration(milliseconds: 180);
}

// ───────────────────────── Tepi memudar untuk daftar horizontal ─────────────────────────

/// Memudarkan tepi kiri/kanan sebuah scrollable horizontal (ShaderMask alfa → netral terhadap tema). Hanya sisi yang
/// masih punya isi yang memudar: tanpa pudar kiri di awal, tanpa pudar kanan di akhir, tanpa pudar bila isi muat.
/// Pudar muncul/hilang dengan animasi. Anak tidak dibangun ulang saat pudar berubah.
class FadedEdges extends StatefulWidget {
  const FadedEdges({super.key, required this.child, this.width = 32});
  final Widget child;
  /// Lebar pudar (dp).
  final double width;
  @override
  State<FadedEdges> createState() => FadedEdgesState();
}

class FadedEdgesState extends State<FadedEdges> {
  bool _left = false, _right = false;

  /// Untuk uji: sisi yang sedang memudar.
  bool get showLeft => _left;
  bool get showRight => _right;

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != Axis.horizontal) return false;
    final l = m.pixels > m.minScrollExtent + 1;
    final r = m.pixels < m.maxScrollExtent - 1;
    if (l != _left || r != _right) setState(() => (_left = l, _right = r));
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = RaveMotion.reduced(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: TweenAnimationBuilder<Offset>(
          tween: Tween(end: Offset(_left ? 1 : 0, _right ? 1 : 0)),
          duration: reduce ? Duration.zero : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: widget.child,
          // Struktur pohon tetap (ShaderMask selalu ada) → posisi gulir anak tidak pernah hilang saat pudar berubah.
          builder: (context, f, child) {
            return ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) {
                final w = rect.width <= 0 ? 1.0 : rect.width;
                final edge = (widget.width / w).clamp(0.0, 0.45);
                return LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 1 - f.dx),
                    Colors.white,
                    Colors.white,
                    Colors.white.withValues(alpha: 1 - f.dy),
                  ],
                  stops: [0, edge, 1 - edge, 1],
                ).createShader(rect);
              },
              child: child,
            );
          },
        ),
      ),
    );
  }
}

/// Daftar horizontal RAVE: tepi memudar + fisika pantul; [snapExtent] → berhenti rapi per kartu (deselerasi halus).
class RaveHorizontalList extends StatelessWidget {
  const RaveHorizontalList({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 10), this.snapExtent, this.controller});
  final List<Widget> children;
  final EdgeInsets padding;
  final double? snapExtent;
  final ScrollController? controller;
  @override
  Widget build(BuildContext context) => FadedEdges(
        child: ListView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          padding: padding,
          physics: snapExtent == null ? const ClampingScrollPhysics() : SnapScrollPhysics(extent: snapExtent!, parent: const ClampingScrollPhysics()),
          children: children,
        ),
      );
}

/// Snap per [extent] dengan deselerasi alami: posisi akhir lemparan (gesekan) dibulatkan ke kartu terdekat, lalu pegas.
class SnapScrollPhysics extends ScrollPhysics {
  const SnapScrollPhysics({required this.extent, super.parent});
  final double extent;

  @override
  SnapScrollPhysics applyTo(ScrollPhysics? ancestor) => SnapScrollPhysics(extent: extent, parent: buildParent(ancestor));

  /// Target snap untuk posisi & kecepatan tertentu (publik untuk uji).
  static double target({required double pixels, required double velocity, required double extent, required double min, required double max}) {
    final end = velocity.abs() < 1 ? pixels : FrictionSimulation(0.135, pixels, velocity).finalX;
    return ((end / extent).roundToDouble() * extent).clamp(min, max);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) || (velocity >= 0 && position.pixels >= position.maxScrollExtent) || extent <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }
    final t = toleranceFor(position);
    final to = target(pixels: position.pixels, velocity: velocity, extent: extent, min: position.minScrollExtent, max: position.maxScrollExtent);
    if ((to - position.pixels).abs() < t.distance && velocity.abs() < t.velocity) return null;
    return ScrollSpringSimulation(spring, position.pixels, to, velocity, tolerance: t);
  }

  @override
  bool get allowImplicitScrolling => false;
}

// ───────────────────────── Tekan-amblas (stiker) ─────────────────────────

/// Saat ditekan: mengecil ~0,96 & bergeser ke arah bayangan (bayangan sablon "amblas"), lalu memantul kembali.
/// Memakai Listener → tidak mengganggu gestur anak (InkWell/GestureDetector); batal bila jari bergeser (scroll).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.96, this.shift = 2});
  final Widget child;
  final double scale, shift;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  Offset? _start;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (RaveMotion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_start != null && (e.position - _start!).distance > 8) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? const Duration(milliseconds: 90) : const Duration(milliseconds: 260),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: AnimatedSlide(
          offset: _down ? Offset(widget.shift / 100, widget.shift / 100) : Offset.zero,
          duration: _down ? const Duration(milliseconds: 90) : const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

// ───────────────────────── Masuk bertahap ─────────────────────────

/// Muncul sekali (pudar + geser 14 dp ke atas) dengan jeda bertingkat per [index] (maks. 8 langkah). [id] mencegah
/// animasi ulang saat baris didaur ulang/kembali ke layar. Kurangi gerakan → langsung tampil.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.index = 0, this.id});
  final Widget child;
  final int index;
  final Object? id;

  static final _seen = <Object>{};

  /// Lupakan riwayat (uji).
  static void reset() => _seen.clear();

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  AnimationController? _c;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c != null) return;
    final id = widget.id;
    final seen = id != null && !Entrance._seen.add(id);
    if (seen || RaveMotion.reduced(context)) return;
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    Future<void>.delayed(Duration(milliseconds: 45 * min(widget.index, 8)), () {
      if (mounted) _c?.forward();
    });
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (c == null) return widget.child;
    final a = CurvedAnimation(parent: c, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(a), child: widget.child),
    );
  }
}

// ───────────────────────── Kerangka shimmer ─────────────────────────

/// Kilau menyapu di atas kerangka statis (satu controller, anak di-cache, RepaintBoundary). Kurangi gerakan / uji →
/// statis.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final run = RaveMotion.infinite && !RaveMotion.reduced(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = context.rc.isLight;
    final hi = light ? const Color(0x99FFFFFF) : const Color(0x22FFFFFF);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) {
          if (!_c.isAnimating) return child!;
          final x = _c.value * 3 - 1;
          return Stack(children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(x - 1, -0.3),
                      end: Alignment(x + 1, 0.3),
                      colors: [hi.withValues(alpha: 0), hi, hi.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Kotak kerangka (warna permukaan tema).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12});
  final double? width;
  final double height;
  @override
  Widget build(BuildContext context) => Container(width: width, height: height, color: context.rc.isLight ? const Color(0xFFE8E0CF) : Rave.raised);
}

/// Kerangka rak: judul + 3 kartu persegi.
class ShelfSkeleton extends StatelessWidget {
  const ShelfSkeleton({super.key, this.cardWidth = 160});
  final double cardWidth;
  @override
  Widget build(BuildContext context) => Shimmer(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 26, 0, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SkeletonBox(width: 150, height: 22),
            const SizedBox(height: 14),
            SizedBox(
              height: cardWidth + 40,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: double.infinity,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (var i = 0; i < 3; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SkeletonBox(width: cardWidth - 14, height: cardWidth - 14),
                        const SizedBox(height: 10),
                        SkeletonBox(width: cardWidth * 0.7),
                        const SizedBox(height: 6),
                        SkeletonBox(width: cardWidth * 0.45, height: 10),
                      ]),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      );
}

/// Kerangka daftar: baris sampul kecil + dua garis teks.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 8});
  final int rows;
  @override
  Widget build(BuildContext context) => Shimmer(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (var i = 0; i < rows; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const SkeletonBox(width: 52, height: 52),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      FractionallySizedBox(widthFactor: 0.4 + (i * 37 % 40) / 100, child: const SkeletonBox(height: 13)),
                      const SizedBox(height: 8),
                      const FractionallySizedBox(widthFactor: 0.35, child: SkeletonBox(height: 10)),
                    ]),
                  ),
                ]),
              ),
          ],
        ),
      );
}

// ───────────────────────── Hati "pop" ─────────────────────────

/// Ikon suka: saat menjadi disukai → hati memantul + semburan garis mustard kecil (sekali).
class LikeHeart extends StatefulWidget {
  const LikeHeart({super.key, required this.liked, this.size = 24, this.color, this.likedColor});
  final bool liked;
  final double size;
  final Color? color, likedColor;
  @override
  State<LikeHeart> createState() => _LikeHeartState();
}

class _LikeHeartState extends State<LikeHeart> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void didUpdateWidget(LikeHeart old) {
    super.didUpdateWidget(old);
    if (widget.liked && !old.liked && !RaveMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      widget.liked ? Icons.favorite : Icons.favorite_border,
      size: widget.size,
      color: widget.liked ? (widget.likedColor ?? Rave.mustard) : widget.color,
    );
    return AnimatedBuilder(
      animation: _c,
      child: icon,
      builder: (context, child) {
        final t = _c.value;
        if (t == 0 || t == 1) return child!;
        final pop = 1 + 0.35 * sin(pi * min(1.0, t * 1.6));
        return CustomPaint(
          painter: _BurstPainter(t),
          child: Transform.scale(scale: pop, child: child),
        );
      },
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final p = Paint()
      ..color = Rave.mustard.withValues(alpha: (1 - t).clamp(0.0, 1.0))
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.square;
    for (var i = 0; i < 8; i++) {
      final a = i * pi / 4 + pi / 8;
      final d = Offset(cos(a), sin(a));
      canvas.drawLine(c + d * (r * (0.7 + t * 0.6)), c + d * (r * (0.9 + t * 0.9)), p);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

// ───────────────────────── Transisi halaman ─────────────────────────

/// Transisi RAVE untuk rute yang didorong: geser cepat dari kanan (8%) + pudar; halaman di bawahnya sedikit mundur.
/// Kurangi gerakan → tanpa animasi.
class RavePageTransitionsBuilder extends PageTransitionsBuilder {
  const RavePageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (RaveMotion.reduced(context)) return child;
    final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    final back = CurvedAnimation(parent: secondaryAnimation, curve: Curves.easeOutCubic);
    return SlideTransition(
      position: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)).animate(back),
      child: FadeTransition(
        opacity: a,
        child: SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a), child: child),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 260);
}

// ───────────────────────── Header yang melipat saat digulir ─────────────────────────

/// Offset gulir [controller] yang aman dibaca di builder (0 bila belum/lebih dari satu posisi terpasang).
double scrollOffsetOf(ScrollController controller) => controller.hasClients && controller.positions.length == 1 ? controller.offset : 0.0;

/// Kemajuan 0→1 dari [o] di rentang [begin, end] dengan kurva easeOut (rumus bersama header Artis & koleksi).
double scrollProgress(double o, double begin, double end) => Curves.easeOut.transform(((o - begin) / (end - begin)).clamp(0.0, 1.0));

/// App bar transparan di atas header yang latarnya & judulnya muncul BERTAHAP mengikuti gulir (bukan berganti
/// mendadak di satu titik): latar terisi di rentang [background], judul kecil menyusul di rentang [titleRange]
/// sambil naik 8 dp. Dipakai halaman Artis dan halaman koleksi (album/playlist/podcast) agar interaksinya sama.
class CollapsingAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CollapsingAppBar({
    super.key,
    required this.controller,
    required this.title,
    required this.color,
    required this.background,
    required this.titleRange,
    this.titleStyle,
    this.foregroundColor,
    this.systemOverlayStyle,
  });
  final ScrollController controller;
  final String title;
  final Color color;
  final (double, double) background, titleRange;
  final TextStyle? titleStyle;
  final Color? foregroundColor;
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final o = scrollOffsetOf(controller);
        final bg = scrollProgress(o, background.$1, background.$2);
        final t = scrollProgress(o, titleRange.$1, titleRange.$2);
        return AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: foregroundColor,
          systemOverlayStyle: systemOverlayStyle,
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: color.a * bg),
              border: Border(bottom: BorderSide(color: (foregroundColor ?? Colors.white).withValues(alpha: 0.06 * bg))),
            ),
            child: const SizedBox.expand(),
          ),
          title: Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle)),
          ),
        );
      },
    );
  }
}

/// Gulir scrollable vertikal terluar di bawah [context] ke atas (ketuk ulang tab aktif). Kurangi gerakan → lompat.
void scrollToTop(BuildContext? context) {
  if (context == null) return;
  ScrollPosition? found;
  void visit(Element e) {
    if (found != null) return;
    if (e is StatefulElement && e.state is ScrollableState) {
      final p = (e.state as ScrollableState).position;
      if (p.axis == Axis.vertical && p.hasContentDimensions && p.maxScrollExtent > 0) {
        found = p;
        return;
      }
    }
    e.visitChildElements(visit);
  }

  context.visitChildElements(visit);
  final p = found;
  if (p == null || p.pixels <= p.minScrollExtent) return;
  if (RaveMotion.reduced(context)) {
    p.jumpTo(p.minScrollExtent);
  } else {
    p.animateTo(p.minScrollExtent, duration: Duration(milliseconds: (220 + p.pixels / 6).clamp(260, 650).round()), curve: Curves.easeOutCubic);
  }
}

/// Tarik ke bawah untuk menutup (layar Sedang Diputar): layar mengikuti jari; dilepas jauh/cepat → [onDismiss],
/// selain itu memantul kembali. Hanya transform anak yang di-cache.
class DragToDismiss extends StatefulWidget {
  const DragToDismiss({super.key, required this.child, required this.onDismiss});
  final Widget child;
  final VoidCallback onDismiss;
  @override
  State<DragToDismiss> createState() => _DragToDismissState();
}

class _DragToDismissState extends State<DragToDismiss> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, lowerBound: 0, upperBound: 4000);
  bool _done = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onVerticalDragUpdate: (d) {
          if (_done) return;
          _c.value = (_c.value + d.delta.dy).clamp(0.0, 4000.0);
        },
        onVerticalDragEnd: (d) {
          if (_done) return;
          final v = d.primaryVelocity ?? 0;
          if (_c.value > 140 || v > 800) {
            _done = true;
            widget.onDismiss();
          } else {
            _c.animateTo(0, duration: RaveMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 320), curve: Curves.easeOutBack);
          }
        },
        child: AnimatedBuilder(
          animation: _c,
          child: widget.child,
          builder: (_, child) => _c.value == 0 ? child! : Transform.translate(offset: Offset(0, _c.value), child: child),
        ),
      );
}

// ───────────────────────── Overscroll "kain ditarik" + segarkan ─────────────────────────

/// Fisika vertikal halaman: berhenti tegas di tepi (tanpa celah kosong) — tepi atas/bawah ditangani efek regang
/// [RaveScrollBehavior] (isi & latar meregang seperti kain, tidak menampakkan kanvas kosong).
const raveVerticalPhysics = AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());

/// Perilaku gulir aplikasi: efek regang (stretch) di semua platform & sumbu; fisika jepit sebagai bawaan.
class RaveScrollBehavior extends MaterialScrollBehavior {
  const RaveScrollBehavior();
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      StretchingOverscrollIndicator(axisDirection: details.direction, clipBehavior: details.decorationClipBehavior ?? Clip.hardEdge, child: child);
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => const ClampingScrollPhysics();
}

/// Tarik-segarkan RAVE: isi meregang (lihat [RaveScrollBehavior]) sementara stiker kaset turun dari atas — gulungan
/// pita berputar mengikuti tarikan; melewati ambang → getar ringan sekali + "Lepas untuk segarkan"; dilepas → pegas
/// teredam kritis ke posisi istirahat, gulungan terus berputar sampai [onRefresh] selesai, lalu menghilang lembut.
/// Hanya menanggapi scrollable vertikal terdekat (depth 0) yang diseret di posisi paling atas. Satu pemicu per tarikan.
class RaveRefresh extends StatefulWidget {
  const RaveRefresh({super.key, required this.child, required this.onRefresh});
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Jarak tarik (dp, setelah hambatan) untuk memicu segarkan.
  static const threshold = 88.0;

  @override
  State<RaveRefresh> createState() => RaveRefreshState();
}

class RaveRefreshState extends State<RaveRefresh> with TickerProviderStateMixin {
  /// Jarak tarik saat ini (dp). Pegas memakai controller tak berbatas yang sama.
  late final AnimationController _pull = AnimationController.unbounded(vsync: this);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _dragging = false, _armed = false, _refreshing = false;

  /// Untuk uji.
  bool get refreshing => _refreshing;
  double get pull => _pull.value;

  static final _spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 1.0);

  @override
  void dispose() {
    _pull.dispose();
    _spin.dispose();
    super.dispose();
  }

  bool get _reduced => RaveMotion.reduced(context);

  void _to(double target) {
    if (_reduced) {
      _pull.value = target;
    } else {
      _pull.animateWith(SpringSimulation(_spring, _pull.value, target, 0));
    }
  }

  /// Hanya [RaveRefresh] terdekat dari scrollable yang menangani (ApiView bersarang → satu indikator, satu pemicu).
  bool _mine(ScrollNotification n) {
    final c = n.context;
    return c == null || c.findAncestorStateOfType<RaveRefreshState>() == this;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || _refreshing || !_mine(n)) return false;
    if (n is ScrollStartNotification) {
      _dragging = n.dragDetails != null;
      if (_dragging) _pull.stop();
    } else if (n is OverscrollNotification) {
      if (n.dragDetails != null && n.overscroll < 0 && n.metrics.extentBefore == 0) {
        _dragging = true;
        // Hambatan makin besar seiring tarikan (terasa elastis).
        final resist = 0.55 * (1 - (_pull.value / 260).clamp(0.0, 0.85));
        _pull.value = _pull.value + -n.overscroll * resist;
        if (!_armed && _pull.value >= RaveRefresh.threshold) {
          _armed = true;
          HapticFeedback.lightImpact();
        }
      }
    } else if (n is ScrollUpdateNotification) {
      final d = n.scrollDelta ?? 0;
      if (n.dragDetails != null && _pull.value > 0 && d > 0) {
        _pull.value = (_pull.value - d).clamp(0.0, double.infinity);
        if (_pull.value < RaveRefresh.threshold) _armed = false;
      }
    } else if (n is ScrollEndNotification) {
      if (_dragging) _release();
      _dragging = false;
    }
    return false;
  }

  Future<void> _release() async {
    if (_pull.value <= 0) return;
    if (!_armed) return _to(0);
    _armed = false;
    setState(() => _refreshing = true);
    _to(RaveRefresh.threshold * 0.72);
    if (!_reduced) _spin.repeat();
    // Segarkan juga [RaveRefresh] leluhur (mis. ringkasan Koleksi di atas daftar artis/album) — dalam satu tarikan.
    final all = <Future<void> Function()>[widget.onRefresh];
    for (var a = context.findAncestorStateOfType<RaveRefreshState>(); a != null; a = a.context.findAncestorStateOfType<RaveRefreshState>()) {
      all.add(a.widget.onRefresh);
    }
    try {
      await Future.wait([for (final f in all) Future.sync(f).catchError((Object _) {})]);
    } catch (_) {
      // galat ditangani pemanggil (ApiView menampilkan data lama)
    } finally {
      if (mounted) {
        _spin.stop();
        setState(() => _refreshing = false);
        _to(0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.maybeRead(context)?.s ?? S.of('id');
    final top = MediaQuery.paddingOf(context).top;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pull, _spin]),
                builder: (context, _) {
                  final p = _pull.value;
                  if (p <= 0.5 && !_refreshing) return const SizedBox.shrink();
                  final progress = (p / RaveRefresh.threshold).clamp(0.0, 1.0);
                  final label = _refreshing ? s.refreshing : (p >= RaveRefresh.threshold ? s.releaseToRefresh : s.pullToRefresh);
                  final reel = _refreshing ? _spin.value : progress * 1.5;
                  return Transform.translate(
                    offset: Offset(0, top + min(p, 150) * 0.55 - 44 * (1 - progress)),
                    child: Opacity(
                      opacity: _refreshing ? 1 : progress,
                      child: Center(child: _RefreshSticker(reel: reel, label: label, armed: _refreshing || p >= RaveRefresh.threshold)),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Stiker kaset kecil: badan ink bertepi, dua gulungan berjari-jari yang berputar ([reel] = putaran), label mono.
class _RefreshSticker extends StatelessWidget {
  const _RefreshSticker({required this.reel, required this.label, required this.armed});
  final double reel;
  final String label;
  final bool armed;
  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: label,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
          decoration: BoxDecoration(color: Rave.ink, border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(3, 3))]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 40, height: 24, child: CustomPaint(painter: _CassettePainter(reel, armed))),
            const SizedBox(width: 8),
            Text(label.toUpperCase(), style: Rave.label(size: 10, color: armed ? Rave.mustard : Rave.paper)),
          ]),
        ),
      );
}

class _CassettePainter extends CustomPainter {
  _CassettePainter(this.turns, this.armed);
  final double turns;
  final bool armed;
  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2));
    canvas.drawRRect(body, Paint()..color = armed ? Rave.mustard : const Color(0xFF3A363E));
    final win = Rect.fromLTWH(size.width * 0.14, size.height * 0.22, size.width * 0.72, size.height * 0.5);
    canvas.drawRect(win, Paint()..color = Rave.ink);
    final r = size.height * 0.2;
    for (final cx in [win.left + r * 1.3, win.right - r * 1.3]) {
      final c = Offset(cx, win.center.dy);
      canvas.drawCircle(c, r, Paint()..color = Rave.paper);
      final spoke = Paint()
        ..color = Rave.ink
        ..strokeWidth = 1.4;
      for (var k = 0; k < 3; k++) {
        final a = turns * 2 * pi + k * 2 * pi / 3;
        canvas.drawLine(c, c + Offset(cos(a), sin(a)) * r * 0.85, spoke);
      }
    }
  }

  @override
  bool shouldRepaint(_CassettePainter old) => old.turns != turns || old.armed != armed;
}
