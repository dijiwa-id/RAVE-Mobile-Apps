import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'login.dart';
import 'shell.dart';

/// Gerbang pembuka: splash animasi → onboarding (sekali, saat pertama dibuka) → aplikasi (sebagai tamu atau akun).
class IntroGate extends StatefulWidget {
  const IntroGate({super.key});
  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  String stage = 'splash';

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final child = switch (stage) {
      'splash' => Splash(onDone: () => setState(() => stage = app.settings.onboarded ? 'app' : 'onboarding')),
      'onboarding' => Onboarding(onDone: () {
          app.settings.setOnboarded();
          setState(() => stage = 'app');
        }),
      _ => const Shell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: c)),
      child: KeyedSubtree(key: ValueKey(stage), child: child),
    );
  }
}

// ======================================================================= SPLASH

/// Splash: piringan berputar masuk, huruf R-A-V-E jatuh seperti potongan kertas ransom-note, stiker menempel.
class Splash extends StatefulWidget {
  const Splash({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  @override
  void initState() {
    super.initState();
    c.forward().whenComplete(widget.onDone);
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOutBack]) => CurvedAnimation(parent: c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final disc = min(size.width, size.height) * 0.92;
    const letters = ['R', 'A', 'V', 'E'];
    const paper = [Rave.mustard, Rave.paper, Rave.purple, Rave.ink];
    const ink = [Rave.ink, Rave.ink, Rave.paper, Rave.mustard];
    const tilt = [-0.10, 0.07, -0.05, 0.11];
    return Scaffold(
      backgroundColor: Rave.canvas,
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final discIn = _iv(0.0, 0.45, Curves.easeOutCubic).value;
          return Stack(fit: StackFit.expand, children: [
            // Latar: gradien ungu yang "menyala" dari tengah.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9 + 0.3 * discIn,
                  colors: [Color.lerp(Rave.canvas, Rave.purple, discIn)!, Rave.plum.withValues(alpha: discIn), Rave.canvas],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            // Piringan hitam berputar masuk dari bawah.
            Positioned(
              left: (size.width - disc) / 2,
              top: size.height * 0.5 - disc / 2 + (1 - discIn) * size.height * 0.6,
              child: Transform.rotate(
                angle: c.value * pi * 3,
                child: Opacity(opacity: discIn.clamp(0, 1), child: Vinyl(size: disc, label: Rave.mustard)),
              ),
            ),
            // Huruf ransom-note jatuh bergantian.
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 4; i++)
                  Builder(builder: (_) {
                    final t = _iv(0.32 + i * 0.08, 0.62 + i * 0.08).value;
                    return Opacity(
                      opacity: t.clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * -120),
                        child: Transform.rotate(
                          angle: tilt[i] * (2 - t),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                            decoration: BoxDecoration(
                              color: paper[i],
                              border: i == 3 ? Border.all(color: Rave.paper, width: 3) : null,
                              boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(4, 4))],
                            ),
                            child: Text(letters[i], style: Rave.poster(min(size.width * 0.2, 96), color: ink[i])),
                          ),
                        ),
                      ),
                    );
                  }),
              ]),
            ),
            // Stiker menempel di bawah wordmark.
            Align(
              alignment: const Alignment(0.35, 0.28),
              child: Transform.scale(
                scale: _iv(0.72, 0.9).value.clamp(0, 2),
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Rave.paper, border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                    child: Text('DIY · INDIE · LIVE', style: Rave.label(size: 11, color: Rave.ink)),
                  ),
                ),
              ),
            ),
            // Nomor katalog ala label rekaman.
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: Opacity(
                opacity: _iv(0.6, 0.9, Curves.easeOut).value.clamp(0, 1),
                child: Text('RV-MOBILE · ${DateTime.now().year} · DIJIWA.ID', textAlign: TextAlign.center, style: Rave.label(size: 10, color: Rave.paper.withValues(alpha: 0.55))),
              ),
            ),
            const IgnorePointer(child: Grain()),
          ]);
        },
      ),
    );
  }
}

// =================================================================== ONBOARDING

