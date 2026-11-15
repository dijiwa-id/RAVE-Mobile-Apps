import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme.dart';
import 'motion.dart';
import 'spectrum.dart';

export 'spectrum.dart' show SpectrumRepo;

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

/// Tombol "piano key" bergaya tape deck vintage. `toggle` → LED (menyala saat [active]). `play` → kunci PLAY mustard.
///
/// Gerak tekan mekanis: muka tombol turun menutupi "rok" (sisi gelap tombol) dalam ±70 ms saat jari menyentuh,
/// lalu kembali dengan pegas sedikit memantul saat dilepas (tekanan singkat tetap terlihat penuh). Toggle yang aktif
/// tetap "terkunci" setengah turun seperti tuts deck kaset. Haptik dua tahap: klik ringan saat masuk, klik halus saat
/// kembali. Gerak dikurangi → langsung tanpa animasi.
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

  /// Jarak tempuh muka tombol (dp) — juga tinggi "rok" yang terlihat di bawah muka saat diam.
  static const travel = 3.0;
  /// Posisi tuts toggle aktif (0 = diam, 1 = tertekan penuh).
  static const latched = 0.6;

  @override
  State<DeckKey> createState() => _DeckKeyState();
}

class _DeckKeyState extends State<DeckKey> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, lowerBound: -0.25, upperBound: 1, value: _rest);
  bool _held = false;
  bool _reduced = false; // diperbarui di build — aman dibaca saat widget sedang dilepas

  double get _rest => widget.toggle && widget.active ? DeckKey.latched : 0;

  @override
  void didUpdateWidget(DeckKey old) {
    super.didUpdateWidget(old);
    if (!_held && (old.active != widget.active || old.toggle != widget.toggle)) _settle();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Listener (bukan onTapDown) → tuts bereaksi saat jari menyentuh, tanpa jeda 100 ms pengenal ketukan.
  void _down(PointerDownEvent _) {
    if (widget.locked) return;
    _held = true;
    HapticFeedback.lightImpact();
    if (_reduced) {
      _c.value = 1;
    } else {
      _c.animateTo(1, duration: const Duration(milliseconds: 70), curve: Curves.easeOutCubic);
    }
  }

  void _up(PointerEvent e) {
    if (!_held) return;
    _held = false;
    if (_reduced || _c.value >= 1) return _release(click: e is PointerUpEvent);
    // Tekanan secepat kilat: tuntaskan dulu perjalanan turun, baru kembali — tuts selalu terasa "masuk".
    _c
        .animateTo(1, duration: Duration(milliseconds: (70 * (1 - _c.value)).round().clamp(16, 70)), curve: Curves.easeOutCubic)
        .then((_) {
      if (mounted && !_held) _release(click: e is PointerUpEvent);
    });
  }

  void _release({required bool click}) {
    if (click) HapticFeedback.selectionClick();
    _settle();
  }

  void _settle() {
    if (_reduced) {
      _c.value = _rest;
    } else {
      // Pegas pendek: sedikit melewati posisi diam (naik) lalu mengendap — seperti tuts deck yang memantul.
      _c.animateTo(_rest, duration: const Duration(milliseconds: 260), curve: Curves.easeOutBack);
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduced = RaveMotion.reduced(context);
    final fg = widget.play ? Rave.ink : const Color(0xFFE4E1EA);
    final upColors = widget.play ? const [Deck.playTop, Rave.mustard, Deck.playBot] : const [Deck.keyTop, Deck.keyMid, Deck.keyBot];
    final downColors = widget.play ? const [Deck.playBot, Rave.mustard, Rave.mustard] : const [Color(0xFF34323A), Color(0xFF393740), Color(0xFF3E3C45)];
    final upLight = widget.play ? const Color(0xFFFFF0B3) : Deck.hiLight, upDark = widget.play ? const Color(0xFF8A6505) : Deck.loLight;
    const downLight = Color(0xFF16151A), downDark = Color(0xFF6D6977);
    final skirt = widget.play ? const [Color(0xFFB88A08), Color(0xFF6E5004)] : const [Color(0xFF2B2930), Color(0xFF141317)];
    const tr = DeckKey.travel;
    return Semantics(
      button: true,
      label: widget.semantic,
      toggled: widget.toggle ? widget.active : null,
      enabled: !widget.locked,
      // Area sentuh setinggi ≥ 48 dp tanpa menggeser muka tombol: lebar = lebar muka (tepi kiri/kanan yang terlihat
      // tetap sejajar gutter), tinggi diperluas simetris di sekitar muka.
      child: Listener(
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.locked || widget.onTap == null ? null : widget.onTap,
        child: SizedBox(
          width: widget.width,
          height: max(widget.height, Rave.tap),
          child: Center(
            child: Opacity(
              opacity: widget.locked ? 0.55 : 1,
              child: SizedBox(
                width: widget.width,
                height: widget.height,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (context, _) {
                    final v = _c.value; // bisa sedikit < 0 saat memantul
                    final t = v.clamp(0.0, 1.0);
                    final lerp = [for (var i = 0; i < 3; i++) Color.lerp(upColors[i], downColors[i], t)!];
                    return Stack(clipBehavior: Clip.none, children: [
                      // Sumur + rok tuts: sisi gelap yang tampak di bawah muka saat tuts naik.
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: skirt),
                            border: Border.all(color: Deck.edge),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: tr * v,
                        height: widget.height - tr,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: lerp),
                            border: Border.all(color: Deck.edge),
                          ),
                          foregroundDecoration: _Bevel(light: Color.lerp(upLight, downLight, t)!, dark: Color.lerp(upDark, downDark, t)!),
                          child: Stack(alignment: Alignment.center, children: [
                            IconTheme(
                              data: IconThemeData(
                                color: fg,
                                size: widget.height * 0.5,
                                shadows: [Shadow(color: (widget.play ? Colors.white54 : Colors.black87).withValues(alpha: 1 - 0.6 * t), offset: const Offset(1, 1))],
                              ),
                              child: widget.child,
                            ),
                            if (widget.toggle)
                              Positioned(
                                left: 4,
                                top: 4,
                                child: AnimatedContainer(
                                  duration: _reduced ? Duration.zero : const Duration(milliseconds: 160),
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
                    ]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// Layar LCD: status (PLAY/PAUSE/BUFFER/STOP), codec, waktu besar fosfor mustard, dan spektrum yang mengikuti lagu
/// ([DeckSpectrum]) memenuhi SISA lebar LCD — bilah sebanyak lebarnya. Tanpa [trackId]/[spectrum] → dekoratif.
class DeckLcd extends StatelessWidget {
  const DeckLcd({
    super.key,
    required this.status,
    required this.codec,
    required this.time,
    required this.on,
    this.dim = false,
    this.trackId,
    this.position,
    this.spectrum,
  });
  final String status;
  final String? codec;
  final String time;
  final bool on, dim;

  /// Lagu yang amplop spektrumnya diputar (null: episode, iklan, live → dekoratif).
  final String? trackId;
  final Duration Function()? position;
  final SpectrumRepo? spectrum;

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
              Text(status, style: mono(9)),
              const SizedBox(height: 4),
              Text(codec ?? '----', maxLines: 1, overflow: TextOverflow.clip, style: mono(9, dim: codec == null)),
            ]),
          ),
          Text(time, style: mono(24, dim: dim)),
          const SizedBox(width: 10),
          Expanded(
            child: DeckSpectrum(trackId: trackId, playing: on, dim: dim, position: position, repo: spectrum),
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
  const DeckSlider({super.key, required this.value, required this.max, required this.onChanged, this.locked = false, this.onDrag, this.onLocked, this.semantic = ''});
  final double value, max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double?>? onDrag;
  final bool locked;

  /// Dipanggil saat pengguna mencoba menggeser/mengetuk slider yang [locked] (mis. info "khusus Premium").
  final VoidCallback? onLocked;
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
        final hint = widget.onLocked;
        if (widget.locked) {
          // Hanya tampilan: progres tetap jalan, gestur geser/ketuk tidak mengubah posisi.
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: hint == null ? null : (_) => hint(),
            onTapUp: hint == null ? null : (_) => hint(),
            child: _track(w, pct),
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (d) => _set(_at(d.localPosition, w)),
          onHorizontalDragUpdate: (d) => _set(_at(d.localPosition, w)),
          onHorizontalDragEnd: (_) {
            if (drag != null) widget.onChanged(drag!);
            _set(null);
          },
          onTapUp: (d) => widget.onChanged(_at(d.localPosition, w)),
          child: _track(w, pct),
        );
      }),
    );
  }

  Widget _track(double w, double pct) => SizedBox(
        width: w,
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
            // Thumb tetap di dalam lintasan → tepi slider yang terlihat = tepi isi.
            left: (w * pct - 12).clamp(0.0, max(0.0, w - 24)),
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
      );
}
