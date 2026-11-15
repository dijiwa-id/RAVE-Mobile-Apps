import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/social_login.dart';
import '../core/theme.dart';
import '../widgets/brand_marks.dart';
import '../widgets/common.dart';

/// Buka layar Masuk/Daftar (aplikasi tetap bisa dipakai sebagai tamu). Mengembalikan true bila berhasil masuk.
/// [signUp]: buka dalam mode Daftar (judul berbeda; alurnya sama — OTP membuat akun baru otomatis).
Future<bool> openLogin(BuildContext context, {bool signUp = false}) async {
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => LoginScreen(signUp: signUp)),
  );
  return ok == true;
}

/// Minta tamu masuk dulu untuk fitur pribadi (Disukai, Pustaka, ikuti).
Future<bool> requireLogin(BuildContext context) async {
  final app = App.read(context);
  if (app.api.authed) return true;
  final s = app.s;
  final go = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.guestTitle.toUpperCase(), style: Rave.poster(30)),
          const SizedBox(height: 8),
          Text(s.guestBody, style: Rave.body(color: context.rc.muted)),
          const SizedBox(height: 20),
          PrimaryButton(label: s.signInOrUp, onTap: () => Navigator.pop(sheet, 'login')),
        ]),
      ),
    ),
  );
  if (go == null || !context.mounted) return false;
  return openLogin(context);
}

/// Masuk / Daftar dengan OTP email (IAM RAVE hanya OTP — akun baru dibuat otomatis saat kode diverifikasi).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.signUp = false});
  final bool signUp;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false, _busy = false;
  String? _err, _dev;
  List<String> _providers = const [];
  String? _socialBusy;
  SocialLoginFlow? _flow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Hanya provider yang diaktifkan server yang tampil (tanpa jaringan → bagian sosial disembunyikan).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final list = await App.read(context).api.socialProviders();
        if (mounted) setState(() => _providers = list);
      } catch (_) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Di latar belakang (pengguna di browser) polling dijeda; kembali ke aplikasi → langsung periksa.
    if (state == AppLifecycleState.resumed) {
      _flow?.resume();
    } else if (state == AppLifecycleState.paused) {
      _flow?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flow?.dispose();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  /// Setelah sesi tersimpan (OTP atau sosial): bahasa akun, cache, onboarding, tutup layar.
  Future<void> _afterLogin() async {
    final app = App.read(context);
    final loc = app.api.user?.locale;
    if (loc != null) await app.settings.setLocale(loc);
    app.cache.clear();
    app.likes.reset();
    await syncOnboarding(app);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _social(String provider) async {
    final app = App.read(context);
    final s = app.s;
    setState(() => (_socialBusy = provider, _err = null));
    try {
      final launch = await app.api.startSocial(provider);
      final url = app.api.socialStartUrl(launch);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) throw const _BrowserFail();
      final flow = SocialLoginFlow(launch, poll: app.api.pollSocial, onDone: app.api.saveSession)..start();
      _flow?.dispose();
      _flow = flow;
      if (!mounted) return;
      final done = await showModalBottomSheet<bool>(
        context: context,
        isDismissible: false,
        enableDrag: false,
        showDragHandle: true,
        builder: (_) => _SocialWaitSheet(flow: flow, label: _providerLabel(s, provider), onReopen: () => launchUrl(url, mode: LaunchMode.externalApplication)),
      );
      flow.cancel();
      if (done == true) {
        await _afterLogin();
      } else if (mounted && (flow.state == SocialPollState.error || flow.state == SocialPollState.expired)) {
        setState(() => _err = flow.message ?? (flow.state == SocialPollState.expired ? s.socialExpired : s.genericError));
      }
    } catch (e) {
      if (mounted) setState(() => _err = e is _BrowserFail ? s.socialBrowserFailed : friendlyError(s, e));
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  Future<void> _send() async {
    final app = App.read(context);
    setState(() => (_busy = true, _err = null));
    try {
      _dev = await app.api.sendOtp(_email.text);
      if (mounted) setState(() => _codeStep = true);
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(app.s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final app = App.read(context);
    setState(() => (_busy = true, _err = null));
    try {
      await app.api.verifyOtp(_email.text, _code.text);
      await _afterLogin();
    } catch (e) {
      if (mounted) setState(() => _err = friendlyError(app.s, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final emailOk = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
    return Scaffold(
      appBar: AppBar(leading: IconButton(tooltip: MaterialLocalizations.of(context).closeButtonTooltip, icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context, false))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 24), children: [
          Image.asset(context.rc.isLight ? 'assets/brand/rave-logo-dark.webp' : 'assets/brand/rave-logo.webp', height: 36, alignment: Alignment.centerLeft),
          const SizedBox(height: 28),
          Transform.rotate(
            angle: -0.06,
            alignment: Alignment.centerLeft,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: context.rc.isLight ? Rave.ink : Rave.paper, width: 2), boxShadow: context.rc.hard()),
                child: Text('DIY · INDIE · LIVE', style: Rave.label(size: 10, color: Rave.ink)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text((widget.signUp ? s.signUpTitle : s.authTitle).toUpperCase(), style: Rave.poster(44)),
          const SizedBox(height: 8),
          Text(s.authBody, style: Rave.body(color: context.rc.muted)),
          const SizedBox(height: 28),
          if (!_codeStep) ...[
            Eyebrow(s.email),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.send,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => emailOk ? _send() : null,
              style: Rave.body(size: 16),
              decoration: InputDecoration(hintText: s.emailHint),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: s.sendCode, busy: _busy, onTap: emailOk ? _send : null),
            if (_providers.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(children: [
                Expanded(child: Divider(color: context.rc.isLight ? context.rc.chipBorder : Rave.line)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(s.orContinueWith.toUpperCase(), style: Rave.label(size: 10, color: context.rc.muted))),
                Expanded(child: Divider(color: context.rc.isLight ? context.rc.chipBorder : Rave.line)),
              ]),
              const SizedBox(height: 14),
              for (final p in _providers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SocialButton(provider: p, label: _providerLabel(s, p), semantic: s.continueWith(_providerLabel(s, p)), busy: _socialBusy == p, onTap: _socialBusy == null && !_busy ? () => _social(p) : null),
                ),
            ],
          ] else ...[
            Text(s.codeSent(_email.text.trim()), style: Rave.body(color: context.rc.muted)),
            if (_dev != null) Padding(padding: const EdgeInsets.only(top: 6), child: Eyebrow(s.devCode(_dev!), color: context.rc.accent)),
            const SizedBox(height: 14),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: 6,
              textAlign: TextAlign.center,
              onChanged: (v) {
                setState(() {});
                if (v.length == 6) _verify();
              },
              style: const TextStyle(fontFamily: Rave.mono, fontSize: 26, letterSpacing: 12),
              decoration: const InputDecoration(counterText: ''),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: s.signIn, busy: _busy, onTap: _code.text.length == 6 ? _verify : null),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(onPressed: () => setState(() => (_codeStep = false, _code.text = '', _err = null)), child: Text(s.changeEmail, style: Rave.body(color: context.rc.muted))),
              TextButton(onPressed: _busy ? null : _send, child: Text(s.resend, style: Rave.body(color: context.rc.muted))),
            ]),
          ],
          if (_err != null)
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: Color(0x268A2F3F), border: Border(left: BorderSide(color: Rave.berry, width: 4))),
              child: Text(_err!, style: Rave.body(size: 13)),
            ),
          const SizedBox(height: 24),
          const SizedBox(height: 8),
          Center(child: Text('${s.server}: ${app.settings.server.replaceFirst(RegExp(r'^https?://'), '')}', style: Rave.label(size: 9.5, color: context.rc.subtle))),
        ]),
      ),
    );
  }
}

