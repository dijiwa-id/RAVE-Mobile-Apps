import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Buka layar Masuk/Daftar (aplikasi tetap bisa dipakai sebagai tamu). Mengembalikan true bila berhasil masuk.
Future<bool> openLogin(BuildContext context, {bool signup = false}) async {
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => LoginScreen(signup: signup)),
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
          Text(s.guestBody, style: Rave.body(color: Rave.muted)),
          const SizedBox(height: 20),
          PrimaryButton(label: s.signup, onTap: () => Navigator.pop(sheet, 'signup')),
          const SizedBox(height: 10),
          Center(child: OutlineButton(label: s.signIn, onTap: () => Navigator.pop(sheet, 'login'))),
        ]),
      ),
    ),
  );
  if (go == null || !context.mounted) return false;
  return openLogin(context, signup: go == 'signup');
}

/// Masuk / Daftar dengan OTP email (IAM RAVE hanya OTP — akun baru dibuat otomatis saat kode diverifikasi).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.signup = false});
  final bool signup;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStep = false, _busy = false;
  String? _err, _dev;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final app = App.read(context);
    setState(() => (_busy = true, _err = null));
    try {
      _dev = await app.api.sendOtp(_email.text);
      setState(() => _codeStep = true);
    } catch (e) {
      setState(() => _err = e is OfflineError ? app.s.offline : e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final app = App.read(context);
    setState(() => (_busy = true, _err = null));
    try {
      await app.api.verifyOtp(_email.text, _code.text);
      final loc = app.api.user?.locale;
      if (loc != null) await app.settings.setLocale(loc);
      app.cache.clear();
      app.likes.reset();
      await syncOnboarding(app);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _err = e is OfflineError ? app.s.offline : e.toString());
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
          Image.asset('assets/brand/rave-logo.webp', height: 36, alignment: Alignment.centerLeft),
          const SizedBox(height: 28),
          Transform.rotate(
            angle: -0.06,
            alignment: Alignment.centerLeft,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                child: Text('DIY · INDIE · LIVE', style: Rave.label(size: 10, color: Rave.ink)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text((widget.signup ? s.signupTitle : s.loginTitle).toUpperCase(), style: Rave.poster(44)),
          const SizedBox(height: 8),
          Text(widget.signup ? s.signupBody : s.tagline, style: Rave.body(color: Rave.muted)),
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
          ] else ...[
            Text(s.codeSent(_email.text.trim()), style: Rave.body(color: Rave.muted)),
            if (_dev != null) Padding(padding: const EdgeInsets.only(top: 6), child: Eyebrow(s.devCode(_dev!), color: Rave.mustard)),
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
            PrimaryButton(label: widget.signup ? s.signupCta : s.signIn, busy: _busy, onTap: _code.text.length == 6 ? _verify : null),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              TextButton(onPressed: () => setState(() => (_codeStep = false, _code.text = '', _err = null)), child: Text(s.changeEmail, style: Rave.body(color: Rave.muted))),
              TextButton(onPressed: _busy ? null : _send, child: Text(s.resend, style: Rave.body(color: Rave.muted))),
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
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => LoginScreen(signup: !widget.signup))),
              child: Text(widget.signup ? s.haveAccount : s.noAccount, style: Rave.body(weight: FontWeight.w700, color: Rave.mustard)),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Text('${s.server}: ${app.settings.server.replaceFirst(RegExp(r'^https?://'), '')}', style: Rave.label(size: 9.5, color: Rave.subtle))),
        ]),
      ),
    );
  }
}
