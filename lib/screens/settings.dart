import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/appearance.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/settings.dart';
import '../core/theme.dart';
import '../core/version.dart';
import '../player/audio_fx.dart';
import '../widgets/common.dart';
import '../widgets/connection.dart';
import '../widgets/feedback.dart';
import '../widgets/links.dart';
import '../widgets/motion.dart';
import 'browse.dart';
import 'login.dart';
import 'shell.dart';

/// Pengaturan — bagian RAVE berikon (sama dengan web pages/fan/Settings.tsx): Akun, Bahasa, Kualitas audio,
/// Equalizer, Pustaka, Tampilan, Notifikasi, Privasi, Server, Tentang, Zona bahaya. Kolom cari menyaring baris;
/// bagian tanpa baris yang cocok disembunyikan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  final _keys = <String, GlobalKey>{};
  QualityPolicy _policy = const QualityPolicy();
  /// Gain pita equalizer selama slider digeser (disimpan saat dilepas).
  final _dragGain = <int, double>{};

  String get _q => _search.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    final app = App.read(context);
    unawaited(refreshAppearance(app));
    platformSettings(app).then((cfg) {
      if (!mounted) return;
      final pol = QualityPolicy.fromSettings(cfg);
      setState(() => _policy = pol);
      final clamped = pol.clamp(app.settings.quality);
      if (clamped != app.settings.quality) app.settings.setQuality(clamped);
      if (app.api.authed) app.settings.enforceFreeQuality(premium: app.api.user?.premium ?? false, freeMax: pol.freeMax);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    final app = App.read(context);
    await app.player.flush();
    await app.player.reset();
    await app.api.logout();
    app.likes.reset();
    app.cache.clear();
  }

  Future<void> _deleteAccount() async {
    final app = App.read(context);
    final s = app.s;
    final ok = await confirmDialog(context, title: s.deleteTitle, body: s.deleteBody, confirmLabel: s.deleteConfirm, danger: true);
    if (!ok || !mounted) return;
    try {
      await app.api.delete('/v1/me');
      await app.player.reset();
      await app.api.clear();
      app.likes.reset();
      app.cache.clear();
      if (mounted) showToast(context, s.deleted, kind: ToastKind.ok);
    } catch (e) {
      if (mounted) toastError(context, e);
    }
  }

  void _openPremium() {
    Navigator.of(context).maybePop();
    selectShellTab(3);
  }

  void _jump(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.api, app.player]),
      builder: (context, _) {
        final u = app.api.user;
        final q = _q;
        GlobalKey k(String id) => _keys.putIfAbsent(id, GlobalKey.new);
        // Tamu: tidak ada pengaturan akun sama sekali — hanya ajakan Masuk / Daftar (web: /app/settings di balik RequireAuth).
        if (u == null) return _GuestSettings(title: s.settings);
        final premium = u.premium;
        // (id, bagian, terlihat). Bagian tersembunyi tidak dibangun → pencarian hanya mencocokkan baris yang tampil.
        final entries = <(String, Widget, bool)>[];
        void add(String id, SettingsSection sec) => entries.add((id, sec, sec.visible));
        add('account', _account(app, s, u, q, k('account')));
        add('language', _language(app, s, q, k('language')));
        if (premium) {
          add('audio', _audio(app, s, u, q, k('audio')));
          add('eq', _eq(app, s, u, q, k('eq')));
        } else {
          add('premium', _premiumCard(s, q, k('premium')));
        }
        add('playback', _playback(app, s, q, k('playback')));
        add(
          'library',
          SettingsSection(
            key: k('library'),
            title: s.section('library'),
            icon: Icons.library_music_rounded,
            query: q,
            rows: [
              SettingsRow(
                label: s.compactRow,
                desc: s.compactHint,
                keywords: 'compact ringkas library pustaka koleksi collection',
                trailing: RaveSwitch(label: s.compactRow, value: app.settings.compactLibrary, onChanged: (v) => app.settings.setBool('compactLibrary', v)),
              ),
            ],
          ),
        );
        add(
          'display',
          SettingsSection(
            key: k('display'),
            title: s.section('display'),
            icon: Icons.album_rounded,
            query: q,
            rows: [
              SettingsRow(
                label: s.themeRow,
                desc: !app.settings.allowUserTheme ? s.themeLocked : s.themeHint,
                keywords: 'theme tema dark light gelap terang system sistem mode',
                below: app.settings.allowUserTheme ? ThemePicker(value: app.themeChoice, onChanged: (v) => setPlayerTheme(context, v)) : null,
              ),
              SettingsRow(
                label: s.vinylRow,
                desc: s.vinylHint,
                keywords: 'vinyl piringan animation animasi',
                trailing: RaveSwitch(label: s.vinylRow, value: app.settings.vinylMotion, onChanged: (v) => app.settings.setBool('vinylMotion', v)),
              ),
            ],
          ),
        );
        // Bagian yang memuat datanya sendiri (notifikasi, privasi): dicocokkan dari teks statisnya.
        final notifHit =
            settingsMatch(q, [s.section('notifications'), 'notification notifikasi push email whatsapp', for (final c in _NotificationsState.categories) ...[s.notifCategory(c).name, s.notifCategory(c).desc]]);
        final privacyHit = settingsMatch(q, [s.section('privacy'), s.privacy, s.privacyHint, 'privacy privasi consent pdp data', for (final p in _PrivacyState.purposes) s.consentLabel(p)]);
        entries.add(('notifications', _Notifications(key: k('notifications'), query: q), notifHit));
        entries.add(('privacy', _Privacy(key: k('privacy'), query: q), privacyHit));
        add('server', _serverSection(app, s, q, k('server')));
        add(
          'about',
          SettingsSection(
            key: k('about'),
            title: s.about,
            icon: Icons.info_outline_rounded,
            query: q,
            rows: [
              SettingsRow(
                label: s.version(appVersionLabel),
                keywords: 'version versi privacy privasi terms ketentuan',
                below: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlineButton(label: s.privacyPolicy, onTap: () => openUrl('${app.settings.server}/privasi')),
                  OutlineButton(label: s.terms, onTap: () => openUrl('${app.settings.server}/ketentuan')),
                ]),
              ),
            ],
          ),
        );
        add(
          'danger',
          SettingsSection(
            key: k('danger'),
            title: s.section('danger'),
            icon: Icons.warning_amber_rounded,
            danger: true,
            query: q,
            rows: [
              SettingsRow(
                label: s.deleteAccount,
                desc: '${s.dangerNote} ${s.deleteBody}',
                keywords: 'delete hapus akun account',
                below: Align(
                  alignment: Alignment.centerLeft,
                  child: DialogButton(label: s.deleteAccount, variant: DialogVariant.danger, onTap: _deleteAccount),
                ),
              ),
            ],
          ),
        );
        // Chip lompat hanya untuk bagian yang tampil (server & tentang tidak diberi chip).
        final jumpIds = [for (final e in entries) if (e.$3 && settingsIcons.containsKey(e.$1)) e.$1];
        final any = entries.any((e) => e.$3);
        final sections = [for (final e in entries) if (e.$3) e.$2];
        return Scaffold(
          appBar: AppBar(title: Text(s.settings.toUpperCase(), style: Rave.poster(26))),
          body: ListView(physics: raveVerticalPhysics, padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              style: Rave.body(size: 15),
              decoration: InputDecoration(
                hintText: s.searchSettings,
                prefixIcon: Icon(Icons.search_rounded, color: context.rc.muted),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: s.close,
                        onPressed: () => setState(_search.clear),
                        icon: Icon(Icons.close_rounded, color: context.rc.muted),
                      ),
              ),
            ),
            if (q.isEmpty)
              SizedBox(
                height: 52,
                child: RaveHorizontalList(padding: const EdgeInsets.only(top: 10), children: [
                  for (final id in jumpIds)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: RaveChip(label: s.section(id), icon: settingsIcons[id], selected: false, onTap: () => _jump(id)),
                    ),
                ]),
              ),
            ...sections,
            if (q.isNotEmpty && !any)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(s.noSettings(_search.text.trim()), textAlign: TextAlign.center, style: Rave.body(color: context.rc.muted)),
              ),
          ]),
        );
      },
    );
  }

  SettingsSection _account(AppState app, S s, Me? u, String q, Key key) => SettingsSection(
        key: key,
        title: s.section('account'),
        icon: Icons.person_rounded,
        query: q,
        rows: [
          if (u != null) ...[
            SettingsRow(
              label: u.displayName,
              desc: u.premium ? s.premiumActive : s.free,
              keywords: 'profile profil premium logout keluar ${s.logout}',
              leading: Cover(u.avatarUrl, size: 44, round: true),
              trailing: OutlineButton(label: s.logout, onTap: _logout),
            ),
            SettingsRow(label: s.emailRow, desc: s.emailRowHint, keywords: 'email login', below: Text(u.email, style: TextStyle(fontFamily: Rave.mono, fontSize: 13, color: context.rc.text))),
          ] else
            SettingsRow(
              label: s.signInOrUp,
              desc: s.guestBody,
              keywords: 'login masuk daftar sign',
              below: PrimaryButton(label: s.signInOrUp, onTap: () => openLogin(context)),
            ),
        ],
      );

  SettingsSection _language(AppState app, S s, String q, Key key) => SettingsSection(
        key: key,
        title: s.section('language'),
        icon: Icons.language_rounded,
        query: q,
        rows: [
          SettingsRow(
            label: s.languageRow,
            desc: s.languageRowHint,
            keywords: 'language bahasa english indonesia',
            below: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (k, label) in [('id', 'Bahasa Indonesia'), ('en', 'English')]) RaveChip(label: label, selected: app.settings.locale == k, onTap: () => app.settings.setLocale(k)),
            ]),
          ),
        ],
      );

  SettingsSection _audio(AppState app, S s, Me? u, String q, Key key) {
    final premium = u?.premium ?? false;
    final pol = _policy;
    final cur = app.settings.quality;
    return SettingsSection(
      key: key,
      title: s.section('audio'),
      icon: Icons.graphic_eq_rounded,
      query: q,
      rows: [
        SettingsRow(
          label: s.quality,
          desc: s.qualityRowHint,
          keywords: 'kbps flac lossless aac quality kualitas hi-res',
          below: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final v in pol.options)
              _QualityOption(
                label: s.q(v),
                desc: v == 'lossless' ? s.losslessCap(pol.losslessRes) : s.qDesc(v),
                selected: cur == v,
                locked: pol.locked(v, premium: premium),
                lockedLabel: s.premium,
                onTap: () => app.settings.setQuality(v),
              ),
            if (!premium)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                  Text(s.freeQualityNote(s.q(pol.freeMax)), style: Rave.body(size: 12.5, color: context.rc.muted)),
                  GestureDetector(
                    onTap: _openPremium,
                    child: Text(s.premiumQualityCta, style: Rave.body(size: 12.5, weight: FontWeight.w800, color: context.rc.accent).copyWith(decoration: TextDecoration.underline, decorationColor: context.rc.accent)),
                  ),
                ]),
              ),
          ]),
        ),
      ],
    );
  }

  /// Pemutaran (semua akun): hemat data & normalisasi volume.
  SettingsSection _playback(AppState app, S s, String q, Key key) => SettingsSection(
        key: key,
        title: s.section('playback'),
        icon: Icons.play_circle_outline_rounded,
        query: q,
        rows: [
          SettingsRow(
            label: s.normalizeRow,
            desc: s.normalizeHint,
            keywords: 'loudness normalize normalisasi volume',
            trailing: RaveSwitch(label: s.normalizeRow, value: app.settings.normalizeVolume, onChanged: (v) => app.settings.setBool('normalize', v)),
          ),
          SettingsRow(
            label: s.dataSaver,
            desc: s.dataSaverHint,
            keywords: 'data saver hemat kuota',
            trailing: RaveSwitch(label: s.dataSaver, value: app.settings.dataSaver, onChanged: app.settings.setDataSaver),
          ),
        ],
      );

  /// Akun Gratis: satu kartu Premium menggantikan bagian Kualitas audio & Equalizer.
  SettingsSection _premiumCard(S s, String q, Key key) => SettingsSection(
        key: key,
        title: s.section('premium'),
        icon: Icons.workspace_premium_rounded,
        query: q,
        rows: [
          SettingsRow(
            label: s.premiumAudioTitle,
            desc: s.premiumAudioBody,
            keywords: 'premium kualitas quality audio kbps aac flac lossless hi-res equalizer equaliser eq bass treble',
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: context.rc.hard(2)),
              child: Text(s.premium.toUpperCase(), style: Rave.label(size: 9.5, color: Rave.ink)),
            ),
            below: Align(alignment: Alignment.centerLeft, child: DialogButton(label: s.premiumQualityCta, variant: DialogVariant.primary, onTap: _openPremium)),
          ),
        ],
      );

  SettingsSection _eq(AppState app, S s, Me? u, String q, Key key) {
    final premium = u?.premium ?? false;
    final p = app.player;
    final params = p.eqParams;
    final on = app.settings.eqOn;
    Widget body;
    if (!premium) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(border: Border.all(color: context.rc.accent.withValues(alpha: 0.6))),
            child: Text(s.premium.toUpperCase(), style: Rave.label(size: 9.5, color: context.rc.accent)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(s.eqPremium, style: Rave.body(size: 13, color: context.rc.muted))),
        ]),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: DialogButton(label: s.eqPremiumCta, variant: DialogVariant.primary, onTap: _openPremium)),
      ]);
    } else if (!p.eqSupported) {
      body = Text(s.eqUnavailable, style: Rave.body(size: 13, color: context.rc.muted));
    } else if (params == null) {
      body = Text(s.eqWaiting, style: Rave.body(size: 13, color: context.rc.muted));
    } else {
      final gains = p.eqGainsFor(params);
      final preset = app.settings.eqPreset;
      body = Opacity(
        opacity: on ? 1 : 0.5,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!on) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.eqOffNote, style: Rave.body(size: 12.5, color: context.rc.muted))),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final k in [...eqPresets.keys, if (preset == 'custom') 'custom'])
              RaveChip(label: s.eqPreset(k), selected: preset == k, onTap: on && k != 'custom' ? () => app.settings.setEq(preset: k) : () {}),
          ]),
          const SizedBox(height: 10),
          for (var i = 0; i < params.bands.length; i++)
            Row(children: [
              SizedBox(width: 46, child: Text(fmtHz(params.bands[i].centerFrequency), style: Rave.label(size: 10.5, color: context.rc.muted))),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: context.rc.accent,
                    thumbColor: context.rc.accent,
                    inactiveTrackColor: context.rc.isLight ? const Color(0x33181818) : const Color(0xFF3A363E),
                  ),
                  child: Slider(
                    min: params.minDecibels,
                    max: params.maxDecibels,
                    divisions: ((params.maxDecibels - params.minDecibels) * 2).round().clamp(1, 200),
                    value: (_dragGain[i] ?? (i < gains.length ? gains[i] : 0)).clamp(params.minDecibels, params.maxDecibels).toDouble(),
                    semanticFormatterCallback: (v) => '${fmtHz(params.bands[i].centerFrequency)} Hz ${v.toStringAsFixed(1)} dB',
                    onChanged: on ? (v) => setState(() => _dragGain[i] = v) : null,
                    onChangeEnd: on
                        ? (v) {
                            final next = [...gains];
                            if (i < next.length) next[i] = v;
                            _dragGain.clear();
                            app.settings.setEq(preset: 'custom', gains: next);
                          }
                        : null,
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text('${(_dragGain[i] ?? (i < gains.length ? gains[i] : 0)) > 0 ? '+' : ''}${(_dragGain[i] ?? (i < gains.length ? gains[i] : 0)).toStringAsFixed(1)} dB',
                    textAlign: TextAlign.right, style: Rave.label(size: 10, color: context.rc.text)),
              ),
            ]),
          Align(alignment: Alignment.centerRight, child: OutlineButton(label: s.eqReset, onTap: on ? () => app.settings.setEq(preset: 'flat') : null)),
        ]),
      );
    }
    return SettingsSection(
      key: key,
      title: s.section('eq'),
      icon: Icons.tune_rounded,
      query: q,
      rows: [
        SettingsRow(
          label: s.eqRow,
          desc: s.eqHint,
          keywords: 'equalizer equaliser bass treble eq premium vocal',
          trailing: RaveSwitch(label: s.eqRow, value: premium && on, onChanged: premium && p.eqSupported ? (v) => app.settings.setBool('eqOn', v) : null),
          below: body,
        ),
      ],
    );
  }

  SettingsSection _serverSection(AppState app, S s, String q, Key key) => SettingsSection(
        key: key,
        title: s.server,
        icon: Icons.dns_rounded,
        query: q,
        rows: [SettingsRow(label: s.server, desc: s.serverHint, keywords: 'server api gateway url', below: const ServerEditor())],
      );
}

