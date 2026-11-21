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
import '../widgets/verified_badge.dart';
import 'browse.dart';
import 'login.dart';
import 'profile.dart';
import 'shell.dart';

/// Pengaturan — tata letak daftar bergaya pengaturan sistem, tetap bernuansa RAVE:
/// kartu profil → Akun & keamanan → Pemutaran → Tampilan → Notifikasi & privasi → Tentang → Keluar / Hapus akun.
/// Detail yang panjang (kualitas audio, equalizer, notifikasi per kategori, privasi, server) dibuka di sub-halaman,
/// jadi halaman utama ringkas. Kolom cari menyaring baris; bagian tanpa baris cocok disembunyikan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  QualityPolicy _policy = const QualityPolicy();

  String get _q => _search.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    final app = App.read(context);
    unawaited(refreshAppearance(app));
    // Status/badge verifikasi & 2FA terbaru (mis. setelah mengubahnya di web).
    unawaited(app.api.refreshMe());
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
    final s = app.s;
    final ok = await confirmDialog(context, title: s.logoutTitle, body: s.logoutBody, confirmLabel: s.logout);
    if (!ok) return;
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

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.api, app.player]),
      builder: (context, _) {
        final u = app.api.user;
        // Tamu: tidak ada pengaturan akun sama sekali — hanya ajakan Masuk / Daftar (web: /app/settings di balik RequireAuth).
        if (u == null) return _GuestSettings(title: s.settings);
        final q = _q;
        final premium = u.premium;
        final sections = <SettingsSection>[
          _accountSection(app, s, u, q),
          _playbackSection(app, s, u, q),
          _displaySection(app, s, q),
          _notifPrivacySection(s, q),
          _aboutSection(app, s, q),
        ];
        final any = sections.any((x) => x.visible) || (q.isNotEmpty && settingsMatch(q, [s.logout, s.deleteAccount, 'logout keluar hapus delete']));
        return Scaffold(
          appBar: AppBar(title: Text(s.settings.toUpperCase(), style: Rave.poster(26))),
          body: ListView(physics: raveVerticalPhysics, padding: const EdgeInsets.fromLTRB(16, 4, 16, 48), children: [
            _SearchField(controller: _search, hint: s.searchSettings, clearLabel: s.close, onChanged: () => setState(() {})),
            if (q.isEmpty) ...[
              const SizedBox(height: 16),
              _ProfileCard(user: u, onEdit: () => openProfile(context)),
              if (!premium) ...[const SizedBox(height: 12), _PremiumBanner(onTap: _openPremium)],
            ],
            ...sections,
            if (q.isEmpty || settingsMatch(q, [s.logout, s.deleteAccount, 'logout keluar hapus delete akun account'])) ...[
              const SizedBox(height: 28),
              _SignOutButton(label: s.logout, onTap: _logout),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  key: const ValueKey('delete-account'),
                  onPressed: _deleteAccount,
                  child: Text(s.deleteAccount, style: Rave.body(size: 13.5, weight: FontWeight.w700, color: const Color(0xFFE0566E))),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(s.version(appVersionLabel), textAlign: TextAlign.center, style: Rave.label(size: 9.5, color: context.rc.subtle)),
              ),
            ],
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

  // ---------------- Bagian ----------------

  SettingsSection _accountSection(AppState app, S s, Me u, String q) {
    final status = u.verificationStatus;
    final badge = status == 'VERIFIED' && u.verified;
    return SettingsSection(
      key: const ValueKey('sec-account'),
      title: s.sectionAccountSecurity,
      icon: Icons.person_rounded,
      query: q,
      rows: [
        SettingsRow(
          icon: Icons.edit_outlined,
          label: s.editProfile,
          desc: s.editProfileHint,
          keywords: 'profile profil edit foto photo avatar bio nama name kota city social ${u.displayName}',
          onTap: () => openProfile(context),
          chevron: true,
        ),
        SettingsRow(
          key: const ValueKey('verify-row'),
          leading: SizedBox(width: 34, height: 34, child: Center(child: VerifiedBadge(size: 28, dim: !badge))),
          label: s.verifyAccount,
          desc: s.verifyStatus(status, badge: u.verified, since: fmtDay(u.verifiedAt, s.id)),
          keywords: 'verified verifikasi verification badge centang kyc nik ktp identitas identity ${s.applyVerified} ${s.manageVerification}',
          onTap: () => openUrl('${app.settings.server}/app/settings#set-verify'),
          external: true,
        ),
        SettingsRow(
          key: const ValueKey('security-row'),
          icon: u.totpEnabled ? Icons.verified_user_rounded : Icons.shield_outlined,
          iconColor: u.totpEnabled ? _ok : null,
          label: s.twoStep,
          desc: s.twoStepShort(u.totpEnabled),
          keywords: '${s.twoStepStatus(u.totpEnabled)} keamanan security 2fa mfa totp authenticator verifikasi dua langkah two-step kode pemulihan recovery',
          onTap: () => openUrl('${app.settings.server}/app/settings#set-security'),
          status: _StatusPill(on: u.totpEnabled, onLabel: s.statusOn, offLabel: s.statusOff),
          external: true,
        ),
        SettingsRow(
          icon: Icons.alternate_email_rounded,
          label: s.emailRow,
          desc: u.email,
          keywords: 'email login otp',
        ),
      ],
    );
  }

  SettingsSection _playbackSection(AppState app, S s, Me u, String q) {
    final premium = u.premium;
    return SettingsSection(
      key: const ValueKey('sec-playback'),
      title: s.section('playback'),
      icon: Icons.play_circle_outline_rounded,
      query: q,
      rows: [
        SettingsRow(
          icon: Icons.graphic_eq_rounded,
          label: s.section('audio'),
          desc: s.q(app.settings.quality),
          keywords: 'kbps flac lossless aac quality kualitas hi-res audio',
          onTap: () => _push(_QualityPage(policy: _policy, onPremium: _openPremium)),
          status: premium ? null : _PremiumTag(label: s.premium),
          chevron: true,
        ),
        SettingsRow(
          icon: Icons.tune_rounded,
          label: 'Equalizer',
          desc: !premium ? s.eqPremium : (app.settings.eqOn ? s.eqPreset(app.settings.eqPreset) : s.statusOff),
          keywords: 'equalizer equaliser bass treble eq premium vocal',
          onTap: premium ? () => _push(const _EqPage()) : _openPremium,
          status: premium ? null : _PremiumTag(label: s.premium),
          chevron: true,
        ),
        SettingsRow(
          icon: Icons.volume_up_outlined,
          label: s.normalizeRow,
          desc: s.normalizeHint,
          keywords: 'loudness normalize normalisasi volume',
          trailing: RaveSwitch(label: s.normalizeRow, value: app.settings.normalizeVolume, onChanged: (v) => app.settings.setBool('normalize', v)),
        ),
        SettingsRow(
          icon: Icons.data_saver_on_outlined,
          label: s.dataSaver,
          desc: s.dataSaverHint,
          keywords: 'data saver hemat kuota',
          trailing: RaveSwitch(label: s.dataSaver, value: app.settings.dataSaver, onChanged: app.settings.setDataSaver),
        ),
      ],
    );
  }

  SettingsSection _displaySection(AppState app, S s, String q) => SettingsSection(
        key: const ValueKey('sec-display'),
        title: s.section('display'),
        icon: Icons.palette_outlined,
        query: q,
        rows: [
          SettingsRow(
            icon: Icons.contrast_rounded,
            label: s.themeRow,
            desc: !app.settings.allowUserTheme ? s.themeLocked : null,
            keywords: 'theme tema dark light gelap terang system sistem mode ${s.themeHint}',
            below: app.settings.allowUserTheme ? ThemePicker(value: app.themeChoice, onChanged: (v) => setPlayerTheme(context, v)) : null,
          ),
          SettingsRow(
            icon: Icons.translate_rounded,
            label: s.languageRow,
            keywords: 'language bahasa english indonesia ${s.languageRowHint}',
            trailing: _Segmented(
              value: app.settings.locale,
              options: const [('id', 'ID'), ('en', 'EN')],
              semantic: const {'id': 'Bahasa Indonesia', 'en': 'English'},
              onChanged: app.settings.setLocale,
            ),
          ),
          SettingsRow(
            icon: Icons.album_outlined,
            label: s.vinylRow,
            desc: s.vinylHint,
            keywords: 'vinyl piringan animation animasi',
            trailing: RaveSwitch(label: s.vinylRow, value: app.settings.vinylMotion, onChanged: (v) => app.settings.setBool('vinylMotion', v)),
          ),
          SettingsRow(
            icon: Icons.view_agenda_outlined,
            label: s.compactRow,
            desc: s.compactHint,
            keywords: 'compact ringkas library pustaka koleksi collection',
            trailing: RaveSwitch(label: s.compactRow, value: app.settings.compactLibrary, onChanged: (v) => app.settings.setBool('compactLibrary', v)),
          ),
        ],
      );

  SettingsSection _notifPrivacySection(S s, String q) => SettingsSection(
        key: const ValueKey('sec-notif'),
        title: s.sectionNotifPrivacy,
        icon: Icons.notifications_rounded,
        query: q,
        rows: [
          SettingsRow(
            icon: Icons.notifications_none_rounded,
            label: s.section('notifications'),
            desc: s.notifRowHint,
            keywords: 'notification notifikasi push email whatsapp ${[for (final c in _NotificationsPageState.categories) '${s.notifCategory(c).name} ${s.notifCategory(c).desc}'].join(' ')}',
            onTap: () => _push(const _NotificationsPage()),
            chevron: true,
          ),
          SettingsRow(
            icon: Icons.privacy_tip_outlined,
            label: s.privacy,
            desc: s.privacyRowHint,
            keywords: 'privacy privasi consent pdp data ${[for (final p in _PrivacyPageState.purposes) s.consentLabel(p)].join(' ')}',
            onTap: () => _push(const _PrivacyPage()),
            chevron: true,
          ),
        ],
      );

  SettingsSection _aboutSection(AppState app, S s, String q) => SettingsSection(
        key: const ValueKey('sec-about'),
        title: s.about,
        icon: Icons.info_outline_rounded,
        query: q,
        rows: [
          SettingsRow(
            icon: Icons.dns_outlined,
            label: s.server,
            desc: app.settings.server.replaceFirst(RegExp(r'^https?://'), ''),
            keywords: 'server api gateway url',
            onTap: () => _push(const _ServerPage()),
            chevron: true,
          ),
          SettingsRow(
            icon: Icons.policy_outlined,
            label: s.privacyPolicy,
            keywords: 'privacy policy kebijakan privasi',
            onTap: () => openUrl('${app.settings.server}/privasi'),
            external: true,
          ),
          SettingsRow(
            icon: Icons.description_outlined,
            label: s.terms,
            keywords: 'terms ketentuan layanan',
            onTap: () => openUrl('${app.settings.server}/ketentuan'),
            external: true,
          ),
        ],
      );
}

const _ok = Color(0xFF3ECF8E);

// ---------------- Komponen halaman utama ----------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.clearLabel, required this.onChanged});
  final TextEditingController controller;
  final String hint, clearLabel;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: (_) => onChanged(),
        textInputAction: TextInputAction.search,
        style: Rave.body(size: 15),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search_rounded, color: context.rc.muted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: clearLabel,
                  onPressed: () {
                    controller.clear();
                    onChanged();
                  },
                  icon: Icon(Icons.close_rounded, color: context.rc.muted),
                ),
        ),
      );
}

