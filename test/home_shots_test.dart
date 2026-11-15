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
import 'package:rave_mobile/screens/home.dart';
import 'package:rave_mobile/widgets/brand_marks.dart';
import 'package:rave_mobile/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tangkapan layar beranda (font asli) ke build/shots — hanya bila RAVE_SHOTS=1 (pemeriksaan visual manual).
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
}

void main() {
  final on = Platform.environment['RAVE_SHOTS'] == '1';
  for (final (mode, authed) in [('dark', false), ('light', false), ('dark', true)]) {
    for (final w in [360.0, 412.0]) {
      testWidgets('shot home $mode ${authed ? 'authed' : 'guest'} ${w.round()}', (t) async {
        await t.runAsync(_fonts);
        RaveMotion.infinite = false;
        Entrance.reset();
        SharedPreferences.setMockInitialValues({'locale': 'id'});
        final settings = await Settings.load();
        final api = Api(settings);
        if (authed) {
          api.user = const Me(id: 'u1', email: 'fan@rave.id', displayName: 'Indra');
          api.debugAccessToken = 'test';
        }
        final app = AppState(settings, api, Player(api, settings), Likes(api));
        await app.cache.load('/v1/catalog/home?', () async => HomeData.fromJson(const {'quick_picks': [], 'sections': []}));
        t.view.physicalSize = Size(w * 3, 900 * 3);
        t.view.devicePixelRatio = 3;
        t.view.padding = const FakeViewPadding(top: 24 * 3); // bilah status
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(RepaintBoundary(
          key: key,
          child: App(state: app, child: MaterialApp(debugShowCheckedModeBanner: false, theme: mode == 'light' ? Rave.light : Rave.dark, home: const HomeScreen())),
        ));
        await t.pump(const Duration(milliseconds: 900));
        expect(find.byType(RaveMark), findsOneWidget);
        if (!on) return;
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await t.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 1.5);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          final f = File('build/shots/home-$mode-${authed ? 'authed' : 'guest'}-${w.round()}.png')..createSync(recursive: true);
          f.writeAsBytesSync(png!.buffer.asUint8List());
        });
      });
    }
  }

  testWidgets('shot logo Google & ikon V', (t) async {
    final key = GlobalKey();
    await t.pumpWidget(RepaintBoundary(
      key: key,
      child: const Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(color: Color(0xFF3A1A47), child: Padding(padding: EdgeInsets.all(12), child: Row(mainAxisSize: MainAxisSize.min, children: [GoogleLogo(size: 96), SizedBox(width: 16), RaveMark(size: 96)]))),
      ),
    ));
    if (!on) return;
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('build/shots/marks.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