/// Ganti tema (web lib/playerTheme.ts): langsung berlaku (optimistis), disimpan di perangkat, dan — bila masuk — di
/// akun (`PATCH /v1/me {theme}`) agar ikut ke web & desktop. Gagal simpan ke akun → dikembalikan + stiker galat.
Future<void> setPlayerTheme(BuildContext context, String choice) async {
  final app = App.read(context);
  await app.settings.setThemePref(choice);
  final u = app.api.user;
  if (!app.api.authed || u == null || u.theme == choice) return;
  await app.api.setUser(u.withTheme(choice));
  try {
    final me = await app.api.request<Json>('/v1/me', method: 'PATCH', body: {'theme': choice});
    await app.api.setUser(Me.fromJson(me));
  } catch (e) {
    await app.api.setUser(u);
    if (context.mounted) toastError(context, e);
  }
}

/// Tiga kartu pratinjau tema (Gelap / Terang / Ikuti sistem) — web `.theme-card`.
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final rc = context.rc;
    Widget preview(String k) {
      Widget half(bool light) => Expanded(
            child: Container(
              color: light ? const Color(0xFFF6F1E7) : Rave.ink,
              child: Stack(children: [
                Positioned(left: 6, top: 8, width: 16, bottom: 10, child: Container(decoration: BoxDecoration(color: light ? Rave.teal : Rave.purple, border: Border.all(color: Rave.ink)))),
                Positioned(left: 28, right: 6, top: 10, height: 5, child: ColoredBox(color: light ? Rave.ink : Rave.paper)),
                Positioned(left: 28, width: 18, top: 22, height: 5, child: const ColoredBox(color: Rave.mustard)),
              ]),
            ),
          );
      return Container(
        height: 56,
        decoration: BoxDecoration(border: Border.all(color: Rave.ink, width: 2)),
        child: Row(children: [if (k != 'light') half(false), if (k != 'dark') half(true)]),
      );
    }

    return Row(children: [
      for (final k in themeChoices) ...[
        if (k != themeChoices.first) const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            selected: value == k,
            button: true,
            label: s.themeName(k),
            child: GestureDetector(
              onTap: () => onChanged(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(8),
                transform: Matrix4.translationValues(value == k ? -1 : 0, value == k ? -1 : 0, 0),
                decoration: BoxDecoration(
                  color: rc.isLight ? rc.base : Colors.transparent,
                  border: Border.all(color: value == k ? Rave.mustard : rc.chipBorder, width: value == k ? 2 : 1),
                  boxShadow: value == k ? const [BoxShadow(color: Rave.mustard, offset: Offset(4, 4))] : null,
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  preview(k),
                  const SizedBox(height: 8),
                  Text(s.themeName(k), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, weight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Ikon per bagian pengaturan (web SECTION_ICON).
const settingsIcons = <String, IconData>{
  'account': Icons.person_rounded,
  'language': Icons.language_rounded,
  'audio': Icons.graphic_eq_rounded,
  'eq': Icons.tune_rounded,
  'library': Icons.library_music_rounded,
  'premium': Icons.workspace_premium_rounded,
  'playback': Icons.play_circle_outline_rounded,
  'display': Icons.album_rounded,
  'notifications': Icons.notifications_rounded,
  'privacy': Icons.shield_rounded,
  'danger': Icons.warning_amber_rounded,
};

/// Pengaturan untuk tamu: hanya kartu ajakan Masuk / Daftar (tanpa baris akun/audio/tema/server/privasi).
class _GuestSettings extends StatelessWidget {
  const _GuestSettings({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final rc = context.rc;
    return Scaffold(
      appBar: AppBar(title: Text(title.toUpperCase(), style: Rave.poster(26))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              decoration: BoxDecoration(
                color: rc.isLight ? rc.card : const Color(0xFF1A171C),
                border: Border.all(color: Rave.ink, width: 2),
                boxShadow: rc.hard(6),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                Container(height: 4, color: Rave.mustard),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lock_person_rounded, size: 36, color: rc.accent),
                    const SizedBox(height: 12),
                    Text(s.settingsGuestTitle.toUpperCase(), style: Rave.poster(30)),
                    const SizedBox(height: 8),
                    Text(s.settingsGuestBody, style: Rave.body(size: 14, color: rc.muted, height: 1.4)),
                    const SizedBox(height: 20),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      DialogButton(label: s.logIn, onTap: () => openLogin(context)),
                      DialogButton(label: s.signUp, variant: DialogVariant.primary, onTap: () => openLogin(context, signUp: true)),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cocok dengan kata kunci pencarian (tanpa beda huruf besar/kecil). Kueri kosong = selalu cocok.
bool settingsMatch(String q, Iterable<String?> texts) => q.isEmpty || texts.any((t) => t != null && t.toLowerCase().contains(q.toLowerCase()));

/// Satu baris pengaturan: label + deskripsi di kiri, kontrol di kanan ([trailing]) dan/atau di bawah ([below]).
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.label, this.desc, this.keywords, this.trailing, this.below, this.leading});
  final String label;
  final String? desc, keywords;
  final Widget? trailing, below, leading;

  bool matches(String q) => settingsMatch(q, [label, desc, keywords]);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: Rave.body(size: 15, weight: FontWeight.w700)),
                if (desc != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(desc!, style: Rave.body(size: 12.5, color: context.rc.muted, height: 1.35))),
              ]),
            ),
            if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          ]),
          if (below != null) ...[const SizedBox(height: 12), below!],
        ]),
      );
}