/// Kartu profil: avatar, nama + badge Verified, email, paket — ketuk = Edit profil.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onEdit});
  final Me user;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final rc = context.rc;
    return Semantics(
      button: true,
      label: '${user.displayName}, ${s.editProfile}',
      child: InkWell(
        key: const ValueKey('profile-card'),
        onTap: onEdit,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: rc.card, border: Border.all(color: rc.cardBorder), boxShadow: rc.isLight ? rc.hard(4) : null),
          child: Row(children: [
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(clipBehavior: Clip.none, children: [
                DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Rave.mustard, width: 2)),
                  child: Padding(padding: const EdgeInsets.all(2), child: Cover(user.avatarUrl, size: 52, round: true)),
                ),
                if (user.verified) const Positioned(right: -3, bottom: -3, child: VerifiedBadge(size: 22)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 17, weight: FontWeight.w800))),
                  if (user.verified) ...[const SizedBox(width: 6), const VerifiedBadge(size: 16)],
                ]),
                const SizedBox(height: 2),
                Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, color: rc.muted)),
                const SizedBox(height: 8),
                _PlanTag(premium: user.premium, label: user.premium ? s.premiumActive : s.free),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: rc.muted),
          ]),
        ),
      ),
    );
  }
}

class _PlanTag extends StatelessWidget {
  const _PlanTag({required this.premium, required this.label});
  final bool premium;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: premium ? Rave.mustard : Colors.transparent,
          border: Border.all(color: premium ? Rave.ink : context.rc.chipBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (premium) ...[const Icon(Icons.workspace_premium_rounded, size: 12, color: Rave.ink), const SizedBox(width: 4)],
          Flexible(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.label(size: 9.5, color: premium ? Rave.ink : context.rc.muted))),
        ]),
      );
}

