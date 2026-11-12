import 'package:flutter_test/flutter_test.dart';
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
}