/// Bagian pengaturan: judul Staatliches dengan ikon kotak (mustard; berry = berbahaya) + kartu berisi baris.
/// Hanya baris yang cocok dengan [query] yang dirender; tanpa baris cocok → bagian disembunyikan.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.icon, required this.rows, this.query = '', this.danger = false});
  final String title;
  final IconData icon;
  final List<SettingsRow> rows;
  final String query;
  final bool danger;

  List<SettingsRow> get _visible => rows.where((r) => r.matches(query) || settingsMatch(query, [title])).toList();
  bool get visible => _visible.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final shown = _visible;
    if (shown.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: danger ? Rave.berry : Rave.mustard, border: Border.all(color: Rave.ink, width: 2)),
            child: Icon(icon, size: 16, color: danger ? Colors.white : Rave.ink),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title.toUpperCase(), style: Rave.poster(24))),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: context.rc.card,
            border: Border.all(color: danger ? (context.rc.isLight ? Rave.berry : const Color(0xB38A2F3F)) : context.rc.cardBorder),
            boxShadow: context.rc.isLight ? context.rc.hard(5) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(height: 1, color: context.rc.isLight ? const Color(0x14181818) : const Color(0x14FFFFFF)),
              shown[i],
            ],
          ]),
        ),
      ]),
    );
  }
}