/// Akun Gratis: satu banner ringkas (menggantikan bagian Kualitas audio & Equalizer di halaman utama).
class _PremiumBanner extends StatelessWidget {
  const _PremiumBanner({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return InkWell(
      key: const ValueKey('premium-banner'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(color: Rave.purple, border: Border.all(color: Rave.ink, width: 2), boxShadow: context.rc.hard(3)),
        child: Row(children: [
          const Icon(Icons.workspace_premium_rounded, color: Rave.mustard, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.premiumAudioTitle, style: Rave.body(size: 14.5, weight: FontWeight.w800, color: Rave.paper)),
              const SizedBox(height: 2),
              Text(s.premiumAudioBody, style: Rave.body(size: 12, color: const Color(0xCCF2EEE6), height: 1.3)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2)),
            child: Text(s.premium.toUpperCase(), style: Rave.label(size: 10, color: Rave.ink)),
          ),
        ]),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return InkWell(
      key: const ValueKey('logout'),
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(color: rc.card, border: Border.all(color: rc.isLight ? Rave.ink : rc.cardBorder, width: rc.isLight ? 2 : 1)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.logout_rounded, size: 18, color: rc.text),
          const SizedBox(width: 8),
          Text(label, style: Rave.body(size: 15, weight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.on, required this.onLabel, required this.offLabel});
  final bool on;
  final String onLabel, offLabel;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: on ? _ok.withValues(alpha: 0.14) : Colors.transparent, border: Border.all(color: on ? _ok.withValues(alpha: 0.6) : context.rc.chipBorder)),
        child: Text((on ? onLabel : offLabel).toUpperCase(), style: Rave.label(size: 9, color: on ? _ok : context.rc.muted)),
      );
}

class _PremiumTag extends StatelessWidget {
  const _PremiumTag({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(border: Border.all(color: context.rc.accent.withValues(alpha: 0.6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_rounded, size: 10, color: context.rc.accent),
          const SizedBox(width: 3),
          Text(label.toUpperCase(), style: Rave.label(size: 9, color: context.rc.accent)),
        ]),
      );
}

/// Pilihan bersegmen ringkas (mis. bahasa ID/EN).
class _Segmented extends StatelessWidget {
  const _Segmented({required this.value, required this.options, required this.onChanged, this.semantic = const {}});
  final String value;
  final List<(String, String)> options;
  final Map<String, String> semantic;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: rc.isLight ? Rave.ink : rc.chipBorder, width: rc.isLight ? 2 : 1)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final (k, label) in options)
          Semantics(
            selected: value == k,
            button: true,
            label: semantic[k] ?? label,
            child: GestureDetector(
              onTap: () => onChanged(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                color: value == k ? Rave.mustard : Colors.transparent,
                child: ExcludeSemantics(child: Text(label, style: Rave.label(size: 11, color: value == k ? Rave.ink : rc.muted))),
              ),
            ),
          ),
      ]),
    );
  }
}

