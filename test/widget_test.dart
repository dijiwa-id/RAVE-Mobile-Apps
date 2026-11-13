import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/i18n.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/widgets/common.dart';

void main() {
  test('normalisasi alamat server', () {
    expect(Settings.normalize('https://rave.id/'), 'https://rave.id');
    expect(Settings.normalize('http://10.0.2.2:8088/v1'), 'http://10.0.2.2:8088');
    expect(Settings.normalize('ftp://rave.id'), isNull);
    expect(Settings.normalize('bukan url'), isNull);
  });

  test('format durasi', () {
    expect(fmtDuration(65000), '1:05');
    expect(fmtDuration(3725000), '1:02:05');
  });

  test('i18n jamak/tunggal', () {
    expect(S.of('en').songs(1), '1 song');
    expect(S.of('en').songs(3), '3 songs');
    expect(S.of('id').songs(1), '1 lagu');
  });

  test('href kartu → id target (slug artis)', () {
    const m = MediaItem(id: 'uuid', kind: 'artist', title: 'Senja', subtitle: '', href: '/app/artist/senja-kolektif');
    expect(m.targetId, 'senja-kolektif');
  });

  group('DataCache', () {
    test('selesai (regresi: dulu macet selamanya karena whenComplete menunggu dirinya)', () async {
      final c = DataCache();
      final v = await c.load('k', () async => 'isi').timeout(const Duration(seconds: 2));
      expect(v, 'isi');
      expect(c.peek('k'), 'isi');
    });

    test('dedup permintaan berjalan & galat bisa dicoba ulang', () async {
      final c = DataCache();
      var n = 0;
      Future<Object> boom() async {
        n++;
        throw StateError('x');
      }
      final a = c.load('k', boom);
      final b = c.load('k', boom);
      expect(identical(a, b), isTrue);
      await expectLater(a, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(await c.load('k', () async => 'ok').timeout(const Duration(seconds: 2)), 'ok');
      expect(n, 1);
    });

    test('invalidate saat berjalan: jawaban lama tidak masuk cache', () async {
      final c = DataCache();
      final f = c.load('/v1/x', () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'lama';
      });
      c.invalidate('/v1/');
      expect(await f, 'lama');
      expect(c.peek('/v1/x'), isNull);
    });
  });
}
