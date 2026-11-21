import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'google_native.dart';
import 'models.dart';
import 'social_login.dart';
import 'version.dart';
import 'settings.dart';

/// Galat RFC 9457 dari gateway RAVE.
class ApiError implements Exception {
  final int status;
  final String message;
  final Json problem;
  ApiError(this.status, this.message, [this.problem = const {}]);
  @override
  String toString() => message;
}

/// Faktor pertama sukses (OTP / login sosial) tetapi akun memakai verifikasi 2 langkah → selesaikan dengan [Api.verifyMfa].
class MfaRequired implements Exception {
  const MfaRequired(this.token, this.expiresIn);
  final String token;
  final int expiresIn;
  static MfaRequired? from(Json j) => j['mfa_required'] == true && j['mfa_token'] is String ? MfaRequired(j['mfa_token'] as String, (j['expires_in'] as num?)?.toInt() ?? 300) : null;
}

/// Server tidak terjangkau (offline, alamat salah, timeout).
class OfflineError implements Exception {
  const OfflineError();
}

/// Sesi & klien HTTP. Token disimpan di Keystore Android (flutter_secure_storage), bukan prefs biasa.
class Api extends ChangeNotifier {
  Api(this.settings) {
    settings.onLocaleChanged = (l) {
      if (authed) request<dynamic>('/v1/me', method: 'PATCH', body: {'locale': l}).catchError((_) => null);
    };
  }
  final Settings settings;
  final _store = const FlutterSecureStorage(aOptions: AndroidOptions());
  final _client = http.Client();

  String? _access;
  String? _refresh;
  Me? user;

  bool get authed => _access != null;

  /// Uji tata letak keadaan masuk tanpa jaringan/secure storage.
  @visibleForTesting
  set debugAccessToken(String? v) => _access = v;
  String get base => settings.server;

  Future<void> restore() async {
    _access = await _store.read(key: 'access');
    _refresh = await _store.read(key: 'refresh');
    final u = await _store.read(key: 'user');
    if (u != null) {
      try {
        user = Me.fromJson(jsonDecode(u) as Json);
      } catch (_) {
        // Data tersimpan rusak/format lama → jangan gagalkan start-up; profil dimuat ulang dari server.
        user = null;
        await _store.delete(key: 'user');
      }
    }
  }

  Future<void> _save(Json t) async {
    _access = t['access_token'];
    _refresh = t['refresh_token'];
    user = Me.fromJson(t['user'] as Json);
    await _store.write(key: 'access', value: _access);
    await _store.write(key: 'refresh', value: _refresh);
    await _store.write(key: 'user', value: jsonEncode(user!.toJson()));
    notifyListeners();
  }

  Future<void> setUser(Me u) async {
    user = u;
    await _store.write(key: 'user', value: jsonEncode(u.toJson()));
    notifyListeners();
  }

  Future<void> clear() async {
    _access = _refresh = null;
    user = null;
    await _store.deleteAll();
    notifyListeners();
  }

  /// URL absolut untuk path relatif dari API (gambar, stream).
  String? media(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return url;
    return '$base${url.startsWith('/') ? '' : '/'}$url';
  }

  Future<bool>? _refreshing;

  /// Refresh token berotasi: pakai ulang token lama dianggap pencurian oleh IAM → satu refresh pada satu waktu.
  /// Sesi hanya dihapus bila server menolak tokennya (400/401/403), bukan saat offline.
  Future<bool> _doRefresh() {
    final rt = _refresh;
    if (rt == null) return Future.value(false);
    return _refreshing ??= () async {
      try {
        final r = await _client
            .post(Uri.parse('$base/v1/auth/token'), headers: {'content-type': 'application/json'}, body: jsonEncode({'grant_type': 'refresh_token', 'refresh_token': rt}))
            .timeout(const Duration(seconds: 15));
        if ([400, 401, 403].contains(r.statusCode)) {
          await clear();
          return false;
        }
        if (r.statusCode >= 300) return false;
        await _save(jsonDecode(r.body) as Json);
        return true;
      } catch (_) {
        return false;
      }
    }()
        .whenComplete(() => _refreshing = null);
  }

  Future<T> request<T>(String path,
      {String method = 'GET', Object? body, Map<String, String>? query, bool auth = true, Duration timeout = const Duration(seconds: 20), String? server, List<int>? bytes, String? contentType}) async {
    // `server`: uji alamat lain tanpa token (lihat probeServer).
    if (server != null) auth = false;
    final uri = Uri.parse('${server ?? base}$path').replace(queryParameters: query == null || query.isEmpty ? null : query);
    Future<http.Response> go() {
      final h = <String, String>{'accept-language': settings.locale, 'x-app-version': 'android/$appVersion+$appBuild'};
      if (bytes != null) {
        h['content-type'] = contentType ?? 'application/octet-stream';
      } else if (body != null) {
        h['content-type'] = 'application/json';
      }
      if (auth && _access != null) h['authorization'] = 'Bearer $_access';
      final req = http.Request(method, uri)..headers.addAll(h);
      if (bytes != null) {
        req.bodyBytes = bytes;
      } else if (body != null) {
        req.body = jsonEncode(body);
      }
      return _client.send(req).then(http.Response.fromStream).timeout(timeout);
    }

    http.Response r;
    try {
      r = await go();
      if (r.statusCode == 401 && auth && _refresh != null && await _doRefresh()) r = await go();
    } on TimeoutException {
      throw const OfflineError();
    } on http.ClientException {
      throw const OfflineError();
    } catch (e) {
      if (e is ApiError) rethrow;
      throw const OfflineError();
    }
    final text = utf8.decode(r.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = {'detail': text};
    }
    if (r.statusCode >= 400) {
      final p = data is Json ? data : <String, dynamic>{};
      throw ApiError(r.statusCode, (p['detail'] ?? p['title'] ?? 'HTTP ${r.statusCode}').toString(), p);
    }
    return data as T;
  }

