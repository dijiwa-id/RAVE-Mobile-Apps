import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/api.dart';
import 'core/app_state.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'player/player.dart';
import 'screens/intro.dart';

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
  // Bahasa & status login berubah → semua yang memakai App.of(context) dibangun ulang (teks, tombol tamu/akun).
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([state.settings, state.api]),
        builder: (_, _) => App(
          state: state,
          child: MaterialApp(
            title: 'RAVE',
            debugShowCheckedModeBanner: false,
            theme: Rave.theme(),
            locale: Locale(state.settings.locale),
            home: const IntroGate(),
          ),
        ),
      );
}
