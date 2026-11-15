import 'dart:math';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'motion.dart';

/// Kaset pita RAVE (salinan Flutter dari web `components/fan/Cassette.tsx`, proporsi kaset kompak 400 × 256):
/// cangkang plastik asap dengan bevel & kilau, alur pegangan, label kertas krem berpita ungu + sisi "A", jendela kaca
/// berisi dua gulungan pita cokelat dengan hub bergigi, area head bawah, dan 5 sekrup Phillips.
///
/// Digambar dalam tiga lapis agar ringan: badan (statis) · gulungan (satu-satunya yang beranimasi) · kaca/sekrup
/// (statis). Lapis statis berada di balik [RepaintBoundary] sendiri → saat gulungan berputar hanya lapis gulungan
/// yang dicat ulang, tanpa membangun ulang widget (controller menjadi `repaint` painter).
///
/// [spinning]: gulungan berputar pelan. Otomatis diam bila "kurangi gerakan" aktif atau [RaveMotion.infinite] false
/// (uji `pumpAndSettle`). Bayangan sablon keras (offset, tanpa blur) mengikuti gaya merek mobile.
class Cassette extends StatefulWidget {
  const Cassette({super.key, required this.width, this.label = 'RAVE', this.spinning = true, this.shadow = true});
  final double width;
  final String label;
  final bool spinning;
  final bool shadow;

  /// Tinggi / lebar (viewBox web 400 × 256).
  static const aspect = 256 / 400;

  /// Satu putaran gulungan penuh (detik) — pelan, seperti deck pada kecepatan putar.
  static const period = Duration(milliseconds: 4200);

  @override
  State<Cassette> createState() => _CassetteState();
}

class _CassetteState extends State<Cassette> with SingleTickerProviderStateMixin {
  late final AnimationController _turns = AnimationController(vsync: this, duration: Cassette.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(Cassette old) {
    super.didUpdateWidget(old);
    if (old.spinning != widget.spinning) _sync();
  }

  void _sync() {
    final on = widget.spinning && RaveMotion.infinite && !RaveMotion.reduced(context);
    if (on && !_turns.isAnimating) {
      _turns.repeat();
    } else if (!on && _turns.isAnimating) {
      _turns.stop();
    }
  }

  @override
  void dispose() {
    _turns.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = Size(widget.width, widget.width * Cassette.aspect);
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.fromSize(
        size: size,
        child: Stack(fit: StackFit.expand, children: [
          RepaintBoundary(child: CustomPaint(painter: CassetteBodyPainter(label: widget.label, shadow: widget.shadow))),
          RepaintBoundary(child: CustomPaint(painter: CassetteReelsPainter(_turns))),
          const RepaintBoundary(child: CustomPaint(painter: CassetteGlassPainter())),
        ]),
      ),
    );
  }
}

// Koordinat viewBox web.
const _vw = 400.0;
const _window = Rect.fromLTWH(104, 98, 192, 60);
const _windowR = Radius.circular(9);

void _scale(Canvas canvas, Size size) => canvas.scale(size.width / _vw);

TextPainter _text(String s, TextStyle style) => TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, maxLines: 1)..layout();

