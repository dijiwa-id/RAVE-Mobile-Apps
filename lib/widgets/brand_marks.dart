import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Tanda merek sebagai vektor (tanpa paket SVG): ikon V RAVE putih tanpa kotak & logo "G" Google resmi 4 warna.
/// Data path diambil apa adanya dari sumber SVG (RAVE: `icon mobile.svg`; Google: panduan merek Sign in with Google).

/// Parser path SVG minimal (M/L/H/V/C/S/Q/T/Z, absolut & relatif) — cukup untuk ekspor Illustrator/Google.
Path parseSvgPath(String d) {
  final path = Path();
  final tokens = RegExp(r'[MmLlHhVvCcSsQqTtZz]|-?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?').allMatches(d).map((m) => m.group(0)!).toList();
  var i = 0;
  var cmd = '';
  double x = 0, y = 0, sx = 0, sy = 0, cx = 0, cy = 0; // posisi, awal subpath, titik kontrol terakhir
  bool isCmd(String t) => RegExp(r'^[A-Za-z]$').hasMatch(t);
  double n() => double.parse(tokens[i++]);
  while (i < tokens.length) {
    if (isCmd(tokens[i])) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
    switch (cmd.toUpperCase()) {
      case 'M':
        x = ox + n();
        y = oy + n();
        path.moveTo(x, y);
        sx = x;
        sy = y;
        cx = x;
        cy = y;
        cmd = rel ? 'l' : 'L'; // pasangan berikutnya = lineto implisit
      case 'L':
        x = ox + n();
        y = oy + n();
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'H':
        x = ox + n();
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'V':
        y = oy + n();
        path.lineTo(x, y);
        cx = x;
        cy = y;
      case 'C':
        final x1 = ox + n(), y1 = oy + n(), x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
      case 'S':
        final x1 = 2 * x - cx, y1 = 2 * y - cy;
        final x2 = ox + n(), y2 = oy + n();
        x = ox + n();
        y = oy + n();
        path.cubicTo(x1, y1, x2, y2, x, y);
        cx = x2;
        cy = y2;
      case 'Q':
        final x1 = ox + n(), y1 = oy + n();
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        cx = x1;
        cy = y1;
      case 'T':
        final x1 = 2 * x - cx, y1 = 2 * y - cy;
        x = ox + n();
        y = oy + n();
        path.quadraticBezierTo(x1, y1, x, y);
        cx = x1;
        cy = y1;
      case 'Z':
        path.close();
        x = sx;
        y = sy;
        cx = x;
        cy = y;
      default:
        i++; // token tak dikenal: lewati
    }
  }
  return path;
}

// ---- RAVE: piringan + huruf V (viewBox 64×64) ----
const _ring = 'M32,15.4c9.3,0,16.9,7.5,16.9,16.9S41.3,49.1,32,49.1s-16.9-7.5-16.9-16.9S22.7,15.4,32,15.4 M32,12.3'
    'c-11,0-19.9,9-19.9,19.9S21,52.1,32,52.1s19.9-9,19.9-19.9S43,12.3,32,12.3L32,12.3z';
const _notch = 'M27.4,11.5h9.2L32,33.6L27.4,11.5z';
const _v = 'M26.6,53.4l-6.4-40.6H30v2.8l-0.7,0.2c-0.1,0.2-0.3,0.5-0.2,1.7c0.1,1.5,1.6,11.4,3,19.8'
    'c1.3-8.3,2.8-18.2,3-19.8c0.1-1.1-0.2-1.5-0.2-1.7l-0.7-0.2v-2.8h9.7l-6.4,40.6H26.6z';
const _vOutline = 'M42.3,13.9l-6,38.3H32h-4.4l-6-38.3h7.2v0.7c0,0-1.1,0.2-0.9,2.8c0.2,2.5,4.1,27,4.1,27s4-24.4,4.1-27'
    's-0.9-2.8-0.9-2.8v-0.7H42.3 M45,11.6h-2.7h-7.2h-2.3v2.3v0.7v1.8l1,0.2c0,0.2,0,0.4,0,0.6c-0.1,1-0.8,6.3-1.8,12.4'
    'c-1-6.1-1.8-11.4-1.8-12.4c0-0.2,0-0.5,0-0.6l1-0.2v-1.8v-0.8v-2.3h-2.3h-7.2H19l0.4,2.7l6,38.3l0.3,1.9h2H32h4.4h2l0.3-1.9l6-38.3'
    'L45,11.6L45,11.6z';

/// Ikon V RAVE satu warna (default putih) di latar transparan — tanpa kotak ungu. Bagian ungu sumber
/// (celah di atas V & garis tepi V) dilubangi agar V tetap terpisah dari piringan di latar apa pun.
class RaveMark extends StatelessWidget {
  const RaveMark({super.key, this.size = 32, this.color = Colors.white, this.semanticLabel = 'RAVE'});
  final double size;
  final Color color;
  final String semanticLabel;
  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        image: true,
        child: CustomPaint(size: Size.square(size), painter: _RaveMarkPainter(color)),
      );
}

class _RaveMarkPainter extends CustomPainter {
  _RaveMarkPainter(this.color);
  final Color color;
  static final _ringP = parseSvgPath(_ring)..fillType = PathFillType.evenOdd;
  static final _notchP = parseSvgPath(_notch);
  static final _vP = parseSvgPath(_v);
  static final _vOutlineP = parseSvgPath(_vOutline)..fillType = PathFillType.evenOdd;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 64;
    canvas.save();
    canvas.scale(s);
    canvas.saveLayer(const Rect.fromLTWH(0, 0, 64, 64), Paint());
    final fill = Paint()..color = color..isAntiAlias = true;
    canvas.drawPath(_ringP, fill);
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withValues(alpha: color.a * 0.55);
    for (final r in const [14.6, 12.6, 10.6, 8.5]) {
      canvas.drawCircle(const Offset(32, 32.2), r, groove);
    }
    final clear = Paint()..blendMode = BlendMode.clear;
    canvas.drawPath(_notchP, clear);
    canvas.drawPath(_vOutlineP, clear);
    canvas.drawPath(_vP, fill);
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RaveMarkPainter old) => old.color != color;
}

// ---- Google "G" resmi (viewBox 48×48) ----
const _gPaths = <(int, String)>[
  (0xFFEA4335, 'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z'),
  (0xFF4285F4, 'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z'),
  (0xFFFBBC05, 'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z'),
  (0xFF34A853, 'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z'),
];

/// Logo "G" Google multiwarna (sesuai panduan merek; jangan diwarnai ulang).
class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GooglePainter());
}

class _GooglePainter extends CustomPainter {
  static final _paths = [for (final (c, d) in _gPaths) (ui.Color(c), parseSvgPath(d))];
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48);
    for (final (c, p) in _paths) {
      canvas.drawPath(p, Paint()..color = c..isAntiAlias = true);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
