import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../screens/routes.dart';
import 'common.dart';

/// Ganti server dengan aman: server lain = akun & data lain → event putar dikirim dulu, sesi ditutup, cache dibuang
/// (token tidak boleh terkirim ke server yang salah).
Future<void> switchServer(AppState app, String url) async {
  if (url == app.settings.server) return;
  await app.player.flush();
  await app.player.reset();
  if (app.api.authed) await app.api.logout();
  app.likes.reset();
  app.cache.clear();
  await app.settings.setServer(url);
}

/// Uji satu alamat server tanpa mengubah pengaturan (GET /v1/version, batas 6 dtk).
Future<String?> probeServer(AppState app, String url) async {
  try {
    final j = await app.api.request<Map<String, dynamic>>('/v1/version', server: url, timeout: const Duration(seconds: 6));
    return '${j['version']}';
  } catch (_) {
    return null;
  }
}

/// Banner koneksi di atas mini-player: memeriksa server saat start, saat server diganti, dan saat aplikasi kembali
/// aktif. Bila gagal, mencoba ulang dengan jeda bertahap (5→60 dtk) dan menawarkan server lain dari preset.
/// Saat terhubung banner tidak menggambar apa pun — tidak ada polling selama sehat.
class ConnectionBanner extends StatefulWidget {
  const ConnectionBanner({super.key});
  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  bool _down = false;
  bool _checking = false;
  int _fails = 0;
  Timer? _retry;
  String? _server;
  late final AppLifecycleListener _life;
  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = App.read(context);
    _server = _app.settings.server;
    _app.settings.addListener(_onSettings);
    _life = AppLifecycleListener(onResume: () {
      if (_down) _check();
    });
    _check();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _life.dispose();
    _app.settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (_app.settings.server == _server) return;
    _server = _app.settings.server;
    _fails = 0;
    _check();
  }

  Future<void> _check() async {
    if (_checking) return;
    _retry?.cancel();
    setState(() => _checking = true);
    bool ok;
    try {
      await _app.api.request<dynamic>('/v1/version', auth: false, timeout: const Duration(seconds: 6));
      ok = true;
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    final wasDown = _down;
    setState(() {
      _checking = false;
      _down = !ok;
    });
    if (ok) {
      _fails = 0;
      if (wasDown) _app.cache.clear(); // muat ulang layar yang tadi gagal
      return;
    }
    _fails++;
    _retry = Timer(Duration(seconds: (5 * (1 << (_fails - 1).clamp(0, 4))).clamp(5, 60)), _check);
  }

  @override
  Widget build(BuildContext context) {
    if (!_down) return const SizedBox.shrink();
    final s = _app.s;
    final current = _app.settings.server;
    final others = serverPresets.where((p) => p.$2 != current).toList();
    return Material(
      color: const Color(0xFF2A1416),
      child: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Rave.berry, width: 2))),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.cloud_off_rounded, size: 18, color: Rave.berry),
            const SizedBox(width: 8),
            Expanded(
              child: Text(s.serverDown, style: Rave.body(size: 13, weight: FontWeight.w700)),
            ),
            if (_checking) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Rave.mustard)),
          ]),
          Padding(
            padding: const EdgeInsets.only(left: 26, top: 2),
            child: Text(current, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: Rave.mono, fontSize: 11.5, color: Rave.muted)),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              TextButton(onPressed: _checking ? null : _check, child: Text(s.retry.toUpperCase(), style: Rave.label(size: 11, color: Rave.mustard))),
              for (final p in others)
                TextButton(
                  onPressed: () async {
                    final v = await probeServer(_app, p.$2);
                    if (!context.mounted) return;
                    if (v == null) return toast(context, s.serverUnreachable(p.$1));
                    await switchServer(_app, p.$2);
                    if (context.mounted) toast(context, s.serverSaved);
                  },
                  child: Text(s.useServer(p.$1).toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)),
                ),
              TextButton(onPressed: () => openItem(context, 'settings', ''), child: Text(s.settings.toUpperCase(), style: Rave.label(size: 11, color: Rave.muted))),
            ]),
          ),
        ]),
      ),
    );
  }
}
