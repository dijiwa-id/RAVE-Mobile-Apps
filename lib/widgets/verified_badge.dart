import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/theme.dart';

/// Badge "Verified" khas RAVE — port 1:1 dari web `components/ui/VerifiedBadge.tsx`: stiker bintang-sobek 12 sudut
/// mustard bergaris tinta + bayangan sablon tinta, cincin dalam putus-putus (≥ 28 px) dan centang "V" tebal bersudut
/// tajam. Hanya penanda identitas — tidak mengubah tier. Terbaca di 12–14 px (inline di samping nama) hingga 64 px.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16, this.dim = false, this.label});
  final double size;

  /// Pudar & abu-abu (status belum terverifikasi di panel verifikasi).
  final bool dim;

  /// Label aksesibilitas; bawaan "Akun terverifikasi".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final s = App.maybeRead(context)?.s ?? S.of('id');
    Widget w = CustomPaint(size: Size.square(size), painter: VerifiedBadgePainter(size: size));
    if (dim) {
      w = Opacity(opacity: 0.3, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_grayscale), child: w));
    }
    return Semantics(label: label ?? s.verifiedLabel, image: true, child: ExcludeSemantics(child: SizedBox.square(dimension: size, child: w)));
  }

  static const _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// Geometri badge dalam kotak 24 unit (viewBox -0.6 -0.6 25.6 25.6), sama persis dengan SVG web.
class VerifiedBadgePainter extends CustomPainter {
  VerifiedBadgePainter({required this.size});

  /// Ukuran tampil (px logis) — menentukan cincin dalam & tebal centang seperti web.
  final double size;

  static const _ink = Color(0xFF181818);
  static const _shadow = Color(0xFF0B0A0C);

  /// 24 titik bergantian (r luar 11 / dalam 8,4) di sekitar (12,12), mulai -90°.
  static final Path burst = () {
    final p = Path();
    for (var i = 0; i < 24; i++) {
      final a = (i / 24) * math.pi * 2 - math.pi / 2;
      final r = i.isOdd ? 8.4 : 11.0;
      final x = 12 + math.cos(a) * r, y = 12 + math.sin(a) * r;
      i == 0 ? p.moveTo(x, y) : p.lineTo(x, y);
    }
    return p..close();
  }();

  @override
  void paint(Canvas canvas, Size box) {
    final k = box.shortestSide / 25.6;
    canvas
      ..save()
      ..scale(k)
      ..translate(0.6, 0.6);
    // Bayangan sablon (offset tinta).
    canvas.drawPath(burst.shift(const Offset(1.3, 1.3)), Paint()..color = _shadow);
    // Isi gradien mustard + garis tinta (miter).
    canvas.drawPath(
      burst,
      Paint()
        ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD84A), Color(0xFFF4C21F)])
            .createShader(burst.getBounds()),
    );
    canvas.drawPath(
      burst,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _ink
        ..strokeWidth = 1.3
        ..strokeJoin = StrokeJoin.miter,
    );
    // Cincin dalam putus-putus — kesan cap/segel (hanya di ukuran besar).
    if (size >= 28) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..color = _ink.withValues(alpha: 0.35)
        ..strokeWidth = 0.6;
      const r = 6.4, dash = 1.2, gap = 1.1;
      final rect = Rect.fromCircle(center: const Offset(12, 12), radius: r);
      final circ = 2 * math.pi * r;
      // SVG memulai dash di sudut 0 (arah jam 3), searah jarum jam.
      for (double d = 0; d < circ; d += dash + gap) {
        canvas.drawArc(rect, d / r, math.min(dash, circ - d) / r, false, ring);
      }
    }
    // Centang "V" RAVE: kaki kiri pendek, kaki kanan panjang miring.
    canvas.drawPath(
      Path()
        ..moveTo(7.1, 11.9)
        ..lineTo(10.5, 15.6)
        ..lineTo(17.3, 7.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..color = _ink
        ..strokeWidth = size <= 16 ? 2.9 : 2.5
        ..strokeCap = StrokeCap.square
        ..strokeJoin = StrokeJoin.miter,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(VerifiedBadgePainter old) => old.size != size;
}

/// Cap "VERIFIED" (badge + label) untuk kepala profil / panel verifikasi: blok tinta miring -2°, teks mustard
/// Space Mono, bayangan sablon mustard 3 px — senada dengan stiker & cap lain di RAVE.
class VerifiedStamp extends StatelessWidget {
  const VerifiedStamp({super.key});
  @override
  Widget build(BuildContext context) {
    final s = App.maybeRead(context)?.s ?? S.of('id');
    return Transform.rotate(
      angle: -2 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 2, 8, 2),
        decoration: BoxDecoration(
          color: Rave.ink,
          border: Border.all(color: Rave.ink, width: 2),
          boxShadow: const [BoxShadow(color: Rave.mustard, offset: Offset(3, 3))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const VerifiedBadge(size: 16),
          const SizedBox(width: 6),
          Text(s.verifiedStamp.toUpperCase(), style: Rave.label(size: 10.5, color: Rave.mustard).copyWith(letterSpacing: 1.26)),
        ]),
      ),
    );
  }
}

/// Nama + badge inline (badge hanya bila [verified]). Nama dipotong dengan elipsis, badge tetap terlihat.
class NameWithBadge extends StatelessWidget {
  const NameWithBadge(this.name, {super.key, required this.verified, this.style, this.badgeSize = 16});
  final String name;
  final bool verified;
  final TextStyle? style;
  final double badgeSize;
  @override
  Widget build(BuildContext context) {
    final text = Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    if (!verified) return text;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Flexible(child: text),
      const SizedBox(width: 6),
      VerifiedBadge(size: badgeSize),
    ]);
  }
}
