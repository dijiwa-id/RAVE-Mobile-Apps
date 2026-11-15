import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/screens/home.dart';
import 'package:rave_mobile/screens/library.dart';
import 'package:rave_mobile/screens/now_playing.dart';
import 'package:rave_mobile/widgets/mini_player.dart';
import 'package:rave_mobile/screens/settings.dart';
import 'package:rave_mobile/widgets/brand_marks.dart';
import 'package:rave_mobile/widgets/common.dart';
import 'package:rave_mobile/widgets/getting_started.dart';
import 'package:rave_mobile/widgets/collection.dart';
import 'package:rave_mobile/widgets/media.dart';
import 'package:rave_mobile/widgets/motion.dart';
import 'package:rave_mobile/widgets/vinyl.dart';
import 'package:rave_mobile/widgets/deck.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uji asap tata letak (tanpa jaringan/gambar): komponen baru dirender di lebar ponsel kecil & sedang tanpa
/// overflow/assert.
/// Tema yang sedang diuji (setiap uji dijalankan di tema gelap DAN terang).
ThemeData _theme = Rave.dark;

Future<AppState> _state([String locale = 'id']) async {
  SharedPreferences.setMockInitialValues({'locale': locale});
  final settings = await Settings.load();
  final api = Api(settings);
  return AppState(settings, api, Player(api, settings), Likes(api));
}

