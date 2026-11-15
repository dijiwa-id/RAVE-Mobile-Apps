import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/widgets/deck.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _free = Me(id: 'u1', email: 'free@rave.id', displayName: 'Gratis');
const _premium = Me(id: 'u2', email: 'premium@rave.id', displayName: 'Premium', premium: true);
const _track = Playable(id: 't1', kind: 'track', title: 'Lagu Uji', subtitle: 'Senja Kolektif', durationMs: 180000);

Future<(Player, List<Duration>)> _player({Map<String, Object> prefs = const {}, Me? user}) async {
  SharedPreferences.setMockInitialValues({'locale': 'id', ...prefs});
  final settings = await Settings.load();
  final api = Api(settings)..user = user;
  final p = Player(api, settings)..current = _track;
  final seeks = <Duration>[];
  p.debugSeek = (d) async => seeks.add(d);
  return (p, seeks);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Izin geser lagu (streaming.free_seek_enabled)', () {
    test('aturan: Premium selalu boleh; Gratis hanya bila platform mengizinkan', () {
      expect(Settings.seekAllowed(premium: true, freeSeek: false), isTrue);
      expect(Settings.seekAllowed(premium: false, freeSeek: false), isFalse);
      expect(Settings.seekAllowed(premium: false, freeSeek: true), isTrue);
    });

    test('Gratis tidak bisa seek lewat API pemutar', () async {
      final (p, seeks) = await _player(user: _free);
      expect(p.canSeek, isFalse);
      expect(await p.seek(const Duration(seconds: 42)), isFalse);
      expect(seeks, isEmpty);
    });

    test('tamu (belum masuk) diperlakukan sebagai Gratis', () async {
      final (p, seeks) = await _player();
      expect(p.canSeek, isFalse);
      expect(await p.seek(const Duration(seconds: 5)), isFalse);
      expect(seeks, isEmpty);
    });

    test('Premium bisa seek', () async {
      final (p, seeks) = await _player(user: _premium);
      expect(p.canSeek, isTrue);
      expect(await p.seek(const Duration(seconds: 42)), isTrue);
      expect(seeks, [const Duration(seconds: 42)]);
    });

    test('Gratis bisa seek bila platform mengaktifkan free_seek', () async {
      final (p, seeks) = await _player(user: _free, prefs: {'freeSeek': true});
      expect(p.canSeek, isTrue);
      expect(await p.seek(const Duration(seconds: 7)), isTrue);
      expect(seeks, [const Duration(seconds: 7)]);
    });

    test('flag tersimpan dari konfigurasi platform', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Settings.load();
      expect(st.freeSeek, isFalse, reason: 'tidak ada → false');
      await st.setFreeSeek(true);
      expect(st.freeSeek, isTrue);
    });
  });

  testWidgets('DeckSlider terkunci: progres tampil, geser tidak mengubah posisi & memicu info Premium', (t) async {
    var changed = 0, hinted = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: DeckSlider(value: 30, max: 100, locked: true, onChanged: (_) => changed++, onLocked: () => hinted++),
        ),
      ),
    ));
    await t.drag(find.byType(DeckSlider), const Offset(120, 0));
    await t.pump();
    await t.tap(find.byType(DeckSlider));
    await t.pump();
    expect(changed, 0);
    expect(hinted, 2);
  });

  _anonymousAdTests();
}

const _a = Playable(id: 'a', kind: 'track', title: 'A', subtitle: 'X', durationMs: 180000);
const _b = Playable(id: 'b', kind: 'track', title: 'B', subtitle: 'X', durationMs: 180000);
const _c = Playable(id: 'c', kind: 'track', title: 'C', subtitle: 'X', durationMs: 180000);
const _preview = PlaybackSession(sessionId: 's1', streamUrl: '/s', codecLabel: 'AAC', previewOnly: true, previewMs: 30000);

