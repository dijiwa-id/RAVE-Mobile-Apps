import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/screens/intro.dart';
import 'package:rave_mobile/widgets/cassette.dart';
import 'package:rave_mobile/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding: slide 1 (kaset + sampul rilis asli / cadangan) dan seluruh alur dirender tanpa overflow di lebar
/// 320–412 dp, layar pendek 360×640, dan skala teks 1,3. Tanpa jaringan: sampul "asli" disuntik lewat DataCache.
/// Font merek asli (bukan font uji kotak) → metrik teks realistis untuk uji overflow.
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

Future<AppState> _state({bool covers = false}) async {
  SharedPreferences.setMockInitialValues({'locale': 'id'});
  final settings = await Settings.load();
  final api = Api(settings);
  final app = AppState(settings, api, Player(api, settings), Likes(api));
  if (covers) {
    await app.cache.load(WelcomeArt.cacheKey, () async => HomeData.fromJson(_home));
  }
  return app;
}

const _home = {
  'quick_picks': [
    {'id': 'a1', 'kind': 'artist', 'title': 'Artis', 'subtitle': 'Artis', 'href': '/app/artist/a', 'image_url': 'https://cdn.test/artist.jpg'},
    {'id': 'r9', 'kind': 'release', 'title': 'Quick', 'subtitle': 'Single', 'href': '/app/album/r9', 'image_url': 'https://cdn.test/r9.jpg'},
  ],
  'sections': [
    {
      'id': 'new-releases',
      'title': 'Rilis Baru',
      'kind': 'releases',
      'items': [
        {'id': 'r1', 'kind': 'release', 'title': 'Satu', 'subtitle': 'Album', 'href': '/app/album/r1', 'image_url': '/v1/catalog/media/r1.jpg'},
        {'id': 'r2', 'kind': 'release', 'title': 'Dua', 'subtitle': 'EP', 'href': '/app/album/r2', 'image_url': null},
        {'id': 'r3', 'kind': 'release', 'title': 'Tiga', 'subtitle': 'Single', 'href': '/app/album/r3', 'image_url': 'https://cdn.test/r3.jpg'},
      ],
    },
  ],
};

