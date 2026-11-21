import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/social_login.dart';

/// Verifikasi 2 langkah (2FA): tantangan dari faktor pertama (OTP / login sosial) & status di profil.
void main() {
  test('tantangan 2FA dikenali dari respons token', () {
    final m = MfaRequired.from({'mfa_required': true, 'mfa_token': 'tok-123456789012345678901', 'methods': ['totp', 'recovery'], 'expires_in': 300});
    expect((m?.token, m?.expiresIn), ('tok-123456789012345678901', 300));
    expect(MfaRequired.from({'access_token': 'a', 'refresh_token': 'r', 'user': {}}), isNull);
  });

  test('polling login sosial: tantangan 2FA = selesai (dilanjutkan di layar Masuk), bukan kedaluwarsa', () {
    final r = socialPollFromResponse(200, {'mfa_required': true, 'mfa_token': 'x' * 30, 'methods': ['totp'], 'expires_in': 300});
    expect(r.state, SocialPollState.done);
    expect(MfaRequired.from(r.tokens!)?.token, 'x' * 30);
  });

  test('status 2FA di profil (totp_enabled / mfa_enabled) ikut tersimpan', () {
    final on = Me.fromJson({'id': 'u', 'email': 'a@b.id', 'display_name': 'A', 'totp_enabled': true});
    expect(on.totpEnabled, isTrue);
    expect(Me.fromJson(on.toJson()).totpEnabled, isTrue);
    expect(Me.fromJson({'id': 'u', 'email': 'a@b.id', 'display_name': 'A', 'mfa_enabled': true}).totpEnabled, isTrue);
    expect(Me.fromJson({'id': 'u', 'email': 'a@b.id', 'display_name': 'A'}).totpEnabled, isFalse);
  });
}
