import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import 'common.dart';
import 'feedback.dart';
import 'motion.dart';

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
    // Pita peringatan gelap (di atas mini-player) di kedua tema.
    return DarkZone(
      child: Material(
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
          FadedEdges(
            child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: Row(children: [
              TextButton(onPressed: _checking ? null : _check, child: Text(s.retry.toUpperCase(), style: Rave.label(size: 11, color: Rave.mustard))),
              for (final p in others)
                TextButton(
                  onPressed: () async {
                    final v = await probeServer(_app, p.$2);
                    if (!context.mounted) return;
                    if (v == null) return toast(context, s.serverUnreachable(p.$1), kind: ToastKind.error);
                    await switchServer(_app, p.$2);
                    if (context.mounted) toast(context, s.serverSaved, kind: ToastKind.ok);
                  },
                  child: Text(s.useServer(p.$1).toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)),
                ),
              TextButton(onPressed: () => showServerSheet(context), child: Text(s.server.toUpperCase(), style: Rave.label(size: 11, color: Rave.muted))),
            ]),
          ),
          ),
        ]),
      ),
      ),
    );
  }
}


/// Editor server (pilihan cepat + alamat + Uji/OK). Dipakai di Pengaturan (akun) dan lembar Server dari banner
/// koneksi — agar tamu tetap bisa memulihkan koneksi tanpa membuka Pengaturan.
class ServerEditor extends StatefulWidget {
  const ServerEditor({super.key, this.onSaved});
  final VoidCallback? onSaved;
  @override
  State<ServerEditor> createState() => _ServerEditorState();
}

class _ServerEditorState extends State<ServerEditor> {
  late final _server = TextEditingController(text: App.read(context).settings.server);
  String? _test;
  bool _testOk = false;

  @override
  void dispose() {
    _server.dispose();
    super.dispose();
  }

  Future<void> _testServer() async {
    final app = App.read(context);
    final u = Settings.normalize(_server.text);
    if (u == null) return setState(() => (_test = app.s.serverInvalid, _testOk = false));
    setState(() => (_test = '…', _testOk = true));
    final v = await probeServer(app, u);
    if (!mounted) return;
    setState(() => v == null ? (_test = app.s.offline, _testOk = false) : (_test = app.s.testOk(v), _testOk = true));
  }

  Future<void> _saveServer() async {
    final app = App.read(context);
    final u = Settings.normalize(_server.text);
    if (u == null) return setState(() => (_test = app.s.serverInvalid, _testOk = false));
    if (u == app.settings.server) return;
    await switchServer(app, u);
    if (!mounted) return;
    toast(context, app.s.serverSaved, kind: ToastKind.ok);
    widget.onSaved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      if (serverPresets.length > 1) ...[
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in serverPresets)
            OutlineButton(
              label: p.$1,
              active: _server.text == p.$2,
              onTap: () => setState(() {
                _server.text = p.$2;
                _test = null;
              }),
            ),
        ]),
        const SizedBox(height: 10),
      ],
      TextField(controller: _server, keyboardType: TextInputType.url, autocorrect: false, style: const TextStyle(fontFamily: Rave.mono, fontSize: 13)),
      const SizedBox(height: 10),
      Row(children: [
        OutlineButton(label: s.test, onTap: _testServer),
        const SizedBox(width: 8),
        OutlineButton(label: 'OK', onTap: _saveServer),
      ]),
      if (_test != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_test!, style: Rave.body(size: 13, color: _testOk ? context.rc.accent : Rave.berry))),
    ]);
  }
}

/// Lembar Server dari banner koneksi (juga untuk tamu).
Future<void> showServerSheet(BuildContext context) {
  final s = App.read(context).s;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(sheet).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.server.toUpperCase(), style: Rave.poster(28)),
        const SizedBox(height: 6),
        Text(s.serverHint, style: Rave.body(size: 13, color: sheet.rc.muted)),
        const SizedBox(height: 14),
        ServerEditor(onSaved: () => Navigator.pop(sheet)),
      ]),
    ),
  );
}