String _providerLabel(S s, String p) => switch (p) { 'google' => 'Google', 'apple' => 'Apple', 'facebook' => 'Facebook', _ => s.devProvider };

/// Tombol provider: kotak bergaris tebal dengan ikon merek (ikon Material; tanpa paket ikon tambahan).
class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.provider, required this.label, required this.semantic, required this.busy, required this.onTap});
  final String provider, label, semantic;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final Widget icon = switch (provider) {
      'google' => const GoogleLogo(size: 20),
      'apple' => Icon(Icons.apple, size: 22, color: rc.text),
      'facebook' => const Icon(Icons.facebook, size: 22, color: Color(0xFF1877F2)),
      _ => Icon(Icons.science_outlined, size: 20, color: rc.accent),
    };
    return Semantics(
      button: true,
      label: semantic,
      child: Opacity(
        opacity: onTap == null && !busy ? 0.5 : 1,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 50,
            decoration: BoxDecoration(border: Border.all(color: rc.isLight ? Rave.ink : Rave.paper, width: 2), color: rc.isLight ? Colors.white : const Color(0xFF181818)),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              SizedBox(width: 24, child: Center(child: busy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: rc.text)) : icon)),
              const SizedBox(width: 10),
              ExcludeSemantics(child: Text(label, style: Rave.body(size: 15, color: rc.text).copyWith(fontWeight: FontWeight.w700))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Lembar tunggu: kode pencocokan (sama dengan halaman browser), Buka browser lagi, Batal. Tutup sendiri saat selesai.
class _SocialWaitSheet extends StatefulWidget {
  const _SocialWaitSheet({required this.flow, required this.label, required this.onReopen});
  final SocialLoginFlow flow;
  final String label;
  final VoidCallback onReopen;
  @override
  State<_SocialWaitSheet> createState() => _SocialWaitSheetState();
}

class _SocialWaitSheetState extends State<_SocialWaitSheet> {
  @override
  void initState() {
    super.initState();
    widget.flow.addListener(_changed);
  }

  @override
  void dispose() {
    widget.flow.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (widget.flow.finished && mounted) Navigator.pop(context, widget.flow.state == SocialPollState.done);
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final rc = context.rc;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.socialWaitTitle(widget.label).toUpperCase(), style: Rave.poster(30)),
          const SizedBox(height: 8),
          Text(s.socialWaitBody, style: Rave.body(color: rc.muted)),
          const SizedBox(height: 18),
          Eyebrow(s.socialMatchCode),
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(border: Border.all(color: Rave.mustard, width: 2)),
              child: SelectableText(widget.flow.launch.userCode, style: const TextStyle(fontFamily: Rave.mono, fontSize: 26, letterSpacing: 6, fontWeight: FontWeight.w700, color: Rave.mustard)),
            ),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: rc.muted)),
            const SizedBox(width: 8),
            Text(s.socialWaiting, style: Rave.body(size: 13, color: rc.muted)),
          ]),
          const SizedBox(height: 18),
          PrimaryButton(label: s.socialReopen, onTap: widget.onReopen),
          const SizedBox(height: 6),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel, style: Rave.body(color: rc.muted))),
        ]),
      ),
    );
  }
}

class _BrowserFail implements Exception {
  const _BrowserFail();
}