// ---------------- Sub-halaman ----------------

/// Kerangka sub-halaman pengaturan: judul + daftar bagian.
class _SubPage extends StatelessWidget {
  const _SubPage({required this.title, required this.children, this.intro});
  final String title;
  final String? intro;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title.toUpperCase(), style: Rave.poster(24))),
        body: ListView(physics: raveVerticalPhysics, padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
          if (intro != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(intro!, style: Rave.body(size: 13, color: context.rc.muted, height: 1.4))),
          ...children,
        ]),
      );
}

class _QualityPage extends StatelessWidget {
  const _QualityPage({required this.policy, required this.onPremium});
  final QualityPolicy policy;
  final VoidCallback onPremium;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.api]),
      builder: (context, _) {
        final premium = app.api.user?.premium ?? false;
        final cur = app.settings.quality;
        return _SubPage(title: s.section('audio'), intro: s.qualityRowHint, children: [
          SettingsSection(title: s.quality, icon: Icons.graphic_eq_rounded, rows: [
            for (final v in policy.options)
              SettingsRow(
                label: s.q(v),
                desc: v == 'lossless' ? s.losslessCap(policy.losslessRes) : s.qDesc(v),
                onTap: policy.locked(v, premium: premium) ? null : () => app.settings.setQuality(v),
                leading: _Radio(selected: cur == v, locked: policy.locked(v, premium: premium)),
                status: policy.locked(v, premium: premium) ? _PremiumTag(label: s.premium) : null,
              ),
          ]),
          if (!premium) ...[
            const SizedBox(height: 14),
            Text(s.freeQualityNote(s.q(policy.freeMax)), style: Rave.body(size: 12.5, color: context.rc.muted)),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: DialogButton(label: s.premiumQualityCta, variant: DialogVariant.primary, onTap: onPremium)),
          ],
        ]);
      },
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.locked});
  final bool selected, locked;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: locked ? 0.4 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: selected ? Rave.mustard : Colors.transparent, border: Border.all(color: selected ? Rave.ink : context.rc.subtle, width: 2)),
          child: selected ? const Icon(Icons.check_rounded, size: 14, color: Rave.ink) : null,
        ),
      );
}

