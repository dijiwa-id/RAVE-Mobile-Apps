import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';

/// Kontrol pemutar bergaya tape deck/skin pemutar desktop klasik — sama dengan web (`index.css` .deck-*):
/// baki gelap berbevel, tombol "piano key" aluminium (bevel terbalik saat ditekan), PLAY mustard, LED toggle,
/// layar LCD fosfor mustard, slider alur cekung dengan thumb kotak.
abstract final class Deck {
  static const keyTop = Color(0xFF57545E), keyMid = Color(0xFF45424C), keyBot = Color(0xFF3A3840);
  static const hiLight = Color(0xFF8D8996), loLight = Color(0xFF1E1D22), edge = Color(0xFF0B0A0D);
  static const playTop = Color(0xFFFFD650), playBot = Color(0xFFD9A90F);
  static const ledOff = Color(0xFF3A3010), ledOn = Color(0xFFFFD650);
}

/// Baki tombol: latar gradien gelap berbingkai bevel.
class DeckTray extends StatelessWidget {
  const DeckTray({super.key, required this.children, this.gap = 6, this.padding = 6});
  final List<Widget> children;
  final double gap, padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(padding),
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2830), Color(0xFF1B1A1F)]),
          border: Border.fromBorderSide(BorderSide(color: Deck.edge)),
        ),
        foregroundDecoration: const _Bevel(light: Color(0xFF4A4752), dark: Deck.edge),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(width: gap), children[i]],
        ]),
      );
}

/// Garis bevel 1px (terang kiri-atas, gelap kanan-bawah) — `inverted` untuk keadaan ditekan.
class _Bevel extends Decoration {
  const _Bevel({required this.light, required this.dark});
  final Color light, dark;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _BevelPainter(light, dark);
}

class _BevelPainter extends BoxPainter {
  _BevelPainter(this.light, this.dark);
  final Color light, dark;
  @override
  void paint(Canvas c, Offset o, ImageConfiguration cfg) {
    final s = cfg.size!;
    final r = o & s;
    final pl = Paint()..color = light;
    final pd = Paint()..color = dark;
    c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 1), pl);
    c.drawRect(Rect.fromLTWH(r.left, r.top, 1, r.height), pl);
    c.drawRect(Rect.fromLTWH(r.left, r.bottom - 1, r.width, 1), pd);
    c.drawRect(Rect.fromLTWH(r.right - 1, r.top, 1, r.height), pd);
  }
}

/// Tombol "piano key". `toggle` → LED (menyala saat [active]). `play` → kunci PLAY mustard.
class DeckKey extends StatefulWidget {
  const DeckKey({
    super.key,
    required this.child,
    required this.onTap,
    this.toggle = false,
    this.active = false,
    this.play = false,
    this.locked = false,
    this.width = 52,
    this.height = 44,
    required this.semantic,
  });
  final Widget child;
  final VoidCallback? onTap;
  final bool toggle, active, play, locked;
  final double width, height;
  final String semantic;

  @override
  State<DeckKey> createState() => _DeckKeyState();
}

