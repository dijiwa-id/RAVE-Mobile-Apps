import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/widgets/deck.dart';

/// Tuts deck bergaya tape deck vintage: muka turun saat ditekan, kembali dengan pegas, toggle aktif terkunci setengah.
void main() {
  Widget host(Widget child, {bool reduce = false}) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(body: Center(child: child)),
        ),
      );
  double iconY(WidgetTester t) => t.getCenter(find.byType(Icon)).dy;

  testWidgets('tekan → muka turun penuh; lepas → kembali ke posisi diam', (t) async {
    var taps = 0;
    await t.pumpWidget(host(DeckKey(semantic: 'Putar', play: true, width: 64, height: 52, onTap: () => taps++, child: const Icon(Icons.play_arrow))));
    final rest = iconY(t);
    final g = await t.startGesture(t.getCenter(find.byType(DeckKey)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    expect(iconY(t) - rest, closeTo(DeckKey.travel, 0.2), reason: 'muka turun sejauh travel, langsung saat disentuh');
    await g.up();
    await t.pumpAndSettle();
    expect(iconY(t), closeTo(rest, 0.01));
    expect(taps, 1);
  });

  testWidgets('tekanan kilat tetap terlihat turun sebelum kembali (tanpa ketukan ganda)', (t) async {
    var taps = 0;
    await t.pumpWidget(host(DeckKey(semantic: 'Lanjut', width: 60, height: 50, onTap: () => taps++, child: const Icon(Icons.skip_next))));
    final rest = iconY(t);
    await t.tap(find.byType(DeckKey));
    await t.pump();
    await t.pump(const Duration(milliseconds: 40));
    expect(iconY(t), greaterThan(rest + 1));
    await t.pumpAndSettle();
    expect(iconY(t), closeTo(rest, 0.01));
    expect(taps, 1);
  });

  testWidgets('toggle aktif terkunci setengah turun; nonaktif naik lagi', (t) async {
    Widget key(bool on) => host(DeckKey(semantic: 'Acak', toggle: true, active: on, width: 52, height: 40, onTap: () {}, child: const Icon(Icons.shuffle)));
    await t.pumpWidget(key(false));
    final rest = iconY(t);
    await t.pumpWidget(key(true));
    await t.pumpAndSettle();
    expect(iconY(t) - rest, closeTo(DeckKey.travel * DeckKey.latched, 0.2));
    await t.pumpWidget(key(false));
    await t.pumpAndSettle();
    expect(iconY(t), closeTo(rest, 0.01));
  });

  testWidgets('gerak dikurangi → langsung tanpa animasi', (t) async {
    await t.pumpWidget(host(DeckKey(semantic: 'Putar', width: 60, height: 50, onTap: () {}, child: const Icon(Icons.play_arrow)), reduce: true));
    final rest = iconY(t);
    final g = await t.startGesture(t.getCenter(find.byType(DeckKey)));
    await t.pump();
    expect(iconY(t) - rest, closeTo(DeckKey.travel, 0.01));
    await g.up();
    await t.pump();
    expect(iconY(t), closeTo(rest, 0.01));
  });
}
