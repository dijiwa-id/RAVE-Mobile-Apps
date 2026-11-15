import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/screens/shell.dart';
import 'package:rave_mobile/widgets/motion.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regresi ANR: gestur kembali (tepi layar) di akar Beranda dulu memanggil maybePop() pada route shell yang ber-
/// PopScope(canPop:false) → handler dipanggil ulang tanpa henti dan main thread macet. Kini keluar lewat SystemNavigator.
void main() {
  testWidgets('kembali di akar Beranda keluar ke launcher, tidak berputar tanpa henti', (t) async {
    RaveMotion.infinite = false;
    SharedPreferences.setMockInitialValues({'locale': 'id'});
    final settings = await Settings.load();
    final api = Api(settings);
    final app = AppState(settings, api, Player(api, settings), Likes(api));

    var exits = 0;
    t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    t.view.physicalSize = const Size(1080, 2400);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(App(state: app, child: MaterialApp(theme: Rave.dark, home: const Shell())));
    await t.pump(const Duration(milliseconds: 300));

    // Tombol/gestur kembali sistem → WidgetsBinding.handlePopRoute (jalur yang sama dengan Android).
    await t.binding.handlePopRoute();
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(exits, 1, reason: 'harus keluar tepat sekali (bukan loop maybePop)');
  });
}