/// Opsi kualitas: indikator kotak, label + deskripsi, terkunci = label Premium + gembok.
class _QualityOption extends StatelessWidget {
  const _QualityOption({required this.label, required this.desc, required this.selected, required this.locked, required this.lockedLabel, required this.onTap});
  final String label, desc, lockedLabel;
  final bool selected, locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        enabled: !locked,
        button: true,
        child: InkWell(
          onTap: locked ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: selected ? Rave.mustard : Colors.transparent, border: Border.all(color: selected ? Rave.ink : context.rc.subtle, width: 2)),
                child: selected ? const Icon(Icons.check_rounded, size: 14, color: Rave.ink) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: locked ? 0.5 : 1,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: Rave.body(size: 14.5, weight: FontWeight.w700)),
                    Text(desc, style: Rave.body(size: 12, color: context.rc.muted)),
                  ]),
                ),
              ),
              if (locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(border: Border.all(color: context.rc.accent.withValues(alpha: 0.6))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.lock_rounded, size: 11, color: context.rc.accent),
                    const SizedBox(width: 4),
                    Text(lockedLabel.toUpperCase(), style: Rave.label(size: 9.5, color: context.rc.accent)),
                  ]),
                ),
            ]),
          ),
        ),
      );
}

/// Notifikasi per kategori × kanal tambahan (`/v1/notifications/preferences`, sama dengan web).
class _Notifications extends StatefulWidget {
  const _Notifications({super.key, required this.query});
  final String query;
  @override
  State<_Notifications> createState() => _NotificationsState();
}

