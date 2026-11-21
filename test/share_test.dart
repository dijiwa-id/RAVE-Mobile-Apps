import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/share.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/widgets/media.dart';
import 'package:rave_mobile/widgets/share_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _payload = <String, dynamic>{
  'track_id': 't1',
  'title': 'Senja di Bandung',
  'artist': 'Kolektif Pita',
  'url': 'https://rave.example/s/t/t1',
  'text': 'Lagi dengerin "Senja di Bandung" dari Kolektif Pita di RAVE',
  'hashtags': ['RAVE', 'MusikIndie'],
  'image_url': 'https://rave.example/v1/catalog/media/c.jpg?w=1280',
  'platforms': [
    {'id': 'facebook', 'url': 'https://www.facebook.com/sharer/sharer.php?u=x'},
    {'id': 'instagram', 'url': null},
    {'id': 'x', 'url': 'https://twitter.com/intent/tweet?text=a'},
  ],
};

Future<AppState> _state({Json? cfg}) async {
  SharedPreferences.setMockInitialValues({'locale': 'id'});
  final settings = await Settings.load();
  final api = Api(settings);
  final app = AppState(settings, api, Player(api, settings), Likes(api));
  if (cfg != null) await app.cache.load('cfg:platform', () async => {'settings': cfg});
  return app;
}

const _track = Track(
  id: 't1',
  title: 'Senja di Bandung',
  durationMs: 1000,
  trackNumber: 1,
  explicit: false,
  hasLyrics: false,
  artist: ArtistRef('a1', 'Kolektif Pita', 'kolektif-pita'),
  releaseId: 'r1',
  releaseTitle: 'Rilis',
);