/// Lapis 1 (statis): cangkang, alur pegangan, label kertas, rangka jendela + isi gelapnya.
class CassetteBodyPainter extends CustomPainter {
  const CassetteBodyPainter({this.label = 'RAVE', this.shadow = true});
  final String label;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scale(canvas, size);
    final shell = RRect.fromRectAndRadius(const Rect.fromLTWH(3, 3, 394, 250), const Radius.circular(15));
    if (shadow) canvas.drawRRect(shell.shift(const Offset(7, 7)), Paint()..color = Rave.shadow);
    canvas.drawRRect(
      shell,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF35303D), Color(0xFF221F28), Color(0xFF141217)], stops: [0, 0.5, 1])
            .createShader(shell.outerRect),
    );
    canvas.drawRRect(shell, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = const Color(0xFF060507));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(6.5, 6.5, 387, 243), const Radius.circular(12)),
      Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = const Color(0x17FFFFFF),
    );
    // Alur pegangan di kedua sisi.
    final grip = Paint()..color = const Color(0x800A090C);
    for (var i = 0; i < 7; i++) {
      final y = 80.0 + i * 13;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(9, y, 10, 2), const Radius.circular(1)), grip);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(381, y, 10, 2), const Radius.circular(1)), grip);
    }

    // Label kertas (jendela digambar di atasnya → "berlubang").
    const labelRect = Rect.fromLTWH(30, 20, 340, 156);
    final labelR = RRect.fromRectAndRadius(labelRect, const Radius.circular(7));
    canvas.save();
    canvas.clipRRect(labelR);
    canvas.drawRect(labelRect, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF3EEE2), Color(0xFFE2DAC8)]).createShader(labelRect));
    const band = Rect.fromLTWH(30, 20, 340, 38);
    canvas.drawRect(band, Paint()..shader = const LinearGradient(colors: [Color(0xFF4A2259), Rave.purple, Color(0xFF6D3584)], stops: [0, 0.55, 1]).createShader(band));
    canvas.drawRect(const Rect.fromLTWH(30, 58, 340, 4), Paint()..color = Rave.mustard);
    canvas.drawRect(const Rect.fromLTWH(30, 62, 340, 1.4), Paint()..color = const Color(0xCC181818));
    // Sisi A.
    canvas.drawCircle(const Offset(54, 39), 13, Paint()..color = Rave.mustard);
    canvas.drawCircle(const Offset(54, 39), 13, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Rave.ink);
    final a = _text('A', Rave.poster(19, color: Rave.ink).copyWith(height: 1));
    a.paint(canvas, Offset(54 - a.width / 2, 39 - a.height / 2));
    final title = _text(label.toUpperCase(), Rave.poster(27, color: Rave.paper).copyWith(height: 1, letterSpacing: 1.5));
    title.paint(canvas, Offset(78, 39 - title.height / 2 + 1));
    final c60 = _text('C-60', const TextStyle(fontFamily: Rave.mono, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2, color: Rave.mustard, height: 1));
    c60.paint(canvas, Offset(352 - c60.width, 27));
    final type = _text('TYPE I · NORMAL', const TextStyle(fontFamily: Rave.mono, fontSize: 7.5, letterSpacing: 1, color: Color(0xBFEDEDED), height: 1));
    type.paint(canvas, Offset(352 - type.width, 43));
    // Garis tulis kosong.
    final rule = Paint()..strokeWidth = 0.8..color = const Color(0x8C8D8576);
    for (final y in [76.0, 88.0]) {
      canvas.drawLine(Offset(46, y), Offset(354, y), rule);
    }
    final foot = _text('DIJIWA.ID · INDIE · LIVE', const TextStyle(fontFamily: Rave.mono, fontSize: 6.6, letterSpacing: 1.6, color: Color(0xFF5D5649), height: 1));
    foot.paint(canvas, Offset(200 - foot.width / 2, 165));
    canvas.restore();
    canvas.drawRRect(labelR, Paint()..style = PaintingStyle.stroke..strokeWidth = 1..color = const Color(0x59000000));

    // Rangka jendela + isi.
    final frame = RRect.fromRectAndRadius(const Rect.fromLTWH(100, 94, 200, 68), const Radius.circular(12));
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF0D0B0F));
    canvas.drawRRect(frame, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFF050406));
    canvas.drawRRect(RRect.fromRectAndRadius(_window, _windowR), Paint()..color = const Color(0xFF1A1720));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CassetteBodyPainter old) => old.label != label || old.shadow != shadow;
}

/// Lapis 2 (beranimasi): dua gulungan pita & hub bergigi, dipotong ke jendela. [turns] 0..1 = satu putaran.
class CassetteReelsPainter extends CustomPainter {
  CassetteReelsPainter(this.turns) : super(repaint: turns);
  final Animation<double> turns;

  static const left = Offset(140, 128), right = Offset(260, 128);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scale(canvas, size);
    canvas.clipRRect(RRect.fromRectAndRadius(_window, _windowR));
    // Pita menyeberang antar gulungan.
    canvas.drawLine(const Offset(140, 155), const Offset(260, 155), Paint()..strokeWidth = 2..color = const Color(0xFF2A1810));
    final t = turns.value * 2 * pi;
    _reel(canvas, left, 28, 6, 15, 2.2, t);
    // Gulungan kanan lebih kecil → berputar lebih cepat (kecepatan linear pita sama).
    _reel(canvas, right, 19, 3, 14, 2, t * 28 / 19);
    // Skala sisa pita.
    final tick = Paint()..strokeWidth = 0.8..color = const Color(0x73EDEDED);
    for (var i = 0; i < 9; i++) {
      final x = 176.0 + i * 6;
      canvas.drawLine(Offset(x, 100), Offset(x, i.isOdd ? 104 : 107), tick);
    }
    canvas.restore();
  }

  void _reel(Canvas canvas, Offset c, double r, int rings, double r0, double step, double angle) {
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = const RadialGradient(colors: [Color(0xFF4A2C1C), Color(0xFF4A2C1C), Color(0xFF2D1A10), Color(0xFF1C100A)], stops: [0, 0.3, 0.85, 1]).createShader(rect),
    );
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..color = const Color(0x59000000));
    for (var i = 0; i < rings; i++) {
      canvas.drawCircle(c, r0 + i * step, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.5..color = const Color(0xFF7A4A2C).withValues(alpha: 0.14 + (i % 3) * 0.05));
    }
    // Hub bergigi (6 gigi) + kilau kecil yang ikut berputar → putaran terlihat.
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, 12.5, Paint()..color = const Color(0xFFEBE7DF));
    canvas.drawCircle(Offset.zero, 12.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = const Color(0xFFB9B3A6));
    canvas.drawCircle(Offset.zero, 7.2, Paint()..color = const Color(0xFF17151A));
    final tooth = Paint()..color = const Color(0xFFEBE7DF);
    for (var k = 0; k < 6; k++) {
      canvas.save();
      canvas.rotate(k * pi / 3);
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-1.4, -7.4, 2.8, 3.6), const Radius.circular(0.6)), tooth);
      canvas.restore();
    }
    canvas.drawArc(Rect.fromCircle(center: Offset.zero, radius: 12.5), -pi / 2, 0.4, false, Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = const Color(0x80FFFFFF));
    canvas.restore();
  }

  @override
  bool shouldRepaint(CassetteReelsPainter old) => old.turns != turns;
}