/// Pemutar tamu dengan antrean [a, b, c] di item pertama, sesi cuplikan, dan jeda iklan/pemuatan palsu.
Future<(Player, List<String>, List<String>)> _anon({Map<String, Object> prefs = const {}, void Function(Player)? duringAd}) async {
  SharedPreferences.setMockInitialValues({'locale': 'id', ...prefs});
  final settings = await Settings.load();
  final p = Player(Api(settings), settings)
    ..queue = [_a, _b, _c]
    ..index = 0
    ..current = _a
    ..session = _preview;
  final ads = <String>[], loads = <String>[];
  p.debugAdBreak = (next) async {
    ads.add(next.id);
    duringAd?.call(p);
  };
  p.debugLoad = (item) async => loads.add(item.id);
  return (p, ads, loads);
}

void _anonymousAdTests() {
  group('Iklan tamu di akhir cuplikan (ads.anonymous_enabled)', () {
    test('kelayakan jeda iklan: tamu on/off, Gratis selalu, Premium tidak pernah', () async {
      SharedPreferences.setMockInitialValues({});
      final st = await Settings.load();
      final api = Api(st);
      final p = Player(api, st);
      expect(st.adsAnonymous, isTrue, reason: 'bawaan true');
      expect(p.adBreakAllowed, isTrue);
      expect(p.anonymousAdsEligible, isTrue);
      await st.setAdsAnonymous(false);
      expect(p.adBreakAllowed, isFalse);
      expect(p.anonymousAdsEligible, isFalse);
      api.user = _free;
      expect(p.adBreakAllowed, isTrue);
      expect(p.anonymousAdsEligible, isFalse, reason: 'aturan cuplikan hanya untuk tamu');
      api.user = _premium;
      expect(p.adBreakAllowed, isFalse);
    });

    test('cuplikan selesai → satu jeda iklan lalu lanjut ke item berikutnya (sekali per item)', () async {
      final (p, ads, loads) = await _anon();
      final msgs = <String>[];
      final sub = p.messages.listen(msgs.add);
      p.debugPreviewReached();
      p.debugPreviewReached(); // tick posisi berikutnya: tidak memicu ulang
      await pumpEventQueue();
      expect(ads, ['b']);
      expect(loads, ['b']);
      expect(p.index, 1);
      expect(p.error, isNull, reason: 'lanjut memutar, bukan berhenti');
      expect(msgs, hasLength(1));
      await sub.cancel();
    });

    test('antrean diganti selama iklan → item pilihan baru yang dimuat', () async {
      final (p, ads, loads) = await _anon(duringAd: (p) {
        p.queue = [_c, _a];
        p.index = 0;
      });
      p.debugPreviewReached();
      await pumpEventQueue();
      expect(ads, ['b']);
      expect(loads, ['c']);
    });

    test('iklan tamu dimatikan → berhenti dengan pesan cuplikan selesai, tanpa iklan', () async {
      final (p, ads, loads) = await _anon(prefs: {'adsAnonymous': false});
      p.debugPreviewReached();
      await pumpEventQueue();
      expect(ads, isEmpty);
      expect(loads, isEmpty);
      expect(p.error, isNotNull);
      expect(p.index, 0);
    });

    test('item terakhir di antrean → berhenti seperti biasa', () async {
      final (p, ads, loads) = await _anon();
      p
        ..index = 2
        ..current = _c;
      p.debugPreviewReached();
      await pumpEventQueue();
      expect(ads, isEmpty);
      expect(loads, isEmpty);
      expect(p.error, isNotNull);
    });
  });

  group('Sebelumnya di item pertama', () {
    test('Gratis: tidak mengulang lagu (tanpa seek mundur)', () async {
      final (p, seeks) = await _player(user: _free);
      p
        ..queue = [_track]
        ..index = 0;
      await p.prev();
      expect(seeks, isEmpty);
      expect(p.index, 0);
    });

    test('Premium: mengulang dari awal', () async {
      final (p, seeks) = await _player(user: _premium);
      p
        ..queue = [_track]
        ..index = 0;
      await p.prev();
      expect(seeks, [Duration.zero]);
    });
  });
}
