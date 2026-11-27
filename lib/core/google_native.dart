import 'package:flutter/foundation.dart';
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

  /// Client ID yang terbukti gagal di perangkat ini (mis. SHA-1 belum terdaftar) — ketukan berikutnya di sesi ini
  /// langsung ke alur browser tanpa menunggu lembar akun gagal lagi.
  static String? _unavailableFor;

  static Future<GoogleNativeResult> signIn(String serverClientId) async {
    final o = override;
    if (o != null) return o(serverClientId);
    if (_unavailableFor == serverClientId) return const GoogleNativeUnavailable('gagal sebelumnya di sesi ini');
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
      final r = classifyGoogleError(e.code, e.description);
      if (r is GoogleNativeUnavailable) _unavailableFor = serverClientId;
      return r;
    } catch (e) {
      _unavailableFor = serverClientId;
      return GoogleNativeUnavailable(e.toString());
    }
  }

  /// Petakan galat `google_sign_in` → hasil. Credential Manager melaporkan salah konfigurasi (klien OAuth Android /
  /// SHA-1 sertifikat belum didaftarkan di Google Cloud) sebagai *pembatalan* — `[16] Account reauth failed` — sehingga
  /// tanpa pemetaan ini tombol Google diam saja. Hanya pembatalan sungguhan oleh pengguna yang dianggap batal.
  @visibleForTesting
  static GoogleNativeResult classifyGoogleError(GoogleSignInExceptionCode code, String? description) {
    final d = (description ?? '').toLowerCase();
    if (code == GoogleSignInExceptionCode.canceled && !_looksMisconfigured(d)) return const GoogleNativeCanceled();
    return GoogleNativeUnavailable('${code.name}: ${description ?? ''}');
  }

  static bool _looksMisconfigured(String d) =>
      d.contains('[16]') || d.contains('[10]') || d.contains('reauth') || d.contains('developer_error') || d.contains('developer console');

  /// Keluar dari RAVE → lupakan pilihan akun agar login berikutnya menampilkan pemilih akun lagi.
  static Future<void> signOut() async {
    if (override != null || _initializedFor == null) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