/// Onboarding 3 halaman bergaya poster gig. Halaman terakhir: Daftar / Masuk / Lanjut sebagai tamu.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  final _pc = PageController();
  double page = 0;

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => setState(() => page = _pc.page ?? 0));
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _auth(bool signup) async {
    final ok = await openLogin(context, signup: signup);
    if (ok) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final pages = [
      (tint: Rave.purple, eyebrow: '01 / 03', title: s.ob1Title, body: s.ob1Body, art: const _ArtCovers()),
      (tint: Rave.teal, eyebrow: '02 / 03', title: s.ob2Title, body: s.ob2Body, art: const _ArtLyrics()),
      (tint: Rave.berry, eyebrow: '03 / 03', title: s.ob3Title, body: s.ob3Body, art: const _ArtLive()),
    ];
    final i = page.round().clamp(0, 2);
    final last = page > 1.5;
    final bg = Color.lerp(pages[page.floor().clamp(0, 2)].tint, pages[page.ceil().clamp(0, 2)].tint, page - page.floor())!;
    return Scaffold(
      backgroundColor: Rave.canvas,
      body: Stack(fit: StackFit.expand, children: [
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bg, Rave.canvas], stops: const [0, 0.78]))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(children: [
                Image.asset('assets/brand/rave-logo.webp', height: 26),
                const Spacer(),
                for (final l in ['id', 'en'])
                  TextButton(
                    onPressed: () => app.settings.setLocale(l),
                    child: Text(l.toUpperCase(), style: Rave.label(size: 11, color: app.settings.locale == l ? Rave.mustard : Rave.paper.withValues(alpha: 0.6))),
                  ),
                if (!last) TextButton(onPressed: () => _pc.animateToPage(2, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic), child: Text(s.obSkip.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper))),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: pages.length,
                itemBuilder: (_, k) {
                  final d = (page - k).clamp(-1.0, 1.0);
                  final pg = pages[k];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Center(
                          // Paralaks: ilustrasi bergeser lebih lambat dari teks.
                          child: Transform.translate(offset: Offset(d * -60, 0), child: Opacity(opacity: (1 - d.abs()).clamp(0.0, 1.0), child: pg.art)),
                        ),
                      ),
                      Eyebrow(pg.eyebrow, color: Rave.mustard),
                      const SizedBox(height: 10),
                      Transform.translate(
                        offset: Offset(d * 40, 0),
                        child: Text(pg.title.toUpperCase(), style: Rave.poster(MediaQuery.sizeOf(context).width > 400 ? 50 : 42)),
                      ),
                      const SizedBox(height: 12),
                      Text(pg.body, style: Rave.body(size: 15.5, color: Rave.paper.withValues(alpha: 0.85), height: 1.45)),
                      const SizedBox(height: 20),
                    ]),
                  );
                },
              ),
            ),
            // Indikator halaman: bilah mustard.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(children: [
                for (var k = 0; k < 3; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    height: 5,
                    width: k == i ? 34 : 12,
                    color: k == i ? Rave.mustard : Rave.paper.withValues(alpha: 0.3),
                  ),
              ]),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: last
                    ? Column(key: const ValueKey('cta'), children: [
                        PrimaryButton(label: s.signup, onTap: () => _auth(true)),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _Ghost(label: s.signIn, onTap: () => _auth(false))),
                          const SizedBox(width: 10),
                          Expanded(child: _Ghost(label: s.obGuest, onTap: widget.onDone)),
                        ]),
                      ])
                    : SizedBox(
                        key: const ValueKey('next'),
                        width: double.infinity,
                        child: PrimaryButton(label: s.obNext, onTap: () => _pc.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic)),
                      ),
              ),
            ),
          ]),
        ),
        const IgnorePointer(child: Grain()),
      ]),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: Rave.paper.withValues(alpha: 0.7), width: 1.5)),
          child: Text(label.toUpperCase(), style: Rave.label(size: 11.5, color: Rave.paper)),
        ),
      );
}

// ================================================================ ILUSTRASI

/// Piringan hitam (alur, label tengah, kilap) — digambar, tanpa aset.
class Vinyl extends StatelessWidget {
  const Vinyl({super.key, required this.size, this.label = Rave.mustard});
  final double size;
  final Color label;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _VinylPainter(label));
}

class _VinylPainter extends CustomPainter {
  _VinylPainter(this.label);
  final Color label;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF121113));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var k = r * 0.38; k < r * 0.97; k += r * 0.025) {
      canvas.drawCircle(c, k, groove);
    }
    // Kilap diagonal.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.10), Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: 0.07), Colors.transparent],
          stops: const [0, 0.08, 0.18, 0.5, 0.58, 0.68],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r * 0.34, Paint()..color = label);
    final tp = TextPainter(text: TextSpan(text: 'RAVE', style: Rave.poster(r * 0.16, color: Rave.ink)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, r * 0.2));
    canvas.drawCircle(c, r * 0.035, Paint()..color = Rave.canvas);
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.label != label;
}

