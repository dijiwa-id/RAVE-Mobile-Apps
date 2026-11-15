import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/widgets/spectrum.dart';

/// Spektrum LCD yang mengikuti lagu (kontrak `GET /v1/catalog/tracks/:id/spectrum`).
void main() {
  SpectrumEnvelope env(List<int> bytes, {int bands = 1, double fps = 20}) =>
      SpectrumEnvelope(fps: fps, bands: bands, frames: bytes.length ~/ bands, durationMs: 0, data: Uint8List.fromList(bytes));

  group('amplop', () {
    test('jumlah bilah dari lebar: clamp(floor(w / 6), 16, 64)', () {
      expect(spectrumBars(60), 16);
      expect(spectrumBars(240), 40);
      expect(spectrumBars(245), 40);
      expect(spectrumBars(1000), 64);
    });

    test('pita di-resample ke jumlah bilah (interpolasi linear, ujung = pita terendah/tertinggi)', () {
      final e = env([0, 85, 170, 255], bands: 4);
      final out = List<double>.filled(7, -1);
      e.sample(0, out);
      for (var i = 0; i < 7; i++) {
        expect(out[i], closeTo(i / 6, 1e-9));
      }
      // Lebih sedikit bilah daripada pita: tetap mencakup seluruh rentang.
      final two = List<double>.filled(2, -1);
      e.sample(0, two);
      expect(two, [0.0, 1.0]);
    });

    test('indeks frame mengikuti posisi & diinterpolasi antar-frame', () {
      final e = env([0, 255, 0]); // 20 fps → frame tiap 50 ms
      expect(e.frameAt(0), 0);
      expect(e.frameAt(50), closeTo(1, 1e-9));
      expect(e.frameAt(99999), 2, reason: 'dijepit ke frame terakhir');
      final out = [0.0];
      e.sample(25, out);
      expect(out[0], closeTo(0.5, 1e-9));
      e.sample(50, out);
      expect(out[0], closeTo(1, 1e-9));
      e.sample(75, out);
      expect(out[0], closeTo(0.5, 1e-9));
    });

    test('JSON base64 → amplop; bentuk rusak → null (tak melempar)', () {
      final ok = SpectrumEnvelope.tryParse({'fps': 20, 'bands': 2, 'frames': 2, 'duration_ms': 100, 'data': base64Encode([1, 2, 3, 4])});
      expect(ok!.frames, 2);
      expect(ok.data, [1, 2, 3, 4]);
      expect(SpectrumEnvelope.tryParse({'fps': 20, 'bands': 2, 'data': 'bukan base64!!'}), isNull);
      expect(SpectrumEnvelope.tryParse({'status': 'pending'}), isNull);
      expect(SpectrumEnvelope.tryParse(null), isNull);
    });
  });

  group('mesin bilah', () {
    test('jeda → bilah turun ke lantai, topi puncak ikut jatuh, lalu diam', () {
      final m = SpectrumEngine()..resize(8);
      for (var i = 0; i < 30; i++) {
        m.step(16, List.filled(8, 1.0));
      }
      expect(m.levels.every((v) => v > 0.95), isTrue);
      expect(m.settled, isFalse);
      m.step(16, null);
      expect(m.levels.first, lessThan(1), reason: 'turun bertahap, bukan seketika');
      expect(m.levels.first, greaterThan(0.5));
      for (var i = 0; i < 300; i++) {
        m.step(16, null);
      }
      expect(m.settled, isTrue);
      expect(m.peaks.every((p) => p <= SpectrumEngine.idle + 0.004), isTrue);
    });

    test('topi puncak bertahan sebentar lalu jatuh pelan', () {
      final m = SpectrumEngine()..resize(1);
      m.step(16, [1.0], snap: true);
      m.step(16, [0.0], snap: true);
      expect(m.peaks.first, SpectrumEngine.idle, reason: 'seek → topi ikut melompat');
      for (var i = 0; i < 20; i++) {
        m.step(16, [1.0]);
      }
      m.step(100, [0.1]);
      expect(m.peaks.first, greaterThan(0.9), reason: 'tahan puncak');
      for (var i = 0; i < 100; i++) {
        m.step(16, [0.1]);
      }
      expect(m.peaks.first, closeTo(m.levels.first, 0.01));
    });

    test('seek → lompat langsung tanpa smoothing', () {
      final m = SpectrumEngine()..resize(4);
      m.step(16, [0.9, 0.9, 0.9, 0.9], snap: true);
      expect(m.levels, everyElement(closeTo(0.9, 1e-9)));
    });
  });

  group('repo', () {
    test('404 disimpan sebagai tidak ada; galat jaringan tidak disimpan; LRU', () async {
      var calls = 0;
      final r = SpectrumRepo((id) async {
        calls++;
        if (id == 'gone') throw ApiError(404, 'not_found');
        if (id == 'off') throw const OfflineError();
        return {'fps': 20, 'bands': 1, 'frames': 1, 'data': base64Encode([9])};
      }, capacity: 2);
      expect((await r.load('gone')).status, SpectrumStatus.missing);
      expect((await r.load('gone')).status, SpectrumStatus.missing);
      expect((await r.load('off')).status, SpectrumStatus.error);
      expect((await r.load('off')).status, SpectrumStatus.error);
      expect(calls, 3);
      expect((await r.load('a')).envelope!.data, [9]);
      await r.load('b');
      expect(r.peek('gone'), isNull, reason: 'terlama dibuang (kapasitas 2)');
      expect(r.peek('a'), isNotNull);
    });

    test('202 → coba ulang maks 2× per lagu', () async {
      final r = SpectrumRepo((_) async => {'status': 'pending'});
      expect((await r.load('x')).status, SpectrumStatus.pending);
      expect(r.takeRetry('x'), isTrue);
      expect(r.takeRetry('x'), isTrue);
      expect(r.takeRetry('x'), isFalse);
    });
  });

  group('widget', () {
    Widget host(Widget child, {bool reduce = false}) => MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduce),
            child: Scaffold(body: Center(child: SizedBox(width: 240, child: child))),
          ),
        );
    DeckSpectrumState st(WidgetTester t) => t.state<DeckSpectrumState>(find.byType(DeckSpectrum));

    testWidgets('fetch gagal → dekoratif selebar penuh, beranimasi saat diputar, berhenti saat dijeda', (t) async {
      final repo = SpectrumRepo((_) async => throw const OfflineError());
      await t.pumpWidget(host(DeckSpectrum(trackId: 't1', playing: true, repo: repo, position: () => Duration.zero)));
      await t.pump(const Duration(milliseconds: 100));
      final s = st(t);
      expect(s.envelope, isNull);
      expect(s.engine.bars, 40);
      expect(t.getSize(find.byKey(const Key('lcd-spectrum'))).width, 240);
      expect(s.animating, isTrue);
      expect(s.engine.levels.any((v) => v > 0.2), isTrue);

      await t.pumpWidget(host(DeckSpectrum(trackId: 't1', playing: false, repo: repo, position: () => Duration.zero)));
      for (var i = 0; i < 200; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      expect(s.engine.settled, isTrue);
      expect(s.animating, isFalse, reason: 'ticker berhenti setelah bilah turun');
    });

    testWidgets('dengan amplop: bilah mengikuti frame pada posisi, seek melompat', (t) async {
      // 2 pita, 3 frame: diam · penuh · diam.
      final data = base64Encode([0, 0, 255, 255, 0, 0]);
      final repo = SpectrumRepo((_) async => {'fps': 20, 'bands': 2, 'frames': 3, 'duration_ms': 150, 'data': data});
      var pos = 50;
      await t.pumpWidget(host(DeckSpectrum(trackId: 't1', playing: true, repo: repo, position: () => Duration(milliseconds: pos))));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 16));
      }
      final s = st(t);
      expect(s.envelope, isNotNull);
      expect(s.engine.levels, everyElement(greaterThan(0.95)));
      pos = 100000; // seek jauh → frame terakhir (diam), langsung tanpa release
      await t.pump(const Duration(milliseconds: 16));
      expect(s.engine.levels, everyElement(closeTo(SpectrumEngine.idle, 1e-9)));
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('respons basi setelah ganti lagu diabaikan', (t) async {
      final gate = Completer<Object?>();
      final repo = SpectrumRepo((id) => id == 'old' ? gate.future : Future.error(const OfflineError()));
      await t.pumpWidget(host(DeckSpectrum(trackId: 'old', playing: false, repo: repo)));
      await t.pumpWidget(host(DeckSpectrum(trackId: 'new', playing: false, repo: repo)));
      gate.complete({'fps': 20, 'bands': 1, 'frames': 1, 'data': base64Encode([200])});
      await t.pump();
      expect(st(t).envelope, isNull);
    });

    testWidgets('202 → dekoratif, coba ulang setelah 30 dtk', (t) async {
      var calls = 0;
      final repo = SpectrumRepo((_) async {
        calls++;
        return calls < 2 ? {'status': 'pending'} : {'fps': 20, 'bands': 1, 'frames': 1, 'data': base64Encode([255])};
      });
      await t.pumpWidget(host(DeckSpectrum(trackId: 't1', playing: false, repo: repo)));
      await t.pump();
      expect(st(t).envelope, isNull);
      await t.pump(SpectrumRepo.retryAfter);
      await t.pump();
      expect(calls, 2);
      expect(st(t).envelope, isNotNull);
    });

    testWidgets('gerak dikurangi: tanpa ticker & topi puncak, bilah statis dari frame saat ini', (t) async {
      final repo = SpectrumRepo((_) async => {'fps': 20, 'bands': 1, 'frames': 2, 'data': base64Encode([128, 128])});
      await t.pumpWidget(host(DeckSpectrum(trackId: 't1', playing: true, repo: repo, position: () => Duration.zero), reduce: true));
      await t.pump();
      final s = st(t);
      expect(s.envelope, isNotNull);
      expect(s.animating, isFalse);
      expect(s.engine.caps, isFalse);
      expect(s.engine.levels, everyElement(closeTo(128 / 255, 1e-9)));
      await t.pumpWidget(const SizedBox()); // lepas → timer 4×/dtk dibatalkan
    });

    testWidgets('gerak dikurangi tanpa amplop: bilah dekoratif statis', (t) async {
      await t.pumpWidget(host(const DeckSpectrum(playing: true), reduce: true));
      final s = st(t);
      final before = List.of(s.engine.levels);
      await t.pump(const Duration(seconds: 1));
      expect(s.animating, isFalse);
      expect(s.engine.levels, before);
      expect(before.any((v) => v > SpectrumEngine.idle), isTrue);
    });
  });
}