class _NotificationsState extends State<_Notifications> {
  static const categories = ['event', 'release', 'payment', 'booking', 'system', 'social'];
  static const channels = [('push', 'Push'), ('email', 'Email'), ('whatsapp', 'WhatsApp')];
  Map<String, Json>? prefs;
  bool failed = false;

  /// Bawaan server bila belum ada baris: push aktif, email hanya booking/pembayaran, WhatsApp mati.
  static Json _default(String c) => {'category': c, 'push': true, 'email': c == 'booking' || c == 'payment', 'whatsapp': false, 'quiet_start': null, 'quiet_end': null};

  @override
  void initState() {
    super.initState();
    App.read(context).api.get('/v1/notifications/preferences').then((j) {
      final m = {for (final c in categories) c: _default(c)};
      for (final x in (j['data'] as List? ?? const [])) {
        final p = Map<String, dynamic>.from(x as Json);
        if (m.containsKey(p['category'])) m[p['category'] as String] = p;
      }
      if (mounted) setState(() => prefs = m);
    }).catchError((Object _) {
      if (mounted) setState(() => failed = true);
    });
  }

  Future<void> _set(String c, String ch, bool v) async {
    final app = App.read(context);
    final old = prefs![c]!;
    final next = {...old, ch: v};
    setState(() => prefs![c] = next);
    try {
      await app.api.put('/v1/notifications/preferences', {
        'category': c,
        'push': next['push'] == true,
        'email': next['email'] == true,
        'whatsapp': next['whatsapp'] == true,
        'quiet_start': next['quiet_start'],
        'quiet_end': next['quiet_end'],
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => prefs![c] = old);
      toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final p = prefs;
    return SettingsSection(
      title: s.section('notifications'),
      icon: Icons.notifications_rounded,
      query: widget.query,
      rows: [
        if (failed || p == null)
          SettingsRow(label: s.section('notifications'), desc: failed ? s.notifFailed : s.notifIntro, keywords: 'notification notifikasi push email whatsapp')
        else
          for (final c in categories)
            SettingsRow(
              label: s.notifCategory(c).name,
              desc: s.notifCategory(c).desc,
              keywords: 'notification notifikasi push email whatsapp',
              below: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (ch, label) in channels) RaveChip(label: label, icon: p[c]![ch] == true ? Icons.check_rounded : null, selected: p[c]![ch] == true, onTap: () => _set(c, ch, p[c]![ch] != true)),
              ]),
            ),
      ],
    );
  }
}

/// Privasi & data (UU PDP, BRD §8.2 / IAM-07): persetujuan per tujuan (PUT /v1/me/consents).
class _Privacy extends StatefulWidget {
  const _Privacy({super.key, required this.query});
  final String query;
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
      toastError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final g = granted;
    return SettingsSection(
      title: s.section('privacy'),
      icon: Icons.shield_rounded,
      query: widget.query,
      rows: [
        SettingsRow(label: s.privacy, desc: s.privacyHint, keywords: 'privacy privasi consent pdp data'),
        for (final p in purposes)
          SettingsRow(
            label: s.consentLabel(p),
            keywords: 'privacy privasi consent data $p',
            trailing: RaveSwitch(label: s.consentLabel(p), value: g?[p] ?? false, onChanged: g == null ? null : (v) => _set(p, v)),
          ),
      ],
    );
  }
}