void main() {
  group('TrackShare.fromJson', () {
    test('payload lengkap: platform diurutkan Instagram, X, Facebook; Instagram tanpa URL', () {
      final s = TrackShare.fromJson(_payload);
      expect(s.trackId, 't1');
      expect(s.hashtags, ['RAVE', 'MusikIndie']);
      expect(s.platforms.map((p) => p.id), ['instagram', 'x', 'facebook']);
      expect(s.platforms.first.url, isNull);
      expect(s.fullText, '${_payload['text']} https://rave.example/s/t/t1');
      expect(s.shortUrl, 'rave.example/s/t/t1');
    });

    test('platform tak dikenal/duplikat/tanpa URL intent dibuang; tipe salah ditoleransi', () {
      final s = TrackShare.fromJson({
        ..._payload,
        'hashtags': 'bukan-list',
        'image_url': '',
        'platforms': [
          {'id': 'tiktok', 'url': 'https://t.example'},
          {'id': 'x', 'url': null},
          {'id': 'facebook', 'url': 'javascript:alert(1)'},
          {'id': 'instagram', 'url': 'https://ig.example'},
          {'id': 'instagram', 'url': null},
          'rusak',
        ],
      });
      expect(s.platforms.map((p) => p.id), ['instagram']);
      expect(s.platforms.single.url, isNull);
      expect(s.hashtags, isEmpty);
      expect(s.imageUrl, isNull);
    });

    test('URL bagikan kosong/bukan http → FormatException', () {
      expect(() => TrackShare.fromJson({..._payload, 'url': ''}), throwsFormatException);
      expect(() => TrackShare.fromJson({..._payload, 'url': 'ftp://x'}), throwsFormatException);
    });
  });

  group('ShareFlags', () {
    test('kunci hilang (server lama) = aktif; false mematikan', () {
      expect(ShareFlags.fromConfig(const {}).enabled, isTrue);
      final f = ShareFlags.fromConfig(const {'share.enabled': true, 'share.x_enabled': false, 'share.instagram_enabled': 'rusak'});
      expect(f.allows('x'), isFalse);
      expect(f.allows('instagram'), isTrue);
      expect(f.allows('facebook'), isTrue);
      expect(ShareFlags.fromConfig(const {'share.enabled': false}).allows('facebook'), isFalse);
    });

    test('visiblePlatforms = platform server ∩ config', () {
      final s = TrackShare.fromJson(_payload);
      expect(visiblePlatforms(s, ShareFlags.fromConfig(const {'share.facebook_enabled': false})).map((p) => p.id), ['instagram', 'x']);
      expect(visiblePlatforms(s, ShareFlags.fromConfig(const {'share.enabled': false})), isEmpty);
    });
  });

  group('ShareRepo', () {
    test('cache per lagu + dedup permintaan paralel', () async {
      var calls = 0;
      final repo = ShareRepo((id) async {
        calls++;
        return {..._payload, 'track_id': id};
      });
      final r = await Future.wait([repo.load('t1'), repo.load('t1')]);
      expect(calls, 1);
      expect(r.first, isA<ShareReady>());
      expect(await repo.load('t1'), isA<ShareReady>());
      expect(calls, 1);
      expect(repo.peek('t1'), isA<ShareReady>());
    });

    test('404 → belum tersedia (di-cache 2 menit); offline → gagal (tidak di-cache)', () async {
      var now = DateTime(2026);
      var calls = 0;
      final repo = ShareRepo((id) async {
        calls++;
        if (id == 'off') throw const OfflineError();
        throw ApiError(404, 'Fitur bagikan');
      }, now: () => now);
      expect(await repo.load('gone'), isA<ShareUnavailable>());
      expect(await repo.load('gone'), isA<ShareUnavailable>());
      expect(calls, 1);
      now = now.add(const Duration(minutes: 3));
      expect(repo.peek('gone'), isNull);
      expect(await repo.load('off'), isA<ShareFailed>());
      expect(repo.peek('off'), isNull);
      expect(await repo.load('off'), isA<ShareFailed>());
      expect(calls, 3);
    });

    test('payload rusak → belum tersedia', () async {
      final repo = ShareRepo((_) async => const {'title': 'x'});
      expect(await repo.load('t1'), isA<ShareUnavailable>());
    });
  });

  group('Visibilitas & lembar', () {
    tearDown(() => ShareRepo.debugOverride = null);

    Future<void> pump(WidgetTester t, AppState app, Widget child) async {
      t.view.physicalSize = const Size(360 * 3, 800 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(App(state: app, child: MaterialApp(theme: Rave.dark, home: Scaffold(body: child))));
    }

    testWidgets('menu lagu: "Bagikan" ada bila aktif, hilang bila share.enabled=false', (t) async {
      for (final (cfg, want) in [(null, findsOneWidget), (const {'share.enabled': true}, findsOneWidget), (const {'share.enabled': false}, findsNothing)]) {
        final app = await t.runAsync(() => _state(cfg: cfg));
        await t.pumpWidget(const SizedBox());
        await pump(t, app!, Builder(builder: (c) => TextButton(onPressed: () => showTrackMenu(c, _track), child: const Text('menu'))));
        await t.tap(find.text('menu'));
        await t.pumpAndSettle();
        expect(find.text('Bagikan'), want, reason: 'cfg=$cfg');
        expect(find.byIcon(shareIcon), want);
      }
    });

    testWidgets('lembar: platform aktif saja + salin & lainnya', (t) async {
      ShareRepo.debugOverride = ShareRepo((_) async => _payload);
      final app = await t.runAsync(() => _state(cfg: const {'share.facebook_enabled': false}));
      await pump(t, app!, Builder(builder: (c) => TextButton(onPressed: () => showShareSheet(c, trackId: 't1', title: 'Senja di Bandung', artist: 'Kolektif Pita'), child: const Text('go'))));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('Bagikan lagu'.toUpperCase()), findsOneWidget);
      expect(find.byKey(const Key('share-instagram')), findsOneWidget);
      expect(find.byKey(const Key('share-x')), findsOneWidget);
      expect(find.byKey(const Key('share-facebook')), findsNothing);
      expect(find.text('Salin tautan'), findsOneWidget);
      expect(find.text('Lainnya…'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('lembar: 404 → "belum tersedia" tanpa tombol aksi; offline → coba lagi', (t) async {
      var offline = false;
      ShareRepo.debugOverride = ShareRepo((_) async => throw offline ? const OfflineError() : ApiError(404, 'x'));
      final app = await t.runAsync(() => _state());
      await pump(t, app!, Builder(builder: (c) => TextButton(onPressed: () => showShareSheet(c, trackId: 't9', title: 'A', artist: 'B'), child: const Text('go'))));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('share-unavailable')), findsOneWidget);
      expect(find.text('Bagikan belum tersedia'), findsOneWidget);
      expect(find.byKey(const Key('share-retry')), findsNothing);
      expect(find.text('Salin tautan'), findsNothing);
      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();

      offline = true;
      await t.pumpWidget(const SizedBox());
      await pump(t, app, Builder(builder: (c) => TextButton(onPressed: () => showShareSheet(c, trackId: 't10', title: 'A', artist: 'B'), child: const Text('go'))));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('share-retry')), findsOneWidget);
    });

    testWidgets('share.enabled=false → lembar tidak dibuka', (t) async {
      final app = await t.runAsync(() => _state(cfg: const {'share.enabled': false}));
      await pump(t, app!, Builder(builder: (c) => TextButton(onPressed: () => showShareSheet(c, trackId: 't1', title: 'A', artist: 'B'), child: const Text('go'))));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.byType(ShareSheet), findsNothing);
    });
  });

  testWidgets('kartu cerita: PNG 1080×1920 (dengan & tanpa sampul)', (t) async {
    await t.runAsync(() async {
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
      // Sampul sintetis 64×64 (gradasi) → uji jalur blur + potong persegi.
      final rec = ui.PictureRecorder();
      Canvas(rec).drawRect(
        const Rect.fromLTWH(0, 0, 64, 64),
        Paint()..shader = ui.Gradient.linear(Offset.zero, const Offset(64, 64), const [Color(0xFF1F5C52), Color(0xFFF4C21F)]),
      );
      final cover = await rec.endRecording().toImage(64, 64);
      final share = TrackShare.fromJson(_payload);
      for (final (name, img) in [('cover', cover), ('nocover', null)]) {
        final png = await renderStoryCard(share, tagline: 'Sedang diputar di RAVE', cover: img);
        expect(png.sublist(1, 4), 'PNG'.codeUnits);
        final codec = await ui.instantiateImageCodec(png);
        final frame = await codec.getNextFrame();
        expect((frame.image.width, frame.image.height), (1080, 1920));
        if (Platform.environment['RAVE_SHOTS'] == '1') File('build/shots/story-$name.png')..createSync(recursive: true)..writeAsBytesSync(png);
      }
    });
  });

  test('nama berkas kartu', () {
    expect(storyFileName('Senja di Bandung!'), 'RAVE-Senja-di-Bandung.png');
    expect(storyFileName('???'), 'RAVE-story.png');
  });
}