class _EqPage extends StatefulWidget {
  const _EqPage();
  @override
  State<_EqPage> createState() => _EqPageState();
}

class _EqPageState extends State<_EqPage> {
  /// Gain pita selama slider digeser (disimpan saat dilepas).
  final _drag = <int, double>{};

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: Listenable.merge([app.settings, app.player]),
      builder: (context, _) {
        final p = app.player;
        final params = p.eqParams;
        final on = app.settings.eqOn;
        Widget body;
        if (!p.eqSupported) {
          body = Text(s.eqUnavailable, style: Rave.body(size: 13, color: context.rc.muted));
        } else if (params == null) {
          body = Text(s.eqWaiting, style: Rave.body(size: 13, color: context.rc.muted));
        } else {
          final gains = p.eqGainsFor(params);
          final preset = app.settings.eqPreset;
          double g(int i) => (_drag[i] ?? (i < gains.length ? gains[i] : 0)).clamp(params.minDecibels, params.maxDecibels).toDouble();
          body = Opacity(
            opacity: on ? 1 : 0.5,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!on) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(s.eqOffNote, style: Rave.body(size: 12.5, color: context.rc.muted))),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final k in [...eqPresets.keys, if (preset == 'custom') 'custom'])
                  RaveChip(label: s.eqPreset(k), selected: preset == k, onTap: on && k != 'custom' ? () => app.settings.setEq(preset: k) : () {}),
              ]),
              const SizedBox(height: 12),
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
                        value: g(i),
                        semanticFormatterCallback: (v) => '${fmtHz(params.bands[i].centerFrequency)} Hz ${v.toStringAsFixed(1)} dB',
                        onChanged: on ? (v) => setState(() => _drag[i] = v) : null,
                        onChangeEnd: on
                            ? (v) {
                                final next = [...gains];
                                if (i < next.length) next[i] = v;
                                _drag.clear();
                                app.settings.setEq(preset: 'custom', gains: next);
                              }
                            : null,
                      ),
                    ),
                  ),
                  SizedBox(width: 52, child: Text('${g(i) > 0 ? '+' : ''}${g(i).toStringAsFixed(1)} dB', textAlign: TextAlign.right, style: Rave.label(size: 10, color: context.rc.text))),
                ]),
              Align(alignment: Alignment.centerRight, child: OutlineButton(label: s.eqReset, onTap: on ? () => app.settings.setEq(preset: 'flat') : null)),
            ]),
          );
        }
        return _SubPage(title: 'Equalizer', intro: s.eqHint, children: [
          SettingsSection(title: 'Equalizer', icon: Icons.tune_rounded, rows: [
            SettingsRow(
              label: s.eqRow,
              trailing: RaveSwitch(label: s.eqRow, value: on, onChanged: p.eqSupported ? (v) => app.settings.setBool('eqOn', v) : null),
              below: body,
            ),
          ]),
        ]);
      },
    );
  }
}