Future<void> _pump(WidgetTester t, AppState app, {double width = 360, double height = 800, double textScale = 1}) async {
  t.view.physicalSize = Size(width * 3, height * 3);
  t.view.devicePixelRatio = 3;
  t.view.padding = const FakeViewPadding(top: 24 * 3, bottom: 24 * 3); // bilah status & navigasi gesture
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(t.view.reset);
  addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
  await t.runAsync(_fonts);
  // Seperti main.dart: aplikasi dibangun ulang saat pengaturan (bahasa) berubah.
  await t.pumpWidget(ListenableBuilder(
    listenable: app.settings,
    builder: (_, _) => App(state: app, child: MaterialApp(theme: Rave.dark, home: DarkZone(child: Onboarding(onDone: () {})))),
  ));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => RaveMotion.infinite = false);

  test('welcomeCovers: rilis bersampul dari seksi releases lebih dulu, lalu quick picks; tanpa artis/duplikat', () {
    final d = HomeData.fromJson(_home);
    expect(welcomeCovers(d), ['/v1/catalog/media/r1.jpg', 'https://cdn.test/r3.jpg', 'https://cdn.test/r9.jpg']);
    expect(welcomeCovers(d, max: 1), ['/v1/catalog/media/r1.jpg']);
    expect(welcomeCovers(const HomeData([], [])), isEmpty);
  });

  const sizes = [(320.0, 640.0), (360.0, 640.0), (360.0, 800.0), (412.0, 915.0), (480.0, 800.0)];
  for (final (w, h) in sizes) {
    for (final scale in [1.0, 1.3]) {
      for (final covers in [false, true]) {
        testWidgets('slide 1 ${w.round()}×${h.round()} teks ×$scale ${covers ? 'sampul asli' : 'cadangan'}: tanpa overflow', (t) async {
          final app = await _state(covers: covers);
          await _pump(t, app, width: w, height: h, textScale: scale);
          expect(t.takeException(), isNull);
          expect(find.byType(Cassette), findsOneWidget);
          expect(find.byType(CachedNetworkImage), covers ? findsNWidgets(3) : findsNothing);
          // Sampul cadangan bergaya selalu ada di bawah (offline / sebelum sampul asli memudar masuk).
          expect(find.text('SENJA'), findsOneWidget);
          expect(find.text('MULAI'), findsOneWidget);
          // Ilustrasi tetap di dalam layar (lebar) & CTA berada di atas inset bawah.
          final art = t.getRect(find.byKey(const ValueKey('welcome-art')));
          expect(art.left, greaterThanOrEqualTo(0));
          expect(art.right, lessThanOrEqualTo(w));
          expect(t.getRect(find.text('MULAI')).bottom, lessThanOrEqualTo(h - 24));
        });
      }
    }
  }

  testWidgets('sampul asli memakai URL media absolut (api.media)', (t) async {
    final app = await _state(covers: true);
    await _pump(t, app);
    final urls = t.widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage)).map((c) => c.imageUrl).toList();
    expect(urls, unorderedEquals(['${app.api.base}/v1/catalog/media/r1.jpg', 'https://cdn.test/r3.jpg', 'https://cdn.test/r9.jpg']));
  });

  for (final (w, h, scale) in [(320.0, 640.0, 1.3), (360.0, 640.0, 1.0), (412.0, 915.0, 1.3)]) {
    testWidgets('alur lengkap ${w.round()}×${h.round()} teks ×$scale: kota → genre → artis → siap tanpa overflow', (t) async {
      final app = await _state();
      await _pump(t, app, width: w, height: h, textScale: scale);
      await t.tap(find.text('MULAI'));
      await t.pumpAndSettle();
      expect(find.text('01 / 03'), findsOneWidget);
      await t.ensureVisible(find.text('BANDUNG'));
      await t.tap(find.text('BANDUNG'));
      await t.pump();
      await t.tap(find.text('LANJUT'));
      await t.pumpAndSettle();
      expect(find.text('02 / 03'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.text('SHOEGAZE'));
      await t.pumpAndSettle();
      await t.tap(find.text('SHOEGAZE'));
      await t.pump();
      await t.tap(find.text('LANJUT'));
      await t.pumpAndSettle();
      expect(find.text('03 / 03'), findsOneWidget);
      expect(t.takeException(), isNull);
      // Kembali & lewati tetap berfungsi.
      await t.tap(find.byIcon(Icons.arrow_back_rounded));
      await t.pumpAndSettle();
      expect(find.text('02 / 03'), findsOneWidget);
      await t.tap(find.text('LEWATI'));
      await t.pumpAndSettle();
      expect(find.text('MASUK / DAFTAR'), findsOneWidget);
      expect(find.text('JELAJAHI DULU'), findsOneWidget);
      expect(t.takeException(), isNull);
      expect(app.settings.city, isNull); // belum disimpan sebelum selesai
    });
  }

  testWidgets('ID/EN berganti bahasa onboarding', (t) async {
    final app = await _state();
    await _pump(t, app);
    await t.tap(find.text('EN'));
    await t.pumpAndSettle();
    expect(find.text('GET STARTED'), findsOneWidget);
    expect(app.settings.locale, 'en');
  });

  group('Cassette', () {
    test('ketiga lapis painter menggambar tanpa galat', () {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      const size = Size(400, 256);
      const CassetteBodyPainter(label: 'RAVE').paint(canvas, size);
      CassetteReelsPainter(const AlwaysStoppedAnimation(0.3)).paint(canvas, size);
      const CassetteGlassPainter().paint(canvas, size);
      expect(rec.endRecording(), isNotNull);
    });

    Future<AnimationController> pumpTape(WidgetTester t, {bool reduce = false}) async {
      await t.pumpWidget(MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: const Directionality(textDirection: TextDirection.ltr, child: Center(child: Cassette(width: 240))),
      ));
      expect(t.getSize(find.byType(Cassette)), const Size(240, 240 * Cassette.aspect));
      final reels = t.widgetList<CustomPaint>(find.descendant(of: find.byType(Cassette), matching: find.byType(CustomPaint))).map((p) => p.painter).whereType<CassetteReelsPainter>().single;
      return reels.turns as AnimationController;
    }

    testWidgets('diam saat RaveMotion.infinite = false (pumpAndSettle selesai)', (t) async {
      final c = await pumpTape(t);
      await t.pumpAndSettle();
      expect(c.isAnimating, isFalse);
    });

    testWidgets('berputar bila diizinkan, diam saat kurangi gerakan', (t) async {
      RaveMotion.infinite = true;
      addTearDown(() => RaveMotion.infinite = false);
      final c = await pumpTape(t);
      expect(c.isAnimating, isTrue);
      await t.pump(const Duration(milliseconds: 500));
      final reduced = await pumpTape(t, reduce: true);
      expect(reduced.isAnimating, isFalse);
      await t.pumpWidget(const SizedBox()); // dispose controller
    });
  });
}
