import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/screens/settings.dart';
import 'package:rave_mobile/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tangkapan layar Pengaturan penuh (font asli) ke build/shots — hanya bila RAVE_SHOTS=1 (pemeriksaan visual manual).
Future<void> _fonts() async {
  for (final (family, files) in [
    ('Bricolage', ['assets/fonts/BricolageGrotesque-Variable.ttf']),
    ('Staatliches', ['assets/fonts/Staatliches-Regular.ttf']),
    ('SpaceMono', ['assets/fonts/SpaceMono-Regular.ttf', 'assets/fonts/SpaceMono-Bold.ttf']),
  ]) {
    final l = FontLoader(family);
    for (final f in files) {
      l.addFont(rootBundle.load(f));
    }
    await l.load();
  }
  // Ikon Material (bukan aset aplikasi) — dari cache SDK Flutter agar ikon tidak tampil sebagai kotak.
  final icons = File('${Platform.environment['FLUTTER_ROOT'] ?? r'C:\Users\Melod\rave-mobile-tools\flutter'}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
}

void main() {
  final on = Platform.environment['RAVE_SHOTS'] == '1';
  for (final (mode, premium) in [('dark', false), ('light', false), ('dark', true)]) {
    testWidgets('shot settings $mode ${premium ? 'premium' : 'free'}', (t) async {
      await t.runAsync(_fonts);
      RaveMotion.infinite = false;
      Entrance.reset();
      SharedPreferences.setMockInitialValues({'locale': 'id', 'server': 'http://127.0.0.1:9'});
      final settings = await Settings.load();
      final api = Api(settings);
      api.user = Me(id: 'u1', email: 'indra@rave.id', displayName: 'Indra Pratama', premium: premium, verified: true, verificationStatus: 'VERIFIED', verifiedAt: '2026-11-10T00:00:00Z');
      api.debugAccessToken = 'test';
      final app = AppState(settings, api, Player(api, settings), Likes(api));
      const w = 412.0, h = 2600.0;
      t.view.physicalSize = const Size(w * 3, h * 3);
      t.view.devicePixelRatio = 3;
      t.view.padding = const FakeViewPadding(top: 24 * 3);
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(RepaintBoundary(
        key: key,
        child: App(state: app, child: MaterialApp(debugShowCheckedModeBanner: false, theme: mode == 'light' ? Rave.light : Rave.dark, home: const SettingsScreen())),
      ));
      await t.pump(const Duration(milliseconds: 900));
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 600)));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      if (!on) return;
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await t.runAsync(() async {
        final img = await boundary.toImage(pixelRatio: 1);
        // Potong per 1000 px (hanya bagian berisi konten) agar mudah dinilai.
        final content = (find.byType(Scrollable).evaluate().isEmpty ? h : h).toInt();
        for (var y = 0, i = 0; y < content; y += 1000, i++) {
          final seg = (content - y).clamp(0, 1000);
          final rec = ui.PictureRecorder();
          ui.Canvas(rec).drawImageRect(img, Rect.fromLTWH(0, y.toDouble(), w, seg.toDouble()), Rect.fromLTWH(0, 0, w, seg.toDouble()), Paint());
          final part = await rec.endRecording().toImage(w.toInt(), seg);
          final png = await part.toByteData(format: ui.ImageByteFormat.png);
          File('build/shots/settings-$mode-${premium ? 'premium' : 'free'}-$i.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        }
      });
    });
  }
}