class _ServerPage extends StatelessWidget {
  const _ServerPage();
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return _SubPage(title: s.server, intro: s.serverHint, children: [
      SettingsSection(title: s.server, icon: Icons.dns_rounded, rows: [SettingsRow(label: s.server, below: const ServerEditor())]),
    ]);
  }
}

/// Notifikasi per kategori × kanal tambahan (`/v1/notifications/preferences`, sama dengan web).
class _NotificationsPage extends StatefulWidget {
  const _NotificationsPage();
  @override
  State<_NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<_NotificationsPage> {
  static const categories = ['event', 'release', 'payment', 'booking', 'system', 'social'];
  static const channels = [('push', 'Push'), ('email', 'Email'), ('whatsapp', 'WhatsApp')];
  Map<String, Json>? prefs;
  bool failed = false;

  /// Bawaan server bila belum ada baris: push aktif, email hanya booking/pembayaran, WhatsApp mati.
  static Json _default(String c) => {'category': c, 'push': true, 'email': c == 'booking' || c == 'payment', 'whatsapp': false, 'quiet_start': null, 'quiet_end': null};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() => failed = false);
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
    return _SubPage(title: s.section('notifications'), intro: s.notifIntro, children: [
      if (failed)
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(children: [
            Text(s.notifFailed, textAlign: TextAlign.center, style: Rave.body(color: context.rc.muted)),
            const SizedBox(height: 12),
            OutlineButton(label: s.retry, onTap: _load),
          ]),
        )
      else if (p == null)
        const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
      else
        SettingsSection(title: s.notifChannels, icon: Icons.notifications_rounded, rows: [
          for (final c in categories)
            SettingsRow(
              label: s.notifCategory(c).name,
              desc: s.notifCategory(c).desc,
              below: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (ch, label) in channels) RaveChip(label: label, icon: p[c]![ch] == true ? Icons.check_rounded : null, selected: p[c]![ch] == true, onTap: () => _set(c, ch, p[c]![ch] != true)),
              ]),
            ),
        ]),
    ]);
  }
}

/// Privasi & data (UU PDP, BRD §8.2 / IAM-07): persetujuan per tujuan (PUT /v1/me/consents).
class _PrivacyPage extends StatefulWidget {
  const _PrivacyPage();
  @override
  State<_PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<_PrivacyPage> {
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
    return _SubPage(title: s.privacy, intro: s.privacyHint, children: [
      SettingsSection(title: s.consentsTitle, icon: Icons.shield_rounded, rows: [
        for (final p in purposes)
          SettingsRow(
            label: s.consentLabel(p),
            desc: s.consentDesc(p),
            trailing: RaveSwitch(label: s.consentLabel(p), value: g?[p] ?? false, onChanged: g == null ? null : (v) => _set(p, v)),
          ),
      ]),
    ]);
  }
}

