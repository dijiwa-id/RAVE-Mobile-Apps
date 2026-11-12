import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/mini_player.dart';
import 'home.dart';
import 'library.dart';
import 'routes.dart';
import 'search.dart';

_ShellState? _shell;

/// Buka halaman di navigator tab yang sedang tampil (dipakai dari luar tab, mis. pemutar layar penuh).
void openInActiveTab(String kind, String id) {
  final ctx = _shell?._navs[_shell!.tab].currentContext;
  if (ctx != null) openItem(ctx, kind, id);
}

/// Kerangka utama: 3 tab (Beranda/Cari/Pustaka), masing-masing punya navigator & riwayat sendiri;
/// mini-player selalu terlihat di atas tab bar. Tombol kembali Android menutup halaman di tab dulu.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;
  final _navs = List.generate(3, (_) => GlobalKey<NavigatorState>());
  StreamSubscription<String>? _msgs;

  @override
  void initState() {
    super.initState();
    _shell = this;
    final app = App.read(context);
    // Profil terbaru (status Premium dsb.).
    if (app.api.authed) app.api.get('/v1/me').then((j) => app.api.setUser(Me.fromJson(j))).catchError((_) {});
    _msgs = app.player.messages.listen((m) {
      if (mounted) toast(context, m);
    });
  }

  @override
  void dispose() {
    if (_shell == this) _shell = null;
    _msgs?.cancel();
    super.dispose();
  }

  void _select(int i) {
    if (i == tab) {
      // Ketuk tab aktif lagi → kembali ke akar tab itu.
      _navs[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final roots = [const HomeScreen(), const SearchScreen(), const LibraryScreen()];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navs[tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (tab != 0) {
          setState(() => tab = 0);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab,
          children: [
            for (var i = 0; i < 3; i++)
              Navigator(
                key: _navs[i],
                onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => roots[i]),
              ),
          ],
        ),
        bottomNavigationBar: Column(mainAxisSize: MainAxisSize.min, children: [
          const MiniPlayer(),
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xE60E0C0F), Rave.canvas]),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: Colors.transparent,
                labelTextStyle: WidgetStateProperty.resolveWith((st) => Rave.body(size: 11, weight: FontWeight.w700, color: st.contains(WidgetState.selected) ? Rave.paper : Rave.subtle)),
                iconTheme: WidgetStateProperty.resolveWith((st) => IconThemeData(color: st.contains(WidgetState.selected) ? Rave.mustard : Rave.subtle, size: 26)),
              ),
              child: NavigationBar(
                height: 64,
                selectedIndex: tab,
                onDestinationSelected: _select,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home_rounded), label: s.home),
                  NavigationDestination(icon: const Icon(Icons.search_rounded), selectedIcon: const Icon(Icons.manage_search_rounded), label: s.search),
                  NavigationDestination(icon: const Icon(Icons.library_music_outlined), selectedIcon: const Icon(Icons.library_music_rounded), label: s.library),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
