import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _premium = Me(id: 'u2', email: 'premium@rave.id', displayName: 'Premium', premium: true);
const _free = Me(id: 'u1', email: 'free@rave.id', displayName: 'Gratis');
const _a = Playable(id: 'a', kind: 'track', title: 'A', subtitle: 'X', durationMs: 180000);
const _b = Playable(id: 'b', kind: 'track', title: 'B', subtitle: 'X', durationMs: 180000);
const _c = Playable(id: 'c', kind: 'track', title: 'C', subtitle: 'X', durationMs: 180000);

/// Pemutar dengan antrean [a, b, c] di item pertama; jeda iklan & pemuatan palsu mencatat status layanan saat itu.
Future<(Player, List<String>, List<String>, List<(bool, AudioProcessingState)>)> _player({Me? user = _premium}) async {
  SharedPreferences.setMockInitialValues({'locale': 'id'});
  final settings = await Settings.load();
  final p = Player(Api(settings)..user = user, settings)
    ..queue = [_a, _b, _c]
    ..index = 0
    ..current = _a;
  final ads = <String>[], loads = <String>[];
  final during = <(bool, AudioProcessingState)>[];
  p.debugAdBreak = (next) async {
    ads.add(next.id);
    during.add(p.debugServiceState);
  };
  p.debugLoad = (item) async {
    loads.add(item.id);
    during.add(p.debugServiceState);
  };
  return (p, ads, loads, during);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Lagu selesai → lanjut ke item berikutnya', () {
    test('Premium: langsung memuat item berikutnya', () async {
      final (p, ads, loads, _) = await _player();
      await p.debugCompleted();
      expect(loads, ['b']);
      expect(p.index, 1);
    });

    test('Gratis: jeda iklan lalu item berikutnya', () async {
      final (p, ads, loads, _) = await _player(user: _free);
      await p.debugCompleted();
      expect(ads, ['b']);
      expect(loads, ['b']);
      expect(p.index, 1);
    });

    test('repeat all di item terakhir → kembali ke awal', () async {
      final (p, _, loads, _) = await _player();
      p
        ..index = 2
        ..current = _c
        ..repeat = LoopMode.all;
      await p.debugCompleted();
      expect(loads, ['a']);
      expect(p.index, 0);
    });

    test('selama perpindahan, audio_service tetap "playing" & tidak pernah idle (layanan foreground dipertahankan)', () async {
      final (p, _, _, during) = await _player(user: _free);
      await p.debugCompleted();
      expect(during, hasLength(2));
      for (final (playing, ps) in during) {
        expect(playing, isTrue);
        expect(ps, isNot(AudioProcessingState.idle));
      }
      // Setelah selesai, penahan dilepas.
      expect(p.debugServiceState.$1, isFalse);
    });
  });

  group('Status yang diterbitkan ke audio_service', () {
    test('tanpa penahan: apa adanya', () {
      expect(Player.serviceState(PlayerState(false, ProcessingState.idle), hold: false), (false, AudioProcessingState.idle));
      expect(Player.serviceState(PlayerState(true, ProcessingState.ready), hold: false), (true, AudioProcessingState.ready));
      expect(Player.serviceState(PlayerState(false, ProcessingState.ready), hold: false), (false, AudioProcessingState.ready));
    });

    test('dengan penahan: idle/completed → loading, jeda → buffering, selalu playing', () {
      expect(Player.serviceState(PlayerState(false, ProcessingState.idle), hold: true), (true, AudioProcessingState.loading));
      expect(Player.serviceState(PlayerState(true, ProcessingState.completed), hold: true), (true, AudioProcessingState.loading));
      expect(Player.serviceState(PlayerState(false, ProcessingState.ready), hold: true), (true, AudioProcessingState.buffering));
      expect(Player.serviceState(PlayerState(true, ProcessingState.ready), hold: true), (true, AudioProcessingState.ready));
      expect(Player.serviceState(PlayerState(false, ProcessingState.loading), hold: true), (true, AudioProcessingState.loading));
    });
  });

  group('Fokus audio (pindah aplikasi, Reels, telepon)', () {
    FocusAction act(bool begin, AudioInterruptionType t, {bool playing = true, bool focusPaused = false}) =>
        Player.focusAction(begin: begin, type: t, playing: playing, focusPaused: focusPaused);

    test('hilang sementara → jeda tertahan, lalu lanjut saat fokus kembali', () {
      expect(act(true, AudioInterruptionType.pause), FocusAction.holdPause);
      expect(act(false, AudioInterruptionType.pause, playing: false, focusPaused: true), FocusAction.resume);
    });

    test('duck diabaikan (sistem menurunkan volume)', () {
      expect(act(true, AudioInterruptionType.duck), FocusAction.none);
      expect(act(false, AudioInterruptionType.duck), FocusAction.none);
    });

    test('hilang permanen → jeda biasa tanpa lanjut otomatis', () {
      expect(act(true, AudioInterruptionType.unknown), FocusAction.pause);
      expect(act(true, AudioInterruptionType.unknown, playing: false, focusPaused: true), FocusAction.pause);
      expect(act(false, AudioInterruptionType.unknown, playing: false, focusPaused: true), FocusAction.release);
    });

    test('sedang dijeda pendengar → gangguan tidak memicu putar ulang', () {
      expect(act(true, AudioInterruptionType.pause, playing: false), FocusAction.none);
      expect(act(false, AudioInterruptionType.pause, playing: false), FocusAction.none);
    });
  });
}