// ---------------- Bersama (juga dipakai Edit profil) ----------------

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
                Positioned(left: 6, top: 8, width: 14, bottom: 9, child: Container(decoration: BoxDecoration(color: light ? Rave.teal : Rave.purple, border: Border.all(color: Rave.ink)))),
                Positioned(left: 26, right: 6, top: 10, height: 4, child: ColoredBox(color: light ? Rave.ink : Rave.paper)),
                Positioned(left: 26, width: 16, top: 20, height: 4, child: const ColoredBox(color: Rave.mustard)),
              ]),
            ),
          );
      return Container(
        height: 46,
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: rc.isLight ? rc.base : Colors.transparent,
                  border: Border.all(color: value == k ? Rave.mustard : rc.chipBorder, width: value == k ? 2 : 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  preview(k),
                  const SizedBox(height: 7),
                  Row(children: [
                    Expanded(child: Text(s.themeName(k), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, weight: FontWeight.w700))),
                    if (value == k) const Icon(Icons.check_circle_rounded, size: 14, color: Rave.mustard),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

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

/// Satu baris pengaturan: [icon]/[leading] · label + deskripsi · [status] · kontrol ([trailing]) atau penunjuk
/// ([chevron] = sub-halaman, [external] = dibuka di browser); kontrol lebar di bawah ([below]).
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.desc,
    this.keywords,
    this.trailing,
    this.below,
    this.leading,
    this.labelTrailing,
    this.onTap,
    this.icon,
    this.iconColor,
    this.status,
    this.chevron = false,
    this.external = false,
  });
  final String label;
  final String? desc, keywords;
  final Widget? trailing, below, leading;

  /// Widget kecil tepat setelah label (mis. badge Verified di samping nama).
  final Widget? labelTrailing;

  /// Seluruh baris dapat diketuk (mis. membuka sub-layar).
  final VoidCallback? onTap;

  /// Ikon baris dalam kotak lembut (alternatif [leading]).
  final IconData? icon;
  final Color? iconColor;

  /// Penanda kecil di kanan (mis. status Aktif/Nonaktif, tag Premium).
  final Widget? status;
  final bool chevron, external;

  bool matches(String q) => settingsMatch(q, [label, desc, keywords]);

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final title = Text(label, maxLines: labelTrailing == null ? null : 1, overflow: labelTrailing == null ? null : TextOverflow.ellipsis, style: Rave.body(size: 15, weight: FontWeight.w700));
    final lead = leading ??
        (icon == null
            ? null
            : Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: rc.isLight ? const Color(0x0F181818) : const Color(0x12FFFFFF), border: Border.all(color: rc.isLight ? const Color(0x22181818) : const Color(0x1FFFFFFF))),
                child: Icon(icon, size: 18, color: iconColor ?? rc.text),
              ));
    final Widget row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (lead != null) ...[lead, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (labelTrailing == null) title else Row(children: [Flexible(child: title), const SizedBox(width: 6), labelTrailing!]),
              if (desc != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(desc!, style: Rave.body(size: 12.5, color: rc.muted, height: 1.35))),
            ]),
          ),
          if (status != null) ...[const SizedBox(width: 10), status!],
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
          if (chevron) ...[const SizedBox(width: 6), Icon(Icons.chevron_right_rounded, color: rc.muted)],
          if (external) ...[const SizedBox(width: 8), Icon(Icons.open_in_new_rounded, size: 16, color: rc.muted)],
        ]),
        if (below != null) ...[const SizedBox(height: 12), below!],
      ]),
    );
    return onTap == null ? row : InkWell(onTap: onTap, child: row);
  }
}

/// Bagian pengaturan: judul kecil (label kapital) + kartu berisi baris bergaris pemisah.
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
    final rc = context.rc;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(children: [
            Container(width: 10, height: 10, color: danger ? Rave.berry : Rave.mustard),
            const SizedBox(width: 8),
            Expanded(child: Text(title.toUpperCase(), style: Rave.label(size: 11, color: danger ? const Color(0xFFE0566E) : rc.muted))),
          ]),
        ),
        Container(
          decoration: BoxDecoration(
            color: rc.card,
            border: Border.all(color: danger ? (rc.isLight ? Rave.berry : const Color(0xB38A2F3F)) : rc.cardBorder),
            boxShadow: rc.isLight ? rc.hard(4) : null,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < shown.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: shown[i].icon != null || shown[i].leading != null ? 60 : 14, color: rc.isLight ? const Color(0x14181818) : const Color(0x14FFFFFF)),
              shown[i],
            ],
          ]),
        ),
      ]),
    );
  }
}