  Future<Json> get(String path, {Map<String, String>? query}) => request<Json>(path, query: query);
  Future<dynamic> post(String path, [Object? body]) => request<dynamic>(path, method: 'POST', body: body ?? const {});
  Future<dynamic> put(String path, [Object? body]) => request<dynamic>(path, method: 'PUT', body: body);
  Future<dynamic> delete(String path) => request<dynamic>(path, method: 'DELETE');

  /// Muat ulang profil (status Premium, tema akun, badge/status verifikasi). Galat diabaikan — profil tersimpan tetap dipakai.
  Future<void> refreshMe() async {
    if (!authed) return;
    try {
      await setUser(Me.fromJson(await get('/v1/me')));
    } catch (_) {}
  }

  /// Unggah gambar (dua langkah, sama dengan web `uploadFile`): daftarkan di `/v1/studio/uploads`, lalu PUT biner.
  /// Mengembalikan URL publik (relatif `/v1/catalog/media/…`) + peringatan validasi server (mis. bukan persegi).
  Future<({String url, List<String> warnings})> uploadImage(List<int> data, {required String filename, required String contentType, String purpose = 'avatar'}) async {
    final u = await request<Json>('/v1/studio/uploads',
        method: 'POST', body: {'kind': 'artwork', 'purpose': purpose, 'filename': filename, 'content_type': contentType, 'size': data.length});
    final r = await request<dynamic>(u['upload_url'] as String, method: 'PUT', bytes: data, contentType: contentType, timeout: const Duration(seconds: 90));
    final j = r is Json ? r : const <String, dynamic>{};
    return (url: (j['public_url'] ?? u['public_url']) as String, warnings: (j['warnings'] as List? ?? const []).whereType<String>().toList());
  }

  // ---- Autentikasi OTP (IAM RAVE hanya OTP — tanpa kata sandi) ----
  Future<String?> sendOtp(String email) async {
    final r = await request<Json>('/v1/auth/otp', method: 'POST', body: {'destination': email.trim(), 'channel': 'email'}, auth: false);
    return r['dev_code'] as String?;
  }

  Future<void> verifyOtp(String email, String code) async {
    final r = await request<Json>('/v1/auth/token', method: 'POST', body: {'grant_type': 'otp', 'destination': email.trim(), 'code': code.trim()}, auth: false);
    final mfa = MfaRequired.from(r);
    if (mfa != null) throw mfa;
    await _save(r);
  }

  /// Langkah kedua 2FA: kode authenticator 6 digit ATAU kode pemulihan sekali pakai.
  /// 401 berjudul "MFA Expired" → sesi verifikasi habis, kembali ke langkah pertama.
  Future<void> verifyMfa(String token, {String? code, String? recoveryCode}) async {
    final r = await request<Json>('/v1/auth/token',
        method: 'POST',
        body: {'grant_type': 'mfa', 'mfa_token': token, if (code != null) 'code': code.trim(), if (recoveryCode != null) 'recovery_code': recoveryCode.trim()},
        auth: false);
    await _save(r);
  }

  // ---- Login sosial (Google/Apple/Facebook; `dev` = simulasi di server development) ----
  /// Client ID web Google dari server (= `serverClientId` login Google native). Null = server lama / Google nonaktif.
  String? googleClientId;

  /// Login Google native: ID token dari lembar akun sistem → sesi RAVE, atau [MfaRequired] bila akun memakai 2FA.
  Future<void> googleNative(String idToken) async {
    final r = await request<Json>('/v1/auth/oauth/google/native', method: 'POST', body: {'id_token': idToken, 'client': 'mobile'}, auth: false);
    final mfa = MfaRequired.from(r);
    if (mfa != null) throw mfa;
    await _save(r);
  }

  Future<List<String>> socialProviders() async {
    final r = await request<Json>('/v1/auth/oauth/providers', auth: false, timeout: const Duration(seconds: 8));
    final list = (r['providers'] as List? ?? const []).whereType<String>().toList();
    googleClientId = r['google_client_id'] as String?;
    return [for (final p in const ['google', 'apple', 'facebook', 'dev']) if (list.contains(p)) p];
  }

  Future<SocialLaunch> startSocial(String provider) async {
    final r = await request<Json>('/v1/auth/oauth/$provider/app', method: 'POST', body: {'client': 'mobile'}, auth: false);
    return SocialLaunch.fromJson(provider, r);
  }

  /// URL yang dibuka di browser sistem (relatif ke server yang dipakai aplikasi — berfungsi juga di IP LAN).
  Uri socialStartUrl(SocialLaunch l) => Uri.parse('$base${l.startPath}');

  /// Satu kali polling. OfflineError diteruskan (flow mencoba lagi di tick berikutnya).
  Future<SocialPollResult> pollSocial(String pollToken) async {
    try {
      final r = await request<Json>('/v1/auth/oauth/poll', method: 'POST', body: {'poll_token': pollToken}, auth: false, timeout: const Duration(seconds: 10));
      return socialPollFromResponse(200, r);
    } on ApiError catch (e) {
      return socialPollFromResponse(e.status, e.problem);
    }
  }

  /// Simpan sesi dari token hasil login sosial (sama dengan login OTP).
  Future<void> saveSession(Json tokens) => _save(tokens);

  Future<void> logout() async {
    unawaited(GoogleNative.signOut());
    final rt = _refresh;
    if (rt != null) {
      try {
        await request<dynamic>('/v1/auth/logout', method: 'POST', body: {'refresh_token': rt}, timeout: const Duration(seconds: 5));
      } catch (_) {}
    }
    await clear();
  }
}
