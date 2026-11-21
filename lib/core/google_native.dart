import 'package:google_sign_in/google_sign_in.dart';

/// Hasil lembar akun Google native (Credential Manager Android): pengguna memilih akun yang sudah tersinkron di ponsel
/// tanpa meninggalkan aplikasi; RAVE menerima ID token untuk diverifikasi server (`/v1/auth/oauth/google/native`).
sealed class GoogleNativeResult {
  const GoogleNativeResult();
}

class GoogleNativeToken extends GoogleNativeResult {
  const GoogleNativeToken(this.idToken);
  final String idToken;
}

/// Pengguna menutup lembar akun — tidak perlu pesan galat.
class GoogleNativeCanceled extends GoogleNativeResult {
  const GoogleNativeCanceled();
}

/// Login native tidak tersedia di perangkat/konfigurasi ini (mis. klien OAuth Android belum didaftarkan di Google Cloud,
/// tanpa Layanan Google Play) → aplikasi memakai alur browser dalam aplikasi sebagai cadangan.
class GoogleNativeUnavailable extends GoogleNativeResult {
  const GoogleNativeUnavailable(this.reason);
  final String reason;
}

/// Pembungkus `google_sign_in` 7 — dapat diganti di uji (lihat [GoogleNative.override]).
class GoogleNative {
  GoogleNative._();
  static Future<GoogleNativeResult> Function(String serverClientId)? override;
  static String? _initializedFor;

  static Future<GoogleNativeResult> signIn(String serverClientId) async {
    final o = override;
    if (o != null) return o(serverClientId);
    final g = GoogleSignIn.instance;
    try {
      if (_initializedFor != serverClientId) {
        await g.initialize(serverClientId: serverClientId);
        _initializedFor = serverClientId;
      }
      if (!g.supportsAuthenticate()) return const GoogleNativeUnavailable('authenticate tidak didukung');
      final account = await g.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) return const GoogleNativeUnavailable('ID token kosong');
      return GoogleNativeToken(token);
    } on GoogleSignInException catch (e) {
      return switch (e.code) {
        GoogleSignInExceptionCode.canceled => const GoogleNativeCanceled(),
        _ => GoogleNativeUnavailable('${e.code.name}: ${e.description ?? ''}'),
      };
    } catch (e) {
      return GoogleNativeUnavailable(e.toString());
    }
  }

  /// Keluar dari RAVE → lupakan pilihan akun agar login berikutnya menampilkan pemilih akun lagi.
  static Future<void> signOut() async {
    if (override != null || _initializedFor == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
