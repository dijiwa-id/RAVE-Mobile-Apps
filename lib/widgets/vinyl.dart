import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/theme.dart';
import 'common.dart';

/// Sampul + piringan hitam (web `.shell-vinyl`): saat diputar piringan menyembul ke kanan dari balik sampul dan
/// berputar; label tengah memakai warna dominan sampul. Label pita (codec, mis. "FLAC 24/96") ditempel miring di
/// pojok sampul. [spinning] = sedang berbunyi & animasi piringan diizinkan (pref `vinylMotion`).
class VinylCover extends StatefulWidget {
  const VinylCover({super.key, required this.width, required this.image, required this.labelColor, required this.spinning, this.tape, this.disc = true});
  final double width;
  final String? image;
  final Color labelColor;
  final bool spinning;
  final String? tape;
  /// false → hanya sampul persegi selebar [width] (animasi piringan dimatikan di Pengaturan).
  final bool disc;

  /// Tinggi / lebar komposisi.
  static double ratio(bool disc) => disc ? 0.82 : 1.0;

  /// Geser piringan saat berputar (pecahan diameter): tepi kanan piringan tepat di tepi kanan komposisi
  /// (0,05 + 0,74 + 0,74·f = 1) → lebar karya = lebar isi.
  static const slide = 0.21 / 0.74;
  @override
  State<VinylCover> createState() => _VinylCoverState();
}

/// Putaran ala turntable: kecepatan sudut mendekati target dengan pelunakan (spin-up/spin-down, tanpa lompatan).
/// Ticker berhenti sendiri saat piringan diam → tidak ada frame terbuang.
class _VinylCoverState extends State<VinylCover> with SingleTickerProviderStateMixin {
  static const _rps = 1 / 2.4; // putaran per detik saat berputar penuh
  final _turns = ValueNotifier<double>(0);
  late final Ticker _ticker = createTicker(_tick);
  double _speed = 0;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.spinning) {
      _speed = _rps; // layar dibuka saat lagu berjalan → langsung berputar
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(VinylCover old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 0.016 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    final target = widget.spinning ? _rps : 0.0;
    // Mulai: ~0,5 dtk; berhenti: lebih lambat (piringan melambat seperti turntable dilepas).
    final k = widget.spinning ? 5.0 : 2.6;
    _speed += (target - _speed) * (1 - exp(-k * dt));
    _turns.value = (_turns.value + _speed * dt) % 1;
    if (!widget.spinning && _speed < 0.004) {
      _speed = 0;
      _ticker.stop();
      _last = Duration.zero;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _turns.dispose();
    super.dispose();
  }

  /// Sampul (muka terlihat rata kiri-atas; bayangan sablon ke kanan-bawah tidak menggeser tepi).
  Widget _sleeve(double sleeve) => Hero(
            tag: 'cover',
            child: Container(
              decoration: BoxDecoration(color: Rave.hover, border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(6, 6))]),
              child: Stack(fit: StackFit.expand, children: [
                Cover(widget.image, size: sleeve - 4),
                if (widget.tape != null && widget.tape!.isNotEmpty)
                  Positioned(
                    right: 10,
                    bottom: 12,
                    child: Transform.rotate(
                      angle: -4 * pi / 180,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Rave.paper,
                          border: Border.all(color: Rave.ink, width: 2),
                          boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(2, 2))],
                        ),
                        child: Text(widget.tape!.toUpperCase(), style: Rave.label(size: 11, color: Rave.ink).copyWith(letterSpacing: 0.9)),
                      ),
                    ),
                  ),
              ]),
            ),
          );

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    if (!widget.disc) return SizedBox(width: w, height: w, child: _sleeve(w));
    final sleeve = w * 0.8;
    final disc = w * 0.74;
    final on = widget.spinning;
    return SizedBox(
      width: w,
      height: w * 0.82,
      child: Stack(clipBehavior: Clip.none, children: [
        // Piringan (di belakang sampul)
        Positioned(
          left: w * 0.05,
          top: w * 0.03,
          width: disc,
          height: disc,
          child: AnimatedSlide(
            offset: on ? const Offset(VinylCover.slide, 0) : Offset.zero,
            duration: const Duration(milliseconds: 900),
            curve: const Cubic(0.2, 0.8, 0.2, 1),
            child: DecoratedBox(
              decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Color(0x8C000000), blurRadius: 30, offset: Offset(0, 10))]),
              child: Stack(fit: StackFit.expand, children: [
                const CustomPaint(painter: _GroovePainter()),
                Padding(
                  padding: EdgeInsets.all(disc * 0.33),
                  child: _Spin(
                    turns: _turns,
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: widget.labelColor, boxShadow: [BoxShadow(color: widget.labelColor, spreadRadius: 3)]),
                      child: ClipOval(
                        child: Stack(fit: StackFit.expand, children: [
                          if (widget.image != null) Cover(widget.image, size: disc * 0.34),
                          Center(
                            child: Container(width: disc * 0.034, height: disc * 0.034, decoration: const BoxDecoration(color: Rave.shadow, shape: BoxShape.circle)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
        // Sampul
        Positioned(left: 0, top: 0, width: sleeve, height: sleeve, child: _sleeve(sleeve)),
      ]),
    );
  }
}

/// Alur piringan: lingkaran konsentris gelap-terang + kilap sudut.
class _GroovePainter extends CustomPainter {
  const _GroovePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF111111));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF1A181C);
    for (var rr = r * 0.36; rr < r - 2; rr += 3) {
      canvas.drawCircle(c, rr, groove);
    }
    canvas.drawCircle(c, r * 0.175, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x0DFFFFFF));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0.7,
          endAngle: 0.7 + 2 * pi,
          colors: const [Colors.transparent, Color(0x1AFFFFFF), Colors.transparent, Colors.transparent, Color(0x14FFFFFF), Colors.transparent],
          stops: const [0.12, 0.18, 0.26, 0.62, 0.68, 0.76],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF050505));
  }

  @override
  bool shouldRepaint(_GroovePainter old) => false;
}

/// Putar anak sesuai [turns] (hanya transform; anak di-cache).
class _Spin extends StatelessWidget {
  const _Spin({required this.turns, required this.child});
  final ValueListenable<double> turns;
  final Widget child;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: ValueListenableBuilder<double>(
          valueListenable: turns,
          child: child,
          builder: (_, t, child) => Transform.rotate(angle: t * 2 * pi, child: child),
        ),
      );
}
