import 'package:flutter/material.dart';

/// Tema aplikasi dengar (sama dengan web `lib/theme.ts usePlayerTheme`): `dark` · `light` · `system`.
const themeChoices = ['dark', 'light', 'system'];

String? _valid(String? v) => themeChoices.contains(v) ? v : null;

/// Urutan resolusi: pilihan akun (`me.theme`, ikut ke web/desktop) → pilihan perangkat (tamu/offline) → default
/// platform (`appearance.player_theme`, bawaan gelap). `appearance.allow_user_theme` = false → selalu default platform.
String resolveThemeChoice({String? account, String? device, String? platformDefault, bool allowUser = true}) =>
    (allowUser ? (_valid(account) ?? _valid(device)) : null) ?? _valid(platformDefault) ?? 'dark';

/// `system` mengikuti kecerahan OS.
ThemeMode themeModeOf(String choice) => switch (choice) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
