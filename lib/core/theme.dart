import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/motion.dart';

/// Token merek RAVE (sama dengan web & desktop): kanvas gelap, primer mustard berteks ink, ungu/plum/teal/berry
/// sebagai aksen, sudut tegas, bayangan sablon, judul poster Staatliches, label Space Mono.
///
/// Konstanta di sini adalah warna MEREK (tetap di kedua tema). Warna yang bergantung tema (kanvas, permukaan, teks,
/// garis, aksen teks aktif) dibaca lewat [RaveColors] — `context.rc` — agar tema terang ("poster kertas berwarna")
/// dan gelap sama-sama benar. Konstanta `canvas`/`muted`/… di bawah adalah nilai tema GELAP (dipakai di "pulau
/// gelap": pemutar, kartu poster, konten di atas foto/warna).
abstract final class Rave {
  static const ink = Color(0xFF181818);
  static const paper = Color(0xFFEDEDED);
  static const purple = Color(0xFF5B2A6E);
  static const purpleSoft = Color(0xFF7A3E91);
  static const plum = Color(0xFF2A1233);
  static const mustard = Color(0xFFF4C21F);
  static const mustardHi = Color(0xFFFFD23F);
  static const teal = Color(0xFF1F5C52);
  static const berry = Color(0xFF8A2F3F);

  static const canvas = Color(0xFF0E0C0F);
  static const base = Color(0xFF151316);
  static const raised = Color(0xFF1F1D21);
  static const hover = Color(0xFF2B282E);
  static const line = Color(0xFF2E2B31);
  static const muted = Color(0xFFBDB8C2);
  static const subtle = Color(0xFF8A8490);
  static const shadow = Color(0xFF0B0A0C);

  /// Gutter horizontal standar (dp): tepi isi halaman, kartu, rak, mini-player & Sedang Diputar sejajar di sini.
  static const gutter = 16.0;

  /// Target sentuh minimum (dp).
  static const tap = 48.0;

  static const sans = 'Bricolage';
  static const display = 'Staatliches';
  static const mono = 'SpaceMono';

  /// Judul poster kapital padat. Tanpa [color] → mewarisi warna teks tema (paper di gelap, ink di terang).
  static TextStyle poster(double size, {Color? color}) =>
      TextStyle(fontFamily: display, fontSize: size, height: 0.95, color: color, letterSpacing: 0.2);

  /// Label/eyebrow ala stempel: mono kapital berspasi lebar (teks diubah ke kapital oleh pemanggil).
  static TextStyle label({double size = 10.5, Color color = muted}) =>
      TextStyle(fontFamily: mono, fontSize: size, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: color);

  /// Teks badan dengan bobot variabel (Bricolage Grotesque Variable). Tanpa [color] → warna teks tema.
  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color, double? height}) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
        color: color,
        height: height,
      );

  /// Bayangan sablon (offset keras, tanpa blur) — warna gelap; di tema terang pakai `context.rc.hard()`.
  static const hardShadow = [BoxShadow(color: shadow, offset: Offset(3, 3))];

  static final ThemeData dark = _build(RaveColors.dark);
  static final ThemeData light = _build(RaveColors.light);

  /// Tema gelap (kompatibel dengan pemanggil lama).
  static ThemeData theme() => dark;

  /// Ikon bilah status & navigasi mengikuti tema.
  static SystemUiOverlayStyle overlayFor(Brightness b) => b == Brightness.light
      ? const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFFF6F1E7),
          systemNavigationBarIconBrightness: Brightness.dark,
        )
      : const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: canvas,
          systemNavigationBarIconBrightness: Brightness.light,
        );

  static ThemeData _build(RaveColors c) {
    final isLight = c.isLight;
    final t = ThemeData(brightness: isLight ? Brightness.light : Brightness.dark, useMaterial3: true);
    return t.copyWith(
      scaffoldBackgroundColor: c.canvas,
      canvasColor: c.canvas,
      extensions: [c],
      colorScheme: isLight
          ? const ColorScheme.light(primary: mustard, onPrimary: ink, secondary: purple, surface: Color(0xFFFFFDF8), onSurface: Color(0xFF1B181D), error: berry)
          : const ColorScheme.dark(primary: mustard, onPrimary: ink, secondary: purpleSoft, surface: base, onSurface: paper, error: berry),
      textTheme: t.textTheme.apply(fontFamily: sans, bodyColor: c.text, displayColor: c.text),
      splashFactory: InkSparkle.splashFactory,
      highlightColor: isLight ? Colors.black12 : Colors.white10,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: c.text,
        systemOverlayStyle: overlayFor(isLight ? Brightness.light : Brightness.dark),
      ),
      iconTheme: IconThemeData(color: c.text),
      dividerColor: c.line,
      sliderTheme: SliderThemeData(
        trackHeight: 3,
        activeTrackColor: c.text,
        inactiveTrackColor: isLight ? const Color(0x40181818) : const Color(0xFF4A4550),
        thumbColor: c.text,
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : raised,
        hintStyle: TextStyle(color: c.subtle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c.inputBorder, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: c.inputBorder, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: isLight ? purple : mustard, width: 2)),
      ),
      textSelectionTheme: isLight ? const TextSelectionThemeData(cursorColor: purple, selectionHandleColor: purple, selectionColor: Color(0x405B2A6E)) : null,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: paper,
        contentTextStyle: body(weight: FontWeight.w600, color: ink),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: ink, width: 2)),
      ),
      bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.sheet, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
      progressIndicatorTheme: isLight ? const ProgressIndicatorThemeData(color: purple) : null,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: RavePageTransitionsBuilder(), TargetPlatform.iOS: RavePageTransitionsBuilder()}),
    );
  }
}

