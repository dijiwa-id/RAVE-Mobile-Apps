import 'package:flutter/material.dart';

/// Token merek RAVE (sama dengan web & desktop): kanvas gelap, primer mustard berteks ink, ungu/plum/teal/berry
/// sebagai aksen, sudut tegas, bayangan sablon, judul poster Staatliches, label Space Mono.
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

  static const sans = 'Bricolage';
  static const display = 'Staatliches';
  static const mono = 'SpaceMono';

  /// Judul poster kapital padat.
  static TextStyle poster(double size, {Color color = paper}) =>
      TextStyle(fontFamily: display, fontSize: size, height: 0.95, color: color, letterSpacing: 0.2);

  /// Label/eyebrow ala stempel: mono kapital berspasi lebar (teks diubah ke kapital oleh pemanggil).
  static TextStyle label({double size = 10.5, Color color = muted}) =>
      TextStyle(fontFamily: mono, fontSize: size, fontWeight: FontWeight.w700, letterSpacing: 1.3, color: color);

  /// Teks badan dengan bobot variabel (Bricolage Grotesque Variable).
  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color color = paper, double? height}) => TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
        color: color,
        height: height,
      );

  /// Bayangan sablon (offset keras, tanpa blur).
  static const hardShadow = [BoxShadow(color: shadow, offset: Offset(3, 3))];

  static ThemeData theme() {
    final t = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return t.copyWith(
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      colorScheme: const ColorScheme.dark(
        primary: mustard,
        onPrimary: ink,
        secondary: purpleSoft,
        surface: base,
        onSurface: paper,
        error: berry,
      ),
      textTheme: t.textTheme.apply(fontFamily: sans, bodyColor: paper, displayColor: paper),
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.white10,
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, foregroundColor: paper),
      iconTheme: const IconThemeData(color: paper),
      dividerColor: line,
      sliderTheme: const SliderThemeData(
        trackHeight: 3,
        activeTrackColor: paper,
        inactiveTrackColor: Color(0xFF4A4550),
        thumbColor: paper,
        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: raised,
        hintStyle: const TextStyle(color: subtle),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: line, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: line, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: const BorderSide(color: mustard, width: 2)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: paper,
        contentTextStyle: body(weight: FontWeight.w600, color: ink),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: ink, width: 2)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: base, shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero)),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()}),
    );
  }
}
