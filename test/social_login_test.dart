import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rave_mobile/core/google_native.dart';
import 'package:rave_mobile/core/social_login.dart';

const launch = SocialLaunch(provider: 'dev', startPath: '/v1/auth/oauth/dev/start?app=x', pollToken: 'poll-token-xyz', userCode: 'ABCD-2345', expiresIn: 600, interval: 2);

void main() {
  group('pemetaan respons polling', () {
    test('428 → menunggu, 200 → token, 400 → gagal + pesan, 410 → kedaluwarsa', () {
      expect(socialPollFromResponse(428, {'title': 'authorization_pending'}).state, SocialPollState.pending);
      final ok = socialPollFromResponse(200, {'access_token': 'a', 'refresh_token': 'r', 'user': {}});
      expect(ok.state, SocialPollState.done);
      expect(ok.tokens?['access_token'], 'a');
      final err = socialPollFromResponse(400, {'detail': 'Masuk dibatalkan.'});
      expect((err.state, err.message), (SocialPollState.error, 'Masuk dibatalkan.'));
      expect(socialPollFromResponse(410, {'detail': 'x'}).state, SocialPollState.expired);
      expect(socialPollFromResponse(200, {'oops': true}).state, SocialPollState.expired);
    });

    test('peluncuran dari JSON server (interval dibatasi 1–10 dtk)', () {
      final l = SocialLaunch.fromJson('google', {'start_path': '/s', 'poll_token': 'p', 'user_code': 'AAAA-BBBB', 'expires_in': 600, 'interval': 0});
      expect((l.provider, l.startPath, l.userCode, l.interval), ('google', '/s', 'AAAA-BBBB', 1));
    });
  });

  group('SocialLoginFlow', () {
    test('menunggu → selesai: token diteruskan sekali, flow berhenti & memberi tahu', () async {
      final queue = [
        const SocialPollResult(SocialPollState.pending),
        const SocialPollResult(SocialPollState.done, tokens: {'access_token': 'a'}),
      ];
      var polls = 0, saved = 0, notified = 0;
      final f = SocialLoginFlow(launch, poll: (t) async {
        expect(t, 'poll-token-xyz');
        polls++;
        return queue.removeAt(0);
      }, onDone: (tok) async => saved++);
      f.addListener(() => notified++);
      expect(await f.tick(), SocialPollState.pending);
      expect(await f.tick(), SocialPollState.done);
      expect(await f.tick(), SocialPollState.done); // sudah selesai: tidak polling lagi
      expect((polls, saved, notified, f.finished), (2, 1, 1, true));
      f.dispose();
    });

    test('galat jaringan → tetap menunggu; galat server → error dengan pesan', () async {
      var n = 0;
      final f = SocialLoginFlow(launch, poll: (_) async {
        if (n++ == 0) throw Exception('offline');
        return const SocialPollResult(SocialPollState.error, message: 'Provider menolak');
      }, onDone: (_) async {});
      expect(await f.tick(), SocialPollState.pending);
      expect(await f.tick(), SocialPollState.error);
      expect(f.message, 'Provider menolak');
      f.dispose();
    });

    test('lewat batas waktu → kedaluwarsa tanpa polling; dibatalkan → tidak polling', () async {
      var now = DateTime(2026, 11, 15, 12);
      var polls = 0;
      final f = SocialLoginFlow(launch, poll: (_) async {
        polls++;
        return const SocialPollResult(SocialPollState.pending);
      }, onDone: (_) async {}, now: () => now);
      now = now.add(const Duration(seconds: 601));
      expect(await f.tick(), SocialPollState.expired);
      expect(polls, 0);
      final g = SocialLoginFlow(launch, poll: (_) async {
        polls++;
        return const SocialPollResult(SocialPollState.pending);
      }, onDone: (_) async {});
      g.cancel();
      await g.tick();
      g.resume();
      expect(polls, 0);
      f.dispose();
      g.dispose();
    });
  });

  group('Google native: klasifikasi galat', () {
    test('batal oleh pengguna → Canceled (tanpa fallback)', () {
      expect(GoogleNative.classifyGoogleError(GoogleSignInExceptionCode.canceled, 'activity is cancelled by the user.'), isA<GoogleNativeCanceled>());
      expect(GoogleNative.classifyGoogleError(GoogleSignInExceptionCode.canceled, null), isA<GoogleNativeCanceled>());
    });
    test('SHA-1/klien Android belum terdaftar ("[16] Account reauth failed") → Unavailable → alur browser', () {
      expect(GoogleNative.classifyGoogleError(GoogleSignInExceptionCode.canceled, '[16] Account reauth failed.'), isA<GoogleNativeUnavailable>());
      expect(GoogleNative.classifyGoogleError(GoogleSignInExceptionCode.providerConfigurationError, 'x'), isA<GoogleNativeUnavailable>());
      expect(GoogleNative.classifyGoogleError(GoogleSignInExceptionCode.unknownError, 'No credential available'), isA<GoogleNativeUnavailable>());
    });
  });
}