class _DeckKeyState extends State<DeckKey> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final pressed = down || (widget.toggle && widget.active);
    final colors = widget.play
        ? (pressed ? const [Deck.playBot, Rave.mustard] : const [Deck.playTop, Rave.mustard, Deck.playBot])
        : (pressed ? const [Color(0xFF34323A), Color(0xFF3E3C45)] : const [Deck.keyTop, Deck.keyMid, Deck.keyBot]);
    final fg = widget.play ? Rave.ink : const Color(0xFFE4E1EA);
    return Semantics(
      button: true,
      label: widget.semantic,
      toggled: widget.toggle ? widget.active : null,
      enabled: !widget.locked,
      child: GestureDetector(
        onTapDown: widget.locked ? null : (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.locked || widget.onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onTap!();
              },
        child: Opacity(
          opacity: widget.locked ? 0.55 : 1,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              border: Border.all(color: Deck.edge),
            ),
            foregroundDecoration: _Bevel(
              light: pressed ? const Color(0xFF16151A) : (widget.play ? const Color(0xFFFFF0B3) : Deck.hiLight),
              dark: pressed ? const Color(0xFF6D6977) : (widget.play ? const Color(0xFF8A6505) : Deck.loLight),
            ),
            child: Stack(alignment: Alignment.center, children: [
              Transform.translate(
                offset: pressed ? const Offset(1, 1) : Offset.zero,
                child: IconTheme(
                  data: IconThemeData(color: fg, size: widget.height * 0.5, shadows: [Shadow(color: widget.play ? Colors.white54 : Colors.black87, offset: const Offset(1, 1))]),
                  child: widget.child,
                ),
              ),
              if (widget.toggle)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    width: 8,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.active ? Deck.ledOn : Deck.ledOff,
                      boxShadow: widget.active ? const [BoxShadow(color: Color(0xBFF4C21F), blurRadius: 5, spreadRadius: 1)] : null,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Layar LCD: status (PLAY/PAUSE/BUFFER/STOP), codec, waktu besar fosfor mustard, spektrum animasi.
class DeckLcd extends StatefulWidget {
  const DeckLcd({super.key, required this.status, required this.codec, required this.time, required this.on, this.dim = false});
  final String status;
  final String? codec;
  final String time;
  final bool on, dim;
  @override
  State<DeckLcd> createState() => _DeckLcdState();
}

class _DeckLcdState extends State<DeckLcd> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  @override
  void initState() {
    super.initState();
    if (widget.on) c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(DeckLcd old) {
    super.didUpdateWidget(old);
    widget.on ? (c.isAnimating ? null : c.repeat(reverse: true)) : c.stop();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  static const _glow = [Shadow(color: Color(0x8CF4C21F), blurRadius: 6)];

  @override
  Widget build(BuildContext context) {
    const phosphor = Rave.mustard;
    final dimC = Rave.mustard.withValues(alpha: 0.3);
    TextStyle mono(double s, {bool dim = false}) =>
        TextStyle(fontFamily: Rave.mono, fontSize: s, fontWeight: FontWeight.w700, height: 1, letterSpacing: s > 12 ? 0.8 : 1.2, color: dim ? dimC : phosphor, shadows: dim ? null : _glow, fontFeatures: const [FontFeature.tabularFigures()]);
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF050506), Color(0xFF0D0C0F)]),
        border: Border.fromBorderSide(BorderSide(color: Deck.edge)),
      ),
      foregroundDecoration: const _Bevel(light: Colors.black, dark: Color(0xFF3A3842)),
      child: Stack(children: [
        // Garis pindai halus.
        Positioned.fill(child: CustomPaint(painter: _Scanlines())),
        Row(children: [
          SizedBox(
            width: 64,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.status, style: mono(9)),
              const SizedBox(height: 4),
              Text(widget.codec ?? '----', maxLines: 1, overflow: TextOverflow.clip, style: mono(9, dim: widget.codec == null)),
            ]),
          ),
          Text(widget.time, style: mono(24, dim: widget.dim)),
          const Spacer(),
          AnimatedBuilder(
            animation: c,
            builder: (_, _) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(9, (i) {
                final h = widget.on ? 0.15 + 0.85 * (0.5 + 0.5 * sin(c.value * pi * 2 + i * 0.9)).abs() : 0.12;
                return Container(
                  width: 3,
                  height: 24 * h,
                  margin: const EdgeInsets.only(left: 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Rave.mustard, Rave.mustard, Deck.playTop, Color(0xFFFF6A3D)], stops: [0, 0.55, 0.8, 1]),
                    boxShadow: [BoxShadow(color: Color(0x66F4C21F), blurRadius: 4)],
                  ),
                );
              }),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _Scanlines extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withValues(alpha: 0.025);
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1), p);
    }
  }

  @override
  bool shouldRepaint(_Scanlines old) => false;
}

/// Slider alur: lintasan cekung gelap, isian mustard, thumb kotak berbevel. Nilai ditahan selama digeser,
/// dikirim saat dilepas (satu seek, bukan puluhan permintaan range).
class DeckSlider extends StatefulWidget {
  const DeckSlider({super.key, required this.value, required this.max, required this.onChanged, this.locked = false, this.onDrag, this.semantic = ''});
  final double value, max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double?>? onDrag;
  final bool locked;
  final String semantic;
  @override
  State<DeckSlider> createState() => _DeckSliderState();
}

class _DeckSliderState extends State<DeckSlider> {
  double? drag;
  double _at(Offset local, double w) => (local.dx / w).clamp(0.0, 1.0) * widget.max;

  void _set(double? v) {
    setState(() => drag = v);
    widget.onDrag?.call(v);
  }

  @override
  Widget build(BuildContext context) {
    final v = (drag ?? widget.value).clamp(0.0, widget.max <= 0 ? 1.0 : widget.max);
    final pct = widget.max <= 0 ? 0.0 : v / widget.max;
    return Semantics(
      slider: true,
      label: widget.semantic,
      value: '${(pct * 100).round()}%',
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.locked ? null : (d) => _set(_at(d.localPosition, w)),
          onHorizontalDragUpdate: widget.locked ? null : (d) => _set(_at(d.localPosition, w)),
          onHorizontalDragEnd: widget.locked
              ? null
              : (_) {
                  if (drag != null) widget.onChanged(drag!);
                  _set(null);
                },
          onTapUp: widget.locked ? null : (d) => widget.onChanged(_at(d.localPosition, w)),
          child: SizedBox(
            height: 32,
            child: Stack(alignment: Alignment.centerLeft, clipBehavior: Clip.none, children: [
              Container(
                height: 8,
                padding: const EdgeInsets.all(1),
                decoration: const BoxDecoration(color: Color(0xFF0A090C)),
                foregroundDecoration: const _Bevel(light: Colors.black, dark: Color(0xFF3A3842)),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: pct,
                  child: ColoredBox(color: drag != null ? Rave.mustard : Rave.mustard.withValues(alpha: 0.85)),
                ),
              ),
              Positioned(
                left: (w * pct - 12).clamp(-2.0, w - 22),
                child: Container(
                  width: 24,
                  height: 16,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFD8D5DE), Color(0xFF9D99A6)]),
                    border: Border.all(color: Deck.edge),
                  ),
                  foregroundDecoration: const _Bevel(light: Colors.white, dark: Color(0xFF4A4752)),
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}
