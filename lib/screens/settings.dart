import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'login.dart';
import '../widgets/links.dart';
import '../core/version.dart';


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
    try {
      final old = app.settings.server;
      await app.settings.setServer(u);
      final j = await app.api.request<Map<String, dynamic>>('/v1/version', auth: false, timeout: const Duration(seconds: 6));
      if (u != old) await app.settings.setServer(old);
      setState(() => (_test = app.s.testOk('${j['version']}'), _testOk = true));
    } catch (_) {
      setState(() => (_test = app.s.offline, _testOk = false));
    }
  }

  Future<void> _saveServer() async {
    final app = App.read(context);
    final u = Settings.normalize(_server.text);
    if (u == null) return setState(() => (_test = app.s.serverInvalid, _testOk = false));
    if (u == app.settings.server) return;
    // Server lain = akun & data lain → keluar dulu agar token tidak terkirim ke server yang salah.
    if (app.api.authed) await _logout();
    await app.settings.setServer(u);
    app.cache.clear();
    if (mounted) toast(context, app.s.serverSaved);
  }

  Future<void> _logout() async {
    final app = App.read(context);
    await app.player.flush();
    await app.player.reset();
    await app.api.logout();
    app.likes.reset();
    app.cache.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.api]),
      builder: (context, _) {
        final u = app.api.user;
        return Scaffold(
          appBar: AppBar(title: Text(s.settings.toUpperCase(), style: Rave.poster(26))),
          body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
            _Section(s.account, children: [
              if (u != null)
                Row(children: [
                  Cover(u.avatarUrl, size: 48, round: true),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u.displayName, style: Rave.body(size: 16, weight: FontWeight.w700)),
                      Text('${u.email} · ${u.premium ? s.premiumActive : s.free}', style: Rave.body(size: 13, color: Rave.muted)),
                    ]),
                  ),
                  OutlineButton(label: s.logout, onTap: _logout),
                ])
              else ...[
                Text(s.guestBody, style: Rave.body(color: Rave.muted)),
                const SizedBox(height: 14),
                PrimaryButton(label: s.signup, onTap: () => openLogin(context, signup: true)),
                const SizedBox(height: 10),
                OutlineButton(label: s.signIn, onTap: () => openLogin(context)),
              ],
            ]),
            _Section(s.language, children: [
              Wrap(spacing: 8, children: [
                for (final (k, label) in [('id', 'Bahasa Indonesia'), ('en', 'English')])
                  ChoiceChip(
                    label: Text(label, style: Rave.body(weight: FontWeight.w700, color: app.settings.locale == k ? Rave.ink : Rave.paper)),
                    selected: app.settings.locale == k,
                    showCheckmark: false,
                    selectedColor: Rave.paper,
                    backgroundColor: Rave.raised,
                    shape: const RoundedRectangleBorder(),
                    side: BorderSide.none,
                    onSelected: (_) => app.settings.setLocale(k),
                  ),
              ]),
            ]),
            _Section(s.quality, hint: s.qualityHint, children: [
              for (final q in ['auto', 'low', 'normal', 'high', 'lossless'])
                Builder(builder: (_) {
                  final locked = !(u?.premium ?? false) && (q == 'high' || q == 'lossless');
                  final on = app.settings.quality == q;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    enabled: !locked,
                    onTap: () => app.settings.setQuality(q),
                    leading: Icon(on ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: on ? Rave.mustard : Rave.subtle),
                    title: Text('${s.q(q)}${locked ? ' · ${s.premium}' : ''}', style: Rave.body(size: 14.5, color: locked ? Rave.subtle : Rave.paper)),
                    trailing: locked ? const Icon(Icons.lock_rounded, size: 16, color: Rave.subtle) : null,
                  );
                }),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: app.settings.dataSaver,
                activeThumbColor: Rave.mustard,
                onChanged: app.settings.setDataSaver,
                title: Text(s.dataSaver, style: Rave.body(size: 14.5, weight: FontWeight.w600)),
                subtitle: Text(s.dataSaverHint, style: Rave.body(size: 12.5, color: Rave.muted)),
              ),
            ]),
            _Section(s.server, hint: s.serverHint, children: [
              TextField(controller: _server, keyboardType: TextInputType.url, autocorrect: false, style: const TextStyle(fontFamily: Rave.mono, fontSize: 13)),
              const SizedBox(height: 10),
              Row(children: [
                OutlineButton(label: s.test, onTap: _testServer),
                const SizedBox(width: 8),
                OutlineButton(label: 'OK', onTap: _saveServer),
              ]),
              if (_test != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_test!, style: Rave.body(size: 13, color: _testOk ? Rave.mustard : Rave.berry))),
            ]),
            if (u != null) const _Privacy(),
            _Section(s.about, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlineButton(label: s.privacyPolicy, onTap: () => openUrl('${app.settings.server}/privasi')),
                OutlineButton(label: s.terms, onTap: () => openUrl('${app.settings.server}/ketentuan')),
              ]),
              const SizedBox(height: 12),Text(s.version(appVersionLabel), style: Rave.body(size: 13, color: Rave.muted))]),
          ]),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, {this.hint, required this.children});
  final String title;
  final String? hint;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 22),
        padding: const EdgeInsets.only(top: 16),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Rave.line))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(title, color: Rave.mustard),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: Rave.body(size: 12.5, color: Rave.muted))),
          const SizedBox(height: 12),
          ...children,
        ]),
      );
}