/// Halaman 1: tumpukan sampul berwarna RAVE yang miring seperti kliping di dinding.
class _ArtCovers extends StatelessWidget {
  const _ArtCovers();
  @override
  Widget build(BuildContext context) {
    const cols = [Rave.mustard, Rave.purpleSoft, Rave.teal, Rave.berry];
    const rot = [-0.16, 0.10, -0.05, 0.14];
    const off = [Offset(-62, -66), Offset(66, -44), Offset(-54, 62), Offset(58, 76)];
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(alignment: Alignment.center, children: [
        const Positioned(right: -40, child: Vinyl(size: 230, label: Rave.purple)),
        for (var k = 0; k < 4; k++)
          Transform.translate(
            offset: off[k],
            child: Transform.rotate(
              angle: rot[k],
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(color: cols[k], border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(5, 5))]),
                child: Stack(children: [
                  Positioned(left: 10, top: 10, child: Text(['SENJA', 'NIRMALA', 'DARA', 'KOTA MATI'][k], style: Rave.poster(20, color: k == 0 ? Rave.ink : Rave.paper))),
                  Positioned(right: 8, bottom: 8, child: Text('RV-0${k + 1}', style: Rave.label(size: 8.5, color: k == 0 ? Rave.ink : Rave.paper))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Halaman 2: kartu lirik tersinkron + ekualiser (dengar di mana saja).
class _ArtLyrics extends StatelessWidget {
  const _ArtLyrics();
  @override
  Widget build(BuildContext context) {
    final lines = ['Kau datang seperti ombak pagi', 'Hangat, pelan, lalu pergi', 'Kutulis namamu di pasir', 'Biar laut yang menyimpan'];
    return Transform.rotate(
      angle: -0.04,
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Rave.plum, border: Border.all(color: Rave.paper, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(6, 6))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Equalizer(playing: true),
            const SizedBox(width: 10),
            Text('PASANG SURUT · DARA LAUT', style: Rave.label(size: 9.5, color: Rave.mustard)),
          ]),
          const SizedBox(height: 14),
          for (var k = 0; k < lines.length; k++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(lines[k], style: Rave.body(size: 19, weight: FontWeight.w800, color: k == 1 ? Rave.mustard : Rave.paper.withValues(alpha: k < 1 ? 0.45 : 0.8))),
            ),
          const SizedBox(height: 14),
          ClipRect(child: LinearProgressIndicator(value: 0.42, minHeight: 3, color: Rave.paper, backgroundColor: Rave.paper.withValues(alpha: 0.2))),
        ]),
      ),
    );
  }
}

/// Halaman 3: tiket gig + stiker LIVE (dukung artis: live, tiket, ikuti).
class _ArtLive extends StatelessWidget {
  const _ArtLive();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: 280,
        child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(
            angle: 0.06,
            child: Container(
              width: 270,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Rave.paper, border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(6, 6))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('ADMIT ONE · RV-TIX', style: Rave.label(size: 9.5, color: Rave.berry)),
                const SizedBox(height: 6),
                Text('SENJA KOLEKTIF', style: Rave.poster(36, color: Rave.ink)),
                Text('LIVE DI BANDUNG', style: Rave.poster(22, color: Rave.purple)),
                const SizedBox(height: 10),
                Container(height: 1.5, color: Rave.ink),
                const SizedBox(height: 8),
                Row(children: [
                  Text('SAB · 20:00 WIB', style: Rave.label(size: 10, color: Rave.ink)),
                  const Spacer(),
                  const Icon(Icons.qr_code_2_rounded, color: Rave.ink, size: 34),
                ]),
              ]),
            ),
          ),
          Positioned(
            top: 6,
            left: 8,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFD7263D), border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Rave.paper, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('LIVE', style: Rave.label(size: 12, color: Rave.paper)),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 6,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
                child: Text('+ ${App.of(context).s.follow.toUpperCase()}', style: Rave.label(size: 11, color: Rave.ink)),
              ),
            ),
          ),
        ]),
      );
}

/// Tekstur grain fotokopi (bintik acak, digambar sekali lalu di-cache sebagai lapisan).
class Grain extends StatelessWidget {
  const Grain({super.key});
  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: _GrainPainter(), size: Size.infinite));
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.10);
    final n = (size.width * size.height / 90).clamp(0, 9000).toInt();
    final pts1 = <Offset>[], pts2 = <Offset>[];
    for (var k = 0; k < n; k++) {
      (k.isEven ? pts1 : pts2).add(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height));
    }
    canvas.drawPoints(PointMode.points, pts1, light..strokeWidth = 1.2);
    canvas.drawPoints(PointMode.points, pts2, dark..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}