/// Lapis 3 (statis): kaca jendela, area head bawah, sekrup Phillips & kilau plastik menyeluruh.
class CassetteGlassPainter extends CustomPainter {
  const CassetteGlassPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    _scale(canvas, size);
    // Kaca.
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(_window, _windowR));
    canvas.drawRect(
      _window,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x38FFFFFF), Color(0x0AFFFFFF), Color(0x00FFFFFF), Color(0x12FFFFFF)],
          stops: [0, 0.3, 0.55, 0.8],
        ).createShader(_window),
    );
    canvas.drawLine(const Offset(112, 152), const Offset(150, 100), Paint()..strokeWidth = 6..color = const Color(0x1AFFFFFF));
    canvas.restore();

    // Area head bawah.
    final head = Path()
      ..moveTo(108, 253)
      ..lineTo(122, 196)
      ..quadraticBezierTo(124, 190, 130, 190)
      ..lineTo(270, 190)
      ..quadraticBezierTo(276, 190, 278, 196)
      ..lineTo(292, 253)
      ..close();
    canvas.drawPath(head, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2C2833), Color(0xFF100F13)]).createShader(head.getBounds()));
    canvas.drawPath(head, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = const Color(0xFF060507));
    canvas.drawLine(const Offset(123, 197), const Offset(277, 197), Paint()..color = const Color(0x14FFFFFF));
    final hole = Paint()..color = const Color(0xFF050406);
    final rim = Paint()..style = PaintingStyle.stroke..color = const Color(0xFF3A3540);
    for (final x in [148.0, 252.0]) {
      canvas.drawCircle(Offset(x, 226), 8, hole);
      canvas.drawCircle(Offset(x, 226), 8, rim);
    }
    for (final x in [124.0, 267.0]) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, 232, 9, 9), const Radius.circular(1.5)), hole);
    }
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(178, 236, 44, 15), const Radius.circular(2)), hole);
    canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(190, 240, 20, 7), const Radius.circular(1)), Paint()..color = const Color(0xFFC9B99A));
    canvas.drawRect(const Rect.fromLTWH(114, 248.5, 172, 3), Paint()..color = const Color(0xFF3A2214));

    // Sekrup Phillips.
    final cross = Paint()
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A2A2E);
    for (final (x, y) in const [(22.0, 22.0), (378.0, 22.0), (22.0, 234.0), (378.0, 234.0), (200.0, 222.0)]) {
      final c = Offset(x, y);
      canvas.drawCircle(c, 6.4, Paint()..color = const Color(0xFF0B0A0D));
      canvas.drawCircle(
        c,
        5.2,
        Paint()
          ..shader = const RadialGradient(center: Alignment(-0.3, -0.4), radius: 0.75, colors: [Color(0xFFF4F4F4), Color(0xFFA9A9AD), Color(0xFF4C4C52)], stops: [0, 0.45, 1])
              .createShader(Rect.fromCircle(center: c, radius: 5.2)),
      );
      canvas.drawLine(c - const Offset(3, 0), c + const Offset(3, 0), cross);
      canvas.drawLine(c - const Offset(0, 3), c + const Offset(0, 3), cross);
    }

    // Kilau plastik menyeluruh.
    const all = Rect.fromLTWH(3, 3, 394, 250);
    canvas.drawRRect(
      RRect.fromRectAndRadius(all, const Radius.circular(15)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x29FFFFFF), Color(0x08FFFFFF), Color(0x00FFFFFF), Color(0x0DFFFFFF)],
          stops: [0, 0.35, 0.6, 1],
        ).createShader(all),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CassetteGlassPainter old) => false;
}