/// Privasi & data (UU PDP, BRD §8.2 / IAM-07): persetujuan per tujuan (PUT /v1/me/consents) dan hapus akun (DELETE /v1/me).
class _Privacy extends StatefulWidget {
  const _Privacy();
  @override
  State<_Privacy> createState() => _PrivacyState();
}

class _PrivacyState extends State<_Privacy> {
  static const purposes = ['personalization', 'ads', 'marketing', 'aggregate_sharing'];
  Map<String, bool>? granted;

  @override
  void initState() {
    super.initState();
    App.read(context).api.get('/v1/me/consents').then((j) {
      final m = {for (final p in purposes) p: false};
      for (final c in (j['data'] as List? ?? const [])) {
        m[c['purpose'] as String] = c['granted'] == true;
      }
      if (mounted) setState(() => granted = m);
    }).catchError((_) {
      if (mounted) setState(() => granted = {for (final p in purposes) p: false});
    });
  }

  Future<void> _set(String p, bool v) async {
    final app = App.read(context);
    setState(() => granted![p] = v);
    try {
      await app.api.put('/v1/me/consents', {'purpose': p, 'granted': v});
    } catch (e) {
      if (!mounted) return;
      setState(() => granted![p] = !v);
      toast(context, e.toString());
    }
  }

  Future<void> _delete() async {
    final app = App.read(context);
    final s = app.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Rave.base,
        shape: const RoundedRectangleBorder(side: BorderSide(color: Rave.berry)),
        title: Text(s.deleteTitle.toUpperCase(), style: Rave.poster(26)),
        content: Text(s.deleteBody, style: Rave.body(color: Rave.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(s.cancel, style: Rave.body(color: Rave.paper))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Rave.berry, shape: const RoundedRectangleBorder()),
            onPressed: () => Navigator.pop(d, true),
            child: Text(s.deleteConfirm.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await app.api.delete('/v1/me');
      await app.player.reset();
      await app.api.clear();
      app.likes.reset();
      app.cache.clear();
      if (mounted) toast(context, s.deleted);
    } catch (e) {
      if (mounted) toast(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final g = granted;
    return _Section(s.privacy, hint: s.privacyHint, children: [
      if (g == null)
        const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator(color: Rave.mustard))
      else
        for (final p in purposes)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: g[p] ?? false,
            activeThumbColor: Rave.mustard,
            onChanged: (v) => _set(p, v),
            title: Text(s.consentLabel(p), style: Rave.body(size: 14.5)),
          ),
      const SizedBox(height: 8),
      TextButton.icon(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: Rave.berry),
        onPressed: _delete,
        icon: const Icon(Icons.delete_forever_rounded),
        label: Text(s.deleteAccount, style: Rave.body(weight: FontWeight.w700, color: const Color(0xFFE0566E))),
      ),
    ]);
  }
}

