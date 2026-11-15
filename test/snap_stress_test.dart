import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/widgets/motion.dart';

/// Simulasi balistik berantai (seperti BallisticScrollActivity → goBallistic(0) saat selesai) harus berhenti
/// dalam beberapa langkah untuk semua posisi/kecepatan — rantai tak berujung = layar macet (ANR) saat geser rak.
void main() {
  test('SnapScrollPhysics: rantai simulasi selalu berhenti (dpr 2.625, max bukan kelipatan extent)', () {
    const dpr = 2.625;
    for (final extent in [146.0, 160.0, 174.0, 274.0]) {
      for (final max in [0.0, 37.0, 500.3, 1234.5, 2000.0]) {
        final physics = SnapScrollPhysics(extent: extent, parent: const ClampingScrollPhysics());
        for (var px = -5.0; px <= max + 5; px += 7.3) {
          for (final v in [-8000.0, -2500.0, -300.0, -0.5, 0.0, 0.5, 300.0, 2500.0, 8000.0]) {
            var pos = px, vel = v, steps = 0;
            while (true) {
              final m = FixedScrollMetrics(minScrollExtent: 0, maxScrollExtent: max, pixels: pos, viewportDimension: 360, axisDirection: AxisDirection.right, devicePixelRatio: dpr);
              final sim = physics.createBallisticSimulation(m, vel);
              if (sim == null) break;
              var t = 0.0;
              while (!sim.isDone(t) && t < 30) {
                t += 1 / 60;
              }
              expect(t < 30, isTrue, reason: 'simulasi tak selesai: extent=$extent max=$max px=$px v=$v');
              pos = sim.x(t);
              vel = 0;
              steps++;
              expect(steps < 6, isTrue, reason: 'rantai balistik tak berujung: extent=$extent max=$max px=$px v=$v pos=$pos');
              if (steps >= 6) break;
            }
          }
        }
      }
    }
  });
}