Future<void> _pump(WidgetTester t, AppState app, Widget child, {double width = 360, double height = 800}) async {
  t.view.physicalSize = Size(width * 3, height * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(App(state: app, child: MaterialApp(theme: _theme, home: Scaffold(body: child))));
  await t.pump(const Duration(milliseconds: 500));
}

void main() {
  for (final mode in ['gelap', 'terang']) {
    group('tema $mode', () {
      setUp(() {
        _theme = mode == 'terang' ? Rave.light : Rave.dark;
        // Animasi tak berujung (shimmer) dimatikan agar pumpAndSettle selesai; masuk bertahap tetap diuji.
        RaveMotion.infinite = false;
        Entrance.reset();
      });
      _suite();
    });
  }
}

void _suite() {
  for (final w in [360.0, 412.0]) {
    testWidgets('Mulai di RAVE (${w.round()} dp): 6 langkah, CTA & Tips berikutnya', (t) async {
      final app = await _state();
      final steps = <String>[];
      await _pump(t, app, ListView(children: [GettingStarted(liveOn: true, eventsOn: true, onCta: steps.add)]), width: w);
      expect(find.text('LANGKAH 1 DARI 6'), findsOneWidget);
      expect(find.text('MULAI MEMUTAR'), findsOneWidget);
      await t.tap(find.text('Cari'));
      expect(steps, ['play']);
      await t.tap(find.text('Tips berikutnya'));
      await t.pumpAndSettle();
      expect(find.text('LANGKAH 2 DARI 6'), findsOneWidget);
    });

    testWidgets('kartu media & artis (${w.round()} dp)', (t) async {
      final app = await _state();
      await _pump(
        t,
        app,
        ListView(children: [
          Shelf(title: 'Rilis', children: const [
            MediaCard(item: MediaItem(id: 'r1', kind: 'release', title: 'Album Panjang Sekali Judulnya', subtitle: 'Artis · 2026', href: '/app/album/r1')),
            MediaCard(item: MediaItem(id: 'p1', kind: 'playlist', title: 'Tanpa sampul', subtitle: 'Playlist', href: '/app/playlist/p1')),
          ]),
          Shelf(title: 'Artis', children: const [
            MediaCard(item: MediaItem(id: 'a1', kind: 'artist', title: 'Senja Kolektif Bersaudara', subtitle: 'Bandung', href: '/app/artist/senja')),
          ]),
        ]),
        width: w,
      );
      expect(find.text('SENJA KOLEKTIF BERSAUDARA'), findsOneWidget);
      expect(find.byIcon(Icons.queue_music_rounded), findsWidgets);
    });

    testWidgets('piringan Sedang Diputar (${w.round()} dp)', (t) async {
      final app = await _state();
      await _pump(t, app, Center(child: VinylCover(width: w - 48, image: null, labelColor: Rave.purple, spinning: true, tape: 'FLAC 24/96')), width: w);
      expect(find.text('FLAC 24/96'), findsOneWidget);
    });

    testWidgets('Pengaturan tamu: hanya kartu Masuk / Daftar (${w.round()} dp)', (t) async {
      final app = await _state();
      await _pump(t, app, const SettingsScreen(), width: w);
      expect(find.text('MASUK DULU BUAT ATUR RAVE'), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Daftar'), findsOneWidget);
      for (final hidden in ['AKUN', 'KUALITAS AUDIO', 'EQUALIZER', 'TAMPILAN', 'SERVER', 'NOTIFIKASI', 'PRIVASI', 'ZONA BAHAYA', 'PEMUTARAN']) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('Pengaturan akun Gratis: kartu Premium, tanpa Kualitas audio/EQ; cari (${w.round()} dp)', (t) async {
      final app = await _state();
      app.api.user = const Me(id: 'u1', email: 'fan@rave.id', displayName: 'Fan Rave');
      await _pump(t, app, const SettingsScreen(), width: w);
      expect(find.text('KUALITAS AUDIO'), findsNothing);
      expect(find.text('EQUALIZER'), findsNothing);
      expect(find.text('Kualitas audio tinggi & Equalizer'), findsOneWidget);
      expect(find.text('Lihat Premium'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'normal');
      await t.pump();
      expect(find.text('Normalisasi volume'), findsOneWidget);
      // Cari hanya baris yang tampil: "equalizer" → kartu Premium, bukan bagian EQ.
      await t.enterText(find.byType(TextField).first, 'equalizer');
      await t.pump();
      expect(find.text('Kualitas audio tinggi & Equalizer'), findsOneWidget);
      expect(find.text('EQUALIZER'), findsNothing);
      await t.enterText(find.byType(TextField).first, 'zzzz');
      await t.pump();
      expect(find.textContaining('Nggak ada pengaturan'), findsOneWidget);
    });

    testWidgets('Pengaturan akun Premium: Kualitas audio & Equalizer tampil (${w.round()} dp)', (t) async {
      final app = await _state();
      app.api.user = const Me(id: 'u2', email: 'premium@rave.id', displayName: 'Premium Rave', premium: true);
      await _pump(t, app, const SettingsScreen(), width: w);
      expect(find.text('KUALITAS AUDIO'), findsWidgets);
      expect(find.text('Kualitas audio tinggi & Equalizer'), findsNothing);
      await t.enterText(find.byType(TextField).first, 'equalizer');
      await t.pump();
      expect(find.text('EQUALIZER'), findsOneWidget);
      await t.enterText(find.byType(TextField).first, 'normal');
      await t.pump();
      expect(find.text('Normalisasi volume'), findsOneWidget);
    });

    testWidgets('Beranda tamu: Masuk + Daftar, tanpa ikon Pengaturan (${w.round()} dp)', (t) async {
      final app = await _state();
      await app.cache.load('/v1/catalog/home?', () async => HomeData.fromJson(const {'quick_picks': [], 'sections': []}));
      await _pump(t, app, const HomeScreen(), width: w);
      expect(find.text('MASUK'), findsOneWidget);
      expect(find.text('DAFTAR'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
    });

    testWidgets('Beranda: ikon V sejajar Masuk, hero di bawah bilah atas (${w.round()} dp)', (t) async {
      final app = await _state();
      await app.cache.load('/v1/catalog/home?', () async => HomeData.fromJson(const {'quick_picks': [], 'sections': []}));
      await _pump(t, app, const HomeScreen(), width: w);
      final mark = t.getRect(find.byType(RaveMark));
      final login = t.getRect(find.text('MASUK'));
      final hero = t.getRect(find.textContaining('RAVE · '));
      expect((mark.center.dy - login.center.dy).abs(), lessThan(1.5), reason: 'ikon & tombol Masuk satu baris');
      expect(hero.top, greaterThan(login.bottom + 12), reason: 'hero tidak menumpuk dengan tombol Masuk');
    });
  }

  testWidgets('Getting started (EN, 360 dp): semua langkah tanpa overflow', (t) async {
    final app = await _state('en');
    await _pump(t, app, ListView(children: [GettingStarted(liveOn: true, eventsOn: true, onCta: (_) {})]));
    for (var i = 1; i <= 6; i++) {
      expect(find.text('STEP $i OF 6'), findsOneWidget);
      await t.tap(find.text(i == 6 ? 'Start over' : 'Next tip'));
      await t.pumpAndSettle();
    }
    expect(find.text('STEP 1 OF 6'), findsOneWidget);
  });

  for (final h in [640.0, 800.0]) {
    testWidgets('layar Sedang Diputar (360×${h.round()})', (t) async {
      final app = await _state();
      app.player.current = const Playable(id: 't1', kind: 'track', title: 'Lagu Uji Yang Cukup Panjang', subtitle: 'Senja Kolektif', durationMs: 180000);
      await _pump(t, app, const NowPlayingScreen(), height: h);
      expect(find.text('LAGU UJI YANG CUKUP PANJANG'), findsOneWidget);
    });
  }

  testWidgets('PlayFab dengan kunci konteks: Jeda hanya bila antrean berasal dari item itu', (t) async {
    final app = await _state();
    await _pump(t, app, Row(children: [PlayFab(playKey: 'release:r1', onPlay: () {}), PlayFab(playKey: 'release:r2', onPlay: () {})]));
    expect(find.byIcon(Icons.play_arrow_rounded), findsNWidgets(2));
    app.player
      ..current = const Playable(id: 't1', kind: 'track', title: 'x', subtitle: 'y', durationMs: 1000)
      ..context = 'release:r1'
      ..buffering = false;
    expect(app.player.isActive('release:r1'), isTrue);
    expect(app.player.isActive('release:r2'), isFalse);
  });

  for (final w in [360.0, 412.0]) {
    testWidgets('Beranda dengan data (${w.round()} dp): chip, Mulai di RAVE, quick picks, rak', (t) async {
      final app = await _state();
      // Isi cache SWR → ApiView beranda langsung tampil tanpa jaringan.
      await app.cache.load('/v1/catalog/home?', () async => HomeData.fromJson({
            'quick_picks': [
              {'id': 'r1', 'kind': 'release', 'title': 'Album Satu', 'subtitle': 'Artis', 'href': '/app/album/r1'},
              {'id': 'a1', 'kind': 'artist', 'title': 'Senja Kolektif', 'subtitle': 'Artis', 'href': '/app/artist/senja'},
              {'id': 'p1', 'kind': 'playlist', 'title': 'Playlist Panjang Sekali Namanya Ya', 'subtitle': '', 'href': '/app/playlist/p1'},
            ],
            'sections': [
              {
                'id': 's1',
                'title': 'Rilis baru',
                'kind': 'releases',
                'items': [
                  {'id': 'r2', 'kind': 'release', 'title': 'Rilis Dua', 'subtitle': 'Band', 'href': '/app/album/r2'},
                ],
              },
              {
                'id': 's2',
                'title': 'Artis',
                'kind': 'artists',
                'items': [
                  {'id': 'a2', 'kind': 'artist', 'title': 'Band Kamar', 'subtitle': 'Bandung', 'href': '/app/artist/band'},
                ],
              },
            ],
          }));
      await _pump(t, app, const HomeScreen(), width: w);
      expect(find.text('Album Satu'), findsOneWidget);
      expect(find.text('RILIS BARU'), findsOneWidget);
      expect(find.text('MULAI DI RAVE'), findsOneWidget);
      await t.tap(find.text('Artis').first);
      await t.pumpAndSettle();
      expect(find.text('MULAI DI RAVE'), findsNothing);
      expect(find.text('BAND KAMAR'), findsOneWidget);
      expect(find.text('Album Satu'), findsNothing);
    });

    testWidgets('Koleksi tamu, daftar lagu & mini-player (${w.round()} dp)', (t) async {
      final app = await _state();
      final track = Track.fromJson(const {
        'id': 't1',
        'title': 'Lagu Satu',
        'duration_ms': 200000,
        'explicit': true,
        'artist': {'id': 'a1', 'name': 'Senja', 'slug': 'senja'},
        'release': {'id': 'r1', 'title': 'Album'},
      });
      app.player.current = Playable.fromTrack(track);
      await _pump(
        t,
        app,
        Column(children: [
          const Expanded(child: LibraryScreen()),
          SizedBox(height: 160, child: CustomScrollView(slivers: [TrackSliver(tracks: [track, track], numbered: true)])),
          const MiniPlayer(),
        ]),
        width: w,
      );
      expect(find.text('Lagu Satu'), findsWidgets);
    });
  }

  testWidgets('Pengaturan: baris Tema mengganti pilihan tema', (t) async {
    final app = await _state();
    app.api.user = const Me(id: 'u1', email: 'fan@rave.id', displayName: 'Fan Rave');
    await _pump(t, app, const SettingsScreen());
    await t.enterText(find.byType(TextField).first, 'tema');
    await t.pump();
    expect(find.text('Tema'), findsOneWidget);
    await t.tap(find.text('Terang'));
    await t.pump();
    expect(app.settings.themePref, 'light');
    expect(app.themeChoice, 'light');
  });

  for (final w in [360.0, 412.0]) {
    testWidgets('halaman koleksi: paralaks & app bar saat digulir (${w.round()} dp)', (t) async {
      final app = await _state();
      final tracks = [
        for (var i = 0; i < 20; i++)
          Track.fromJson({
            'id': 't$i',
            'title': 'Lagu $i',
            'duration_ms': 200000,
            'artist': {'id': 'a1', 'name': 'Senja', 'slug': 'senja'},
            'release': {'id': 'r1', 'title': 'Album'},
          }),
      ];
      await _pump(
        t,
        app,
        CollectionPage(kind: 'Album', title: 'Album Uji', meta: const Text('2026'), actions: const [], slivers: [TrackSliver(tracks: tracks, numbered: true, contextKey: 'release:r1')]),
        width: w,
      );
      await t.pumpAndSettle();
      expect(find.text('ALBUM UJI'), findsOneWidget);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await t.pumpAndSettle();
      expect(find.text('Album Uji'), findsOneWidget); // judul kecil di app bar
      await t.drag(find.byType(CustomScrollView), const Offset(0, 900));
      await t.pumpAndSettle();
      expect(find.text('ALBUM UJI'), findsOneWidget);
    });

    testWidgets('rak dengan tepi memudar & snap (${w.round()} dp)', (t) async {
      final app = await _state();
      await _pump(
        t,
        app,
        ListView(children: [
          Shelf(title: 'Rilis', children: [
            for (var i = 0; i < 8; i++) MediaCard(item: MediaItem(id: 'r$i', kind: 'release', title: 'Album $i', subtitle: 'Artis', href: '/app/album/r$i')),
          ]),
        ]),
        width: w,
      );
      await t.pumpAndSettle();
      final st = t.state<FadedEdgesState>(find.byType(FadedEdges).first);
      expect(st.showLeft, isFalse);
      expect(st.showRight, isTrue);
      await t.fling(find.text('Album 1'), const Offset(-300, 0), 1500);
      await t.pumpAndSettle();
      expect(st.showLeft, isTrue);
    });
  }

  // ── Tepi kontrol pemutar sejajar gutter isi (muka yang terlihat, bukan bayangan) ──
  for (final locale in ['id', 'en']) {
    for (final w in [360.0, 412.0]) {
      testWidgets('mini-player sejajar gutter ($locale, ${w.round()} dp)', (t) async {
        final app = await _state(locale);
        app.player.current = const Playable(id: 't1', kind: 'track', title: 'Lagu Uji Yang Cukup Panjang Sekali', subtitle: 'Senja Kolektif', durationMs: 180000);
        await _pump(t, app, const Column(mainAxisAlignment: MainAxisAlignment.end, children: [MiniPlayer()]), width: w);
        expect(t.getTopLeft(find.byKey(const Key('mini-cover'))).dx, closeTo(Rave.gutter, 1));
        expect(t.getTopRight(find.byKey(const Key('mini-last'))).dx, closeTo(w - Rave.gutter, 1));
        // Target sentuh tombol putar ≥ 48 dp.
        expect(t.getSize(find.byKey(const Key('mini-last'))).height, greaterThanOrEqualTo(Rave.tap));
      });

      testWidgets('Sedang Diputar: sampul, judul, progres & transport sejajar gutter ($locale, ${w.round()} dp)', (t) async {
        final app = await _state(locale);
        app.player.current = const Playable(id: 't1', kind: 'track', title: 'Lagu Uji', subtitle: 'Senja Kolektif', durationMs: 180000);
        await _pump(t, app, const NowPlayingScreen(), width: w, height: 860);
        final left = Rave.gutter, right = w - Rave.gutter;
        final art = find.byKey(const Key('np-art'));
        expect(t.getTopLeft(art).dx, closeTo(left, 1));
        expect(t.getTopRight(art).dx, closeTo(right, 1), reason: 'lebar karya = lebar isi');
        expect(t.getTopLeft(find.byKey(const Key('np-title'))).dx, closeTo(left, 1));
        // LCD selebar isi; spektrum memenuhi sisa lebar LCD (hingga bingkai + padding 10 dp di kanan).
        final lcd = find.byKey(const Key('np-lcd'));
        expect(t.getTopLeft(lcd).dx, closeTo(left, 1));
        expect(t.getTopRight(lcd).dx, closeTo(right, 1));
        expect(t.getTopRight(find.byKey(const Key('lcd-spectrum'))).dx, closeTo(right - 10, 1));
        final slider = find.byType(DeckSlider);
        expect(t.getTopLeft(slider).dx, closeTo(left, 1));
        expect(t.getTopRight(slider).dx, closeTo(right, 1));
        final keys = find.byType(DeckKey);
        expect(keys, findsNWidgets(5));
        // Tuts rapat dalam satu baki (seperti web): tepi BAKI tepat di gutter, tuts di dalamnya (bingkai 1 + padding 6).
        final tray = find.byKey(const Key('np-tray'));
        expect(t.getTopLeft(tray).dx, closeTo(left, 1));
        expect(t.getTopRight(tray).dx, closeTo(right, 1));
        expect(t.getTopLeft(keys.first).dx, closeTo(left + 7, 1));
        expect(t.getTopRight(find.byKey(const Key('np-last'))).dx, closeTo(right - 7, 1));
        // Celah antar-tuts seragam & rapat (4 dp).
        for (var i = 1; i < 5; i++) {
          expect(t.getTopLeft(keys.at(i)).dx - t.getTopRight(keys.at(i - 1)).dx, closeTo(4, 0.5));
        }
        // Semua tombol transport dipusatkan pada satu garis tengah & target sentuh ≥ 48 dp.
        final cy = t.getCenter(keys.first).dy;
        for (var i = 0; i < 5; i++) {
          expect(t.getCenter(keys.at(i)).dy, closeTo(cy, 0.5));
          expect(t.getSize(keys.at(i)).width, greaterThanOrEqualTo(Rave.tap));
          expect(t.getSize(keys.at(i)).height, greaterThanOrEqualTo(Rave.tap));
        }
      });
    }
  }

  // ── Copy EN tanpa overflow (360/412) ──
  for (final w in [360.0, 412.0]) {
    testWidgets('Settings (EN, Free, ${w.round()} dp) tanpa overflow', (t) async {
      final app = await _state('en');
      app.api.user = const Me(id: 'u1', email: 'fan@rave.id', displayName: 'Fan Rave');
      await _pump(t, app, const SettingsScreen(), width: w);
      await t.enterText(find.byType(TextField).first, 'volume');
      await t.pump();
      expect(find.text('Volume normalisation'), findsOneWidget);
    });

    testWidgets('Settings guest (EN, ${w.round()} dp)', (t) async {
      final app = await _state('en');
      await _pump(t, app, const SettingsScreen(), width: w);
      expect(find.text('SIGN IN TO SET UP RAVE'), findsOneWidget);
    });

    testWidgets('Collection guest + mini-player (EN, ${w.round()} dp)', (t) async {
      final app = await _state('en');
      app.player.current = const Playable(id: 't1', kind: 'track', title: 'A Fairly Long Song Title Here', subtitle: 'Senja Kolektif', durationMs: 180000);
      await _pump(t, app, const Column(children: [Expanded(child: LibraryScreen()), MiniPlayer()]), width: w);
      expect(find.textContaining('collection'), findsWidgets);
    });

    testWidgets('keadaan kosong + CTA (${w.round()} dp)', (t) async {
      final app = await _state();
      final s = app.s;
      var taps = 0;
      await _pump(t, app, ListView(children: [EmptyState(s.emptyPlaylist, body: s.emptyPlaylistBody, action: s.findMusic, onAction: () => taps++)]), width: w);
      expect(find.text('PLAYLIST INI MASIH KOSONG'), findsOneWidget);
      await t.tap(find.text('CARI MUSIK'));
      expect(taps, 1);
    });
  }
}
