import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/appearance.dart';
import 'package:rave_mobile/core/i18n.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/audio_fx.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/screens/settings.dart';
import 'package:rave_mobile/widgets/common.dart';
import 'package:rave_mobile/widgets/cover_color.dart';
import 'package:rave_mobile/widgets/feedback.dart';
import 'package:rave_mobile/widgets/motion.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('konteks antrean (PlayFab aktif/jeda)', () {
    test('kunci koleksi = asal antrean', () {
      expect(Player.keyActive('release:1', 't9', 'release:1'), isTrue);
      expect(Player.keyActive('release:1', 't9', 'playlist:1'), isFalse);
      expect(Player.keyActive('liked', 't9', 'liked'), isTrue);
    });
    test('kunci lagu/episode = item yang dimuat (apa pun asal antreannya)', () {
      expect(Player.keyActive('track:t9', 't9', 'release:1'), isTrue);
      expect(Player.keyActive('episode:e1', 'e1', null), isTrue);
      expect(Player.keyActive('track:t1', 't9', null), isFalse);
    });
    test('tanpa lagu dimuat → tidak aktif', () {
      expect(Player.keyActive('release:1', null, 'release:1'), isFalse);
      expect(Player.keyActive(null, 't9', 'release:1'), isFalse);
    });
  });

  group('PlayFab', () {
    testWidgets('ikon Putar ↔ Jeda dan ketukan memanggil aksi', (t) async {
      var taps = 0;
      await t.pumpWidget(_wrap(PlayFab(playing: false, onPlay: () => taps++)));
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      await t.tap(find.byType(PlayFab));
      expect(taps, 1);
      await t.pumpWidget(_wrap(PlayFab(playing: true, onPlay: () => taps++)));
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });
  });

  group('pencarian pengaturan', () {
    test('cocok tanpa beda huruf, kueri kosong selalu cocok', () {
      expect(settingsMatch('', ['apa saja']), isTrue);
      expect(settingsMatch('flac', ['Kualitas', 'kbps FLAC lossless']), isTrue);
      expect(settingsMatch('bass', ['Bahasa', null]), isFalse);
    });

    testWidgets('baris tak cocok tidak dirender, bagian tanpa baris cocok disembunyikan', (t) async {
      Widget page(String q) => _wrap(ListView(children: [
            SettingsSection(title: 'Audio', icon: Icons.graphic_eq, query: q, rows: const [
              SettingsRow(label: 'Kualitas streaming', keywords: 'flac lossless'),
              SettingsRow(label: 'Normalisasi volume', keywords: 'loudness'),
            ]),
            SettingsSection(title: 'Bahasa', icon: Icons.language, query: q, rows: const [SettingsRow(label: 'Bahasa aplikasi')]),
          ]));
      await t.pumpWidget(page(''));
      expect(find.text('Kualitas streaming'), findsOneWidget);
      expect(find.text('BAHASA'), findsOneWidget);

      await t.pumpWidget(page('loud'));
      expect(find.text('Normalisasi volume'), findsOneWidget);
      expect(find.text('Kualitas streaming'), findsNothing);
      expect(find.text('BAHASA'), findsNothing);

      // Judul bagian cocok → semua barisnya tampil.
      await t.pumpWidget(page('audio'));
      expect(find.text('Kualitas streaming'), findsOneWidget);
      expect(find.text('Normalisasi volume'), findsOneWidget);
    });
  });

  group('kebijakan kualitas', () {
    test('bawaan: Gratis ≤ normal, Premium ≤ lossless 24/96', () {
      final p = QualityPolicy.fromSettings(const {});
      expect(p.options, ['auto', 'low', 'normal', 'high', 'lossless']);
      expect(p.locked('high', premium: false), isTrue);
      expect(p.locked('normal', premium: false), isFalse);
      expect(p.locked('auto', premium: false), isFalse);
      expect(p.locked('lossless', premium: true), isFalse);
      expect(p.losslessRes, '24-bit/96 kHz');
    });
    test('plafon Premium menyembunyikan opsi; lossless mati → maks high', () {
      final p = QualityPolicy.fromSettings(const {'streaming.lossless_enabled': false, 'streaming.free_max_quality': 'low', 'streaming.lossless_max_resolution': '16_44'});
      expect(p.options, ['auto', 'low', 'normal', 'high']);
      expect(p.clamp('lossless'), 'high');
      expect(p.locked('normal', premium: false), isTrue);
      expect(p.losslessRes, '16-bit/44.1 kHz');
    });
    test('label lossless menyebut plafon resolusi', () {
      expect(S.of('en').losslessCap('24-bit/96 kHz'), contains('FLAC up to 24-bit/96 kHz (Hi-Res)'));
      expect(S.of('id').losslessCap('16-bit/44.1 kHz'), startsWith('FLAC hingga 16-bit/44.1 kHz'));
    });
  });

  group('efek audio', () {
    test('normalisasi dibatasi −12…+6 dB; gain negatif → volume < 1', () {
      expect(normalizeGain(null), 0);
      expect(normalizeGain(-20), -12);
      expect(normalizeGain(9), 6);
      expect(volumeForGain(0), 1);
      expect(volumeForGain(4), 1);
      expect(volumeForGain(-6), closeTo(0.501, 0.001));
    });
    test('preset dipetakan ke pita perangkat & dibatasi rentang', () {
      // Pita khas Android 5-band.
      final bands = <double>[60, 230, 910, 3600, 14000];
      expect(mapCurve(eqPresets['flat']!, bands, -15, 15), everyElement(0));
      final bass = mapCurve(eqPresets['bass']!, bands, -15, 15);
      expect(bass.first, 6);
      expect(bass.last, 0);
      expect(mapCurve(eqPresets['bass']!, bands, -3, 3).first, 3);
    });
    test('galat pembuatan efek dikenali', () {
      expect(looksLikeFxError(Exception('java.lang.RuntimeException: Cannot initialize effect engine')), isTrue);
      expect(looksLikeFxError(Exception('Connection refused')), isFalse);
      expect(fmtHz(60), '60');
      expect(fmtHz(2400), '2.4K');
      expect(fmtHz(14000), '14K');
    });
  });

  test('warna dominan sampul: dibatasi agar teks tetap terbaca', () {
    // 4 piksel merah terang → hue merah, kecerahan dibatasi ≤ 30%.
    final red = dominantFromRgba([for (var i = 0; i < 4; i++) ...[230, 30, 30, 255]])!;
    final hsl = HSLColor.fromColor(red);
    expect(hsl.lightness, lessThanOrEqualTo(0.301));
    expect(hsl.saturation, lessThanOrEqualTo(0.621));
    expect(hsl.hue, anyOf(lessThan(5), greaterThan(355)));
    expect(dominantFromRgba(const []), isNull);
  });

  group('umpan balik', () {
    testWidgets('stiker toast tampil dengan kicker & aksi, lalu hilang sendiri', (t) async {
      var undone = false;
      await t.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () => showToast(context, 'Masuk ke Lagu yang Disukai', kind: ToastKind.ok, action: ToastAction('Urungkan', () => undone = true)),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('BERES!'), findsOneWidget);
      expect(find.text('Masuk ke Lagu yang Disukai'), findsOneWidget);
      await t.tap(find.text('URUNGKAN'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 300)); // animasi keluar
      expect(undone, isTrue);
      expect(find.text('BERES!'), findsNothing);

      await t.tap(find.text('go'));
      await t.pump(const Duration(milliseconds: 500));
      expect(find.text('BERES!'), findsOneWidget);
      await t.pump(const Duration(seconds: 7));
      await t.pump(const Duration(milliseconds: 300)); // animasi keluar
      expect(find.text('BERES!'), findsNothing);
    });

    testWidgets('dialog konfirmasi RAVE: Batal → false, aksi → true', (t) async {
      bool? result;
      await t.pumpWidget(_wrap(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirmDialog(context, title: 'Hapus playlist?', body: 'Tidak bisa dikembalikan.', confirmLabel: 'Hapus playlist', danger: true),
          child: const Text('go'),
        ),
      )));
      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      expect(find.text('KONFIRMASI'), findsOneWidget);
      expect(find.text('HAPUS PLAYLIST?'), findsOneWidget);
      await t.tap(find.text('Batal'));
      await t.pumpAndSettle();
      expect(result, isFalse);

      await t.tap(find.text('go'));
      await t.pumpAndSettle();
      await t.tap(find.text('Hapus playlist'));
      await t.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('resolusi tema', () {
    test('akun → perangkat → default platform', () {
      expect(resolveThemeChoice(account: 'light', device: 'dark', platformDefault: 'dark'), 'light');
      expect(resolveThemeChoice(account: null, device: 'system', platformDefault: 'dark'), 'system');
      expect(resolveThemeChoice(platformDefault: 'light'), 'light');
      expect(resolveThemeChoice(), 'dark');
    });
    test('allow_user_theme mati → selalu default platform', () {
      expect(resolveThemeChoice(account: 'light', device: 'light', platformDefault: 'dark', allowUser: false), 'dark');
      expect(resolveThemeChoice(account: 'dark', platformDefault: 'system', allowUser: false), 'system');
    });
    test('nilai tak dikenal diabaikan; mode Material', () {
      expect(resolveThemeChoice(account: 'neon', device: 'light'), 'light');
      expect(resolveThemeChoice(platformDefault: 'neon'), 'dark');
      expect(themeModeOf('system'), ThemeMode.system);
      expect(themeModeOf('light'), ThemeMode.light);
      expect(themeModeOf('dark'), ThemeMode.dark);
    });
  });

  testWidgets('tema terang: teks ink & aksen ungu; pulau gelap tetap terang', (t) async {
    late RaveColors outer, inner;
    late Color? outerText, innerText;
    await t.pumpWidget(MaterialApp(
      theme: Rave.light,
      home: Scaffold(
        body: Column(children: [
          Builder(builder: (c) {
            outer = c.rc;
            outerText = DefaultTextStyle.of(c).style.color;
            return const SizedBox();
          }),
          DarkZone(
            child: Builder(builder: (c) {
              inner = c.rc;
              innerText = DefaultTextStyle.of(c).style.color;
              return const SizedBox();
            }),
          ),
        ]),
      ),
    ));
    expect(outer.isLight, isTrue);
    expect(outer.accent, Rave.purple);
    expect(outerText, const Color(0xFF1B181D));
    expect(inner.isLight, isFalse);
    expect(innerText, Rave.paper);
    // Tema gelap tidak berubah: teks paper, aksen mustard.
    expect(RaveColors.dark.text, Rave.paper);
    expect(RaveColors.dark.accent, Rave.mustard);
  });

  test('akun Gratis: kualitas bawaan server (auto), pilihan Premium tersimpan direset', () async {
    SharedPreferences.setMockInitialValues({'quality': 'lossless'});
    final st = await Settings.load();
    expect(st.requestQualityFor(premium: false), 'auto');
    expect(st.requestQualityFor(premium: true), 'lossless');
    await st.enforceFreeQuality(premium: true);
    expect(st.quality, 'lossless');
    await st.enforceFreeQuality(premium: false);
    expect(st.quality, 'auto');
    await st.setDataSaver(true);
    expect(st.requestQualityFor(premium: false), 'low');
  });

  group('gerak', () {
    Widget strip(int n, {ScrollController? c}) => MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                height: 60,
                child: FadedEdges(
                  child: ListView(controller: c, scrollDirection: Axis.horizontal, children: [for (var i = 0; i < n; i++) const SizedBox(width: 100, height: 60)]),
                ),
              ),
            ),
          ),
        );

    testWidgets('tepi memudar: tanpa kiri di awal, kanan bila meluap, kiri di akhir', (t) async {
      final c = ScrollController();
      await t.pumpWidget(strip(10, c: c));
      await t.pumpAndSettle();
      var st = t.state<FadedEdgesState>(find.byType(FadedEdges));
      expect(st.showLeft, isFalse);
      expect(st.showRight, isTrue);
      c.jumpTo(c.position.maxScrollExtent);
      await t.pumpAndSettle();
      st = t.state<FadedEdgesState>(find.byType(FadedEdges));
      expect(st.showLeft, isTrue);
      expect(st.showRight, isFalse);
      c.jumpTo(150);
      await t.pumpAndSettle();
      expect(st.showLeft && st.showRight, isTrue);
      c.dispose();
    });

    testWidgets('tepi memudar: isi muat → tidak ada pudar', (t) async {
      await t.pumpWidget(strip(2));
      await t.pumpAndSettle();
      final st = t.state<FadedEdgesState>(find.byType(FadedEdges));
      expect(st.showLeft, isFalse);
      expect(st.showRight, isFalse);
    });

    test('snap: lemparan berhenti tepat di tepi kartu, dibatasi rentang', () {
      double snap(double px, double v) => SnapScrollPhysics.target(pixels: px, velocity: v, extent: 160, min: 0, max: 1000);
      expect(snap(70, 0), 0);
      expect(snap(90, 0), 160);
      final far = SnapScrollPhysics.target(pixels: 170, velocity: 3000, extent: 160, min: 0, max: 100000);
      expect(far % 160, 0);
      expect(far, greaterThan(170));
      expect(snap(900, 9000), 1000);
      expect(snap(300, -9000), 0);
    });

    testWidgets('kurangi gerakan → masuk bertahap & tekan langsung di keadaan akhir', (t) async {
      Entrance.reset();
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Column(children: const [
              Entrance(index: 3, id: 'uji-a', child: Text('halo')),
              Pressable(child: Text('tekan')),
              FadedEdges(child: SizedBox(height: 10)),
            ]),
          ),
        ),
      ));
      // Tanpa pump tambahan: tidak ada FadeTransition/AnimatedScale yang menunda tampilan.
      expect(find.text('halo'), findsOneWidget);
      expect(find.descendant(of: find.byType(Entrance), matching: find.byType(FadeTransition)), findsNothing);
      expect(find.ancestor(of: find.text('tekan'), matching: find.byType(AnimatedScale)), findsNothing);
    });

    testWidgets('masuk bertahap: animasi sekali per id, lalu tampil penuh', (t) async {
      Entrance.reset();
      await t.pumpWidget(const MaterialApp(home: Entrance(index: 2, id: 'uji-b', child: Text('baris'))));
      FadeTransition fade() => t.widget<FadeTransition>(find.descendant(of: find.byType(Entrance), matching: find.byType(FadeTransition)));
      expect(fade().opacity.value, 0);
      await t.pumpAndSettle();
      expect(fade().opacity.value, 1);
      // Dipasang ulang dengan id sama → tanpa animasi.
      await t.pumpWidget(const MaterialApp(home: SizedBox()));
      await t.pumpWidget(const MaterialApp(home: Entrance(index: 2, id: 'uji-b', child: Text('baris'))));
      expect(find.descendant(of: find.byType(Entrance), matching: find.byType(FadeTransition)), findsNothing);
    });
  });

  group('tarik-segarkan', () {
    Widget page(Future<void> Function() onRefresh, {bool reduce = false}) => MaterialApp(
          scrollBehavior: const RaveScrollBehavior(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce, size: const Size(400, 800)),
            child: Scaffold(
              body: RaveRefresh(
                onRefresh: onRefresh,
                child: ListView(physics: raveVerticalPhysics, children: [
                  Container(key: const Key('atas'), height: 120, color: Rave.purple),
                  for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('baris $i')),
                ]),
              ),
            ),
          ),
        );

    testWidgets('tarik di atas: isi meregang tanpa celah, ambang memicu tepat sekali', (t) async {
      var n = 0;
      final done = Completer<void>();
      await t.pumpWidget(page(() {
        n++;
        return done.future;
      }));
      final g = await t.startGesture(t.getCenter(find.text('baris 2')));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, 30));
        await t.pump(const Duration(milliseconds: 16));
      }
      // Tidak ada celah: posisi gulir tetap 0, bagian paling atas tetap menempel di tepi atas.
      final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(pos.pixels, 0);
      expect(t.getTopLeft(find.byKey(const Key('atas'))).dy, closeTo(0, 0.5));
      expect(find.byType(StretchingOverscrollIndicator), findsWidgets);
      expect(find.text('LEPAS UNTUK SEGARKAN'), findsOneWidget);
      await g.up();
      await t.pump(const Duration(milliseconds: 400));
      expect(n, 1);
      expect(t.state<RaveRefreshState>(find.byType(RaveRefresh)).refreshing, isTrue);
      expect(find.text('LAGI DISEGARKAN…'), findsOneWidget);
      // Tarikan lagi saat masih menyegarkan tidak memicu ulang.
      await t.drag(find.text('baris 2'), const Offset(0, 400));
      await t.pump(const Duration(milliseconds: 400));
      expect(n, 1);
      done.complete();
      await t.pumpAndSettle();
      expect(t.state<RaveRefreshState>(find.byType(RaveRefresh)).refreshing, isFalse);
      expect(find.text('LAGI DISEGARKAN…'), findsNothing);
      expect(n, 1);
    });

    testWidgets('header besar (CustomScrollView + SliverAppBar): tarik di atas tanpa celah', (t) async {
      await t.pumpWidget(MaterialApp(
        scrollBehavior: const RaveScrollBehavior(),
        home: Scaffold(
          body: RaveRefresh(
            onRefresh: () async {},
            child: CustomScrollView(physics: raveVerticalPhysics, slivers: [
              SliverAppBar(expandedHeight: 280, pinned: true, flexibleSpace: Container(key: const Key('hero'), color: Rave.purple)),
              SliverList.list(children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('baris $i'))]),
            ]),
          ),
        ),
      ));
      final g = await t.startGesture(t.getCenter(find.text('baris 1')));
      for (var i = 0; i < 10; i++) {
        await g.moveBy(const Offset(0, 25));
        await t.pump(const Duration(milliseconds: 16));
      }
      final pos = t.state<ScrollableState>(find.byType(Scrollable).first).position;
      expect(pos.pixels, 0);
      // Latar header tetap menempel di tepi atas (meregang, bukan bergeser turun menampakkan kanvas).
      expect(t.getTopLeft(find.byKey(const Key('hero'))).dy, lessThanOrEqualTo(0.5));
      await g.up();
      await t.pumpAndSettle();
    });

    testWidgets('RaveRefresh bersarang: satu indikator, tiap reload dipanggil tepat sekali', (t) async {
      var outer = 0, inner = 0;
      await t.pumpWidget(MaterialApp(
        scrollBehavior: const RaveScrollBehavior(),
        home: Scaffold(
          body: RaveRefresh(
            onRefresh: () async => outer++,
            child: RaveRefresh(
              onRefresh: () async => inner++,
              child: ListView(physics: raveVerticalPhysics, children: [for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('baris $i'))]),
            ),
          ),
        ),
      ));
      final g = await t.startGesture(t.getCenter(find.text('baris 2')));
      for (var i = 0; i < 12; i++) {
        await g.moveBy(const Offset(0, 30));
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(find.text('LEPAS UNTUK SEGARKAN'), findsOneWidget);
      await g.up();
      await t.pumpAndSettle();
      expect((outer, inner), (1, 1));
    });

    testWidgets('tarikan pendek tidak memicu & kembali rapi', (t) async {
      var n = 0;
      await t.pumpWidget(page(() async => n++));
      await t.drag(find.text('baris 2'), const Offset(0, 60));
      await t.pumpAndSettle();
      expect(n, 0);
      expect(t.state<RaveRefreshState>(find.byType(RaveRefresh)).pull, closeTo(0, 0.5));
    });

    testWidgets('kurangi gerakan: indikator statis, tetap memicu sekali', (t) async {
      var n = 0;
      await t.pumpWidget(page(() async => n++, reduce: true));
      await t.drag(find.text('baris 2'), const Offset(0, 420));
      await t.pump();
      await t.pumpAndSettle();
      expect(n, 1);
      expect(t.state<RaveRefreshState>(find.byType(RaveRefresh)).pull, 0);
    });
  });

  group('copy & galat ramah', () {
    test('friendlyError: offline, 4xx dari server, selain itu generik', () {
      final id = S.of('id'), en = S.of('en');
      expect(friendlyError(id, const OfflineError()), id.offline);
      expect(friendlyError(id, ApiError(422, 'Kode salah atau kedaluwarsa')), 'Kode salah atau kedaluwarsa');
      expect(friendlyError(id, ApiError(500, 'stack trace internal')), 'Waduh, ada yang error. Coba lagi ya.');
      expect(friendlyError(en, const FormatException('x')), 'Oops, something went wrong — try again?');
      expect(friendlyError(id, ApiError(404, 'HTTP 404')), id.genericError);
    });
    test('istilah inti setara web: Koleksi Kamu, tanpa "Pustaka"/"Anda"', () {
      final id = S.of('id'), en = S.of('en');
      expect(id.yourLibrary, 'Koleksi Kamu');
      expect(en.yourLibrary, 'Your Collection');
      expect(id.liked, 'Lagu yang Disukai');
      expect(id.nowPlaying, 'Sedang Diputar');
      for (final v in [id.library, id.savedToast, id.unsavedToast, id.deleteBody, id.compactRow, id.section('library'), id.gsStep('playlist').cta, id.deletePlaylistBody('X', 3)]) {
        expect(v.contains('Pustaka') || v.contains('pustaka') || v.contains('Anda'), isFalse, reason: v);
      }
      expect(id.deletePlaylistBody('Mix', 3), contains('3 lagu'));
      expect(en.deletePlaylistBody('Mix', 1), contains('1 song)'));
    });
  });
}