/// Warna semantik RAVE per tema (ThemeExtension) — baca lewat `context.rc`.
@immutable
class RaveColors extends ThemeExtension<RaveColors> {
  const RaveColors({
    required this.isLight,
    required this.canvas,
    required this.base,
    required this.raised,
    required this.hover,
    required this.line,
    required this.text,
    required this.muted,
    required this.subtle,
    required this.accent,
    required this.shadow,
    required this.card,
    required this.cardBorder,
    required this.veil,
    required this.chip,
    required this.chipBorder,
    required this.inputBorder,
    required this.sheet,
    required this.dots,
  });

  final bool isLight;
  /// Latar halaman; permukaan dasar; permukaan terangkat (tile kosong, placeholder); hover; garis.
  final Color canvas, base, raised, hover, line;
  /// Teks utama, sekunder, tersier di atas kanvas.
  final Color text, muted, subtle;
  /// Teks/ikon aktif (lagu diputar, tautan): mustard di gelap, ungu di terang (mustard tak terbaca di kertas).
  final Color accent;
  /// Bayangan sablon (offset keras).
  final Color shadow;
  /// Kartu/panel (pengaturan) + tepinya.
  final Color card, cardBorder;
  /// Lapisan tipis untuk tile (quick picks, tombol pil): putih 10% di gelap, ink 6% di terang.
  final Color veil;
  /// Chip pilihan tak terpilih + tepinya.
  final Color chip, chipBorder;
  final Color inputBorder;
  /// Lembar bawah & dialog.
  final Color sheet;
  /// Titik halftone halus di kanvas (transparan di gelap).
  final Color dots;

  static const dark = RaveColors(
    isLight: false,
    canvas: Rave.canvas,
    base: Rave.base,
    raised: Rave.raised,
    hover: Rave.hover,
    line: Rave.line,
    text: Rave.paper,
    muted: Rave.muted,
    subtle: Rave.subtle,
    accent: Rave.mustard,
    shadow: Rave.shadow,
    card: Color(0x08FFFFFF),
    cardBorder: Color(0x14FFFFFF),
    veil: Color(0x1AFFFFFF),
    chip: Color(0x0FFFFFFF),
    chipBorder: Color(0x24FFFFFF),
    inputBorder: Rave.line,
    sheet: Rave.base,
    dots: Color(0x00000000),
  );

  static const light = RaveColors(
    isLight: true,
    canvas: Color(0xFFF6F1E7),
    base: Color(0xFFFFFDF8),
    raised: Color(0xFFFFFDF8),
    hover: Color(0xFFE8E0CF),
    line: Color(0xFFD8CFBD),
    text: Color(0xFF1B181D),
    muted: Color(0xFF5A5361),
    subtle: Color(0xFF847C89),
    accent: Rave.purple,
    shadow: Rave.ink,
    card: Color(0xFFFFFDF8),
    cardBorder: Color(0x24181818),
    veil: Color(0x0F181818),
    chip: Color(0xFFFFFDF8),
    chipBorder: Color(0x33181818),
    inputBorder: Color(0x33181818),
    sheet: Color(0xFFFFFDF8),
    dots: Color(0x125B2A6E),
  );

  /// Bayangan sablon tema ini.
  List<BoxShadow> hard([double d = 3]) => [BoxShadow(color: shadow, offset: Offset(d, d))];

  @override
  RaveColors copyWith() => this;

  @override
  RaveColors lerp(RaveColors? other, double t) => other == null || t < 0.5 ? this : other;
}

extension RaveThemeContext on BuildContext {
  /// Warna semantik tema aktif (gelap bila tidak ada ekstensi RAVE).
  RaveColors get rc => Theme.of(this).extension<RaveColors>() ?? RaveColors.dark;
}

/// "Pulau gelap": isi selalu memakai tema gelap (teks & ikon terang) — pemutar/deck, konten di atas foto/warna
/// (kartu poster artis, tile pilihan, kartu langkah berwarna, header artis, layar Sedang Diputar). Struktur pohon
/// sama di kedua tema (state tidak hilang saat tema berganti).
class DarkZone extends StatelessWidget {
  const DarkZone({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
        data: Rave.dark,
        child: IconTheme(
          data: const IconThemeData(color: Rave.paper),
          child: DefaultTextStyle.merge(style: const TextStyle(color: Rave.paper), child: child),
        ),
      );
}
