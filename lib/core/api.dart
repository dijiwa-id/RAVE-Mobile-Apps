import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'models.dart';
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

/// Server tidak terjangkau (offline, alamat salah, timeout).
class OfflineError implements Exception {
  const OfflineError();
}

/// Sesi & klien HTTP. Token disimpan di Keystore Android (flutter_secure_storage), bukan prefs biasa.
class Api extends ChangeNotifier {
  Api(this.settings);
  final Settings settings;
  final _store = const FlutterSecureStorage(aOptions: AndroidOptions());
  final _client = http.Client();

  String? _access;
  String? _refresh;
  Me? user;

  bool get authed => _access != null;
  String get base => settings.server;

  Future<void> restore() async {
    _access = await _store.read(key: 'access');
    _refresh = await _store.read(key: 'refresh');
    final u = await _store.read(key: 'user');
    if (u != null) user = Me.fromJson(jsonDecode(u) as Json);
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

  Future<T> request<T>(String path, {String method = 'GET', Object? body, Map<String, String>? query, bool auth = true, Duration timeout = const Duration(seconds: 20)}) async {
    final uri = Uri.parse('$base$path').replace(queryParameters: query == null || query.isEmpty ? null : query);
    Future<http.Response> go() {
      final h = <String, String>{'accept-language': settings.locale};
      if (body != null) h['content-type'] = 'application/json';
      if (auth && _access != null) h['authorization'] = 'Bearer $_access';
      final req = http.Request(method, uri)..headers.addAll(h);
      if (body != null) req.body = jsonEncode(body);
      return _client.send(req).then(http.Response.fromStream).timeout(timeout);
    }

    http.Response r;
    try {
      r = await go();
      if (r.statusCode == 401 && _refresh != null && await _doRefresh()) r = await go();
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

  // ---- Autentikasi OTP (IAM RAVE hanya OTP — tanpa kata sandi) ----
  Future<String?> sendOtp(String email) async {
    final r = await request<Json>('/v1/auth/otp', method: 'POST', body: {'destination': email.trim(), 'channel': 'email'}, auth: false);
    return r['dev_code'] as String?;
  }

  Future<void> verifyOtp(String email, String code) async {
    final r = await request<Json>('/v1/auth/token', method: 'POST', body: {'grant_type': 'otp', 'destination': email.trim(), 'code': code.trim()}, auth: false);
    await _save(r);
  }

  Future<void> logout() async {
    final rt = _refresh;
    if (rt != null) {
      try {
        await request<dynamic>('/v1/auth/logout', method: 'POST', body: {'refresh_token': rt}, timeout: const Duration(seconds: 5));
      } catch (_) {}
    }
    await clear();
  }
}
