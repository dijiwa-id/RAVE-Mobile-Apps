import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/api.dart';
import 'core/app_state.dart';
import 'core/appearance.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'player/player.dart';
import 'screens/intro.dart';
import 'widgets/motion.dart';

/// RAVE Mobile: langsung masuk ke pemutar sebagai tamu (pratinjau 30 dtk); Masuk/Daftar selalu tersedia.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Rave.canvas,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  final settings = await Settings.load();
  final api = Api(settings);
  await api.restore();
  final player = Player(api, settings);
  await player.init();
  final state = AppState(settings, api, player, Likes(api));
  runApp(RaveApp(state: state));
}

class RaveApp extends StatelessWidget {
  const RaveApp({super.key, required this.state});
  final AppState state;

  @override
  // Bahasa, status login & tema berubah → semua yang memakai App.of(context) dibangun ulang (teks, tombol, warna).
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([state.settings, state.api]),
        builder: (_, _) => App(
          state: state,
          child: MaterialApp(
            title: 'RAVE',
            debugShowCheckedModeBanner: false,
            theme: Rave.light,
            darkTheme: Rave.dark,
            // Akun → perangkat → default platform; "system" mengikuti kecerahan OS.
            themeMode: themeModeOf(state.themeChoice),
            locale: Locale(state.settings.locale),
            // Overscroll "kain ditarik" (regang) di semua platform, tanpa celah kosong di tepi.
            scrollBehavior: const RaveScrollBehavior(),
            // Ikon bilah status & navigasi mengikuti tema efektif (layar gelap memasang wilayahnya sendiri).
            builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
              value: Rave.overlayFor(Theme.of(context).brightness),
              child: child ?? const SizedBox.shrink(),
            ),
            home: const IntroGate(),
          ),
        ),
      );
}
