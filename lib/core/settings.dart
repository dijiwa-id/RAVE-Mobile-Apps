import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server default saat build: `--dart-define=RAVE_API=https://…`; dapat diganti pengguna di Pengaturan.
/// 10.0.2.2 = localhost komputer dari emulator Android.
const defaultServer = String.fromEnvironment('RAVE_API', defaultValue: 'http://10.0.2.2:8088');

/// Pilihan cepat server (Pengaturan & banner koneksi): `--dart-define=RAVE_API_PRESETS=Demo|http://…,Produksi|https://…`.
/// Server default selalu ikut sebagai pilihan pertama.
final List<(String, String)> serverPresets = () {
  final out = <(String, String)>[('Default', defaultServer)];
  for (final e in const String.fromEnvironment('RAVE_API_PRESETS').split(',')) {
    final i = e.indexOf('|');
    if (i <= 0) continue;
    final url = Settings.normalize(e.substring(i + 1));
    if (url == null) continue;
    final k = out.indexWhere((p) => p.$2 == url);
    if (k >= 0) {
      out[k] = (e.substring(0, i).trim(), url);
    } else {
      out.add((e.substring(0, i).trim(), url));
    }
  }
  return out;
}();

/// Pengaturan lokal (bukan rahasia): server, bahasa, kualitas streaming.
class Settings extends ChangeNotifier {
  Settings._(this._p);
  final SharedPreferences _p;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  String get server => _p.getString('server') ?? _auto ?? defaultServer;

  /// Server pilihan otomatis (tidak disimpan): dipakai bila pengguna belum pernah menyimpan server sendiri.
  String? _auto;

  /// Pengguna menyimpan server sendiri → tidak ada pemilihan otomatis.
  bool get serverIsCustom => _p.getString('server') != null;

  /// Saat start: bila server default tak terjangkau dan pengguna belum memilih server, coba preset lain (paralel)
  /// lalu pakai yang pertama menjawab — mis. emulator (10.0.2.2) atau PC di Wi-Fi lain. `probe` = versi RAVE atau null.
  Future<void> resolveServer(Future<String?> Function(String url) probe) async {
    if (serverIsCustom || serverPresets.length < 2) return;
    if (await probe(defaultServer) != null) return;
    final others = serverPresets.map((p) => p.$2).where((u) => u != defaultServer).toList();
    final results = await Future.wait(others.map((u) async => await probe(u) == null ? null : u));
    final ok = results.whereType<String>().firstOrNull;
    if (ok != null && ok != _auto) {
      _auto = ok;
      notifyListeners();
    }
  }
  // BRD (NFR lokalisasi): Bahasa Indonesia default; Inggris hanya bila dipilih / perangkat berbahasa Inggris.
  String get locale => _p.getString('locale') ?? (PlatformDispatcher.instance.locale.languageCode == 'en' ? 'en' : 'id');
  String get quality => _p.getString('quality') ?? 'auto';
  bool get dataSaver => _p.getBool('dataSaver') ?? false;
  bool get onboarded => _p.getBool('onboarded') ?? false;
  String? get city => _p.getString('city');
  List<String> get genres => _p.getStringList('genres') ?? const [];
  List<String> get artistIds => _p.getStringList('artistIds') ?? const [];

  /// Pilihan onboarding (tamu disimpan lokal; dikirim ke /v1/me/onboarding setelah masuk).
  Future<void> setPersonalization(String? city, List<String> genres, List<String> artistIds) async {
    if (city != null) await _p.setString('city', city);
    await _p.setStringList('genres', genres);
    await _p.setStringList('artistIds', artistIds);
    notifyListeners();
  }

  Future<void> setOnboarded() async {
    await _p.setBool('onboarded', true);
  }

  Future<void> setServer(String v) async {
    await _p.setString('server', v);
    notifyListeners();
  }

  Future<void> setLocale(String v) async {
    await _p.setString('locale', v);
    notifyListeners();
    onLocaleChanged?.call(v);
  }

  /// Dipasang Api: bahasa yang dipilih disimpan ke akun (PATCH /v1/me, BRD IAM-08) bila masuk.
  void Function(String)? onLocaleChanged;

  Future<void> setQuality(String v) async {
    await _p.setString('quality', v);
    notifyListeners();
  }

  Future<void> setDataSaver(bool v) async {
    await _p.setBool('dataSaver', v);
    notifyListeners();
  }

  /// Kualitas yang diminta ke server: hemat data → rendah, selain itu pilihan pengguna.
  String get requestQuality => dataSaver ? 'low' : quality;

  /// Event putar yang belum terkirim (royalti tidak hilang saat aplikasi ditutup/offline).
  List<String> get pendingEvents => _p.getStringList('pendingEvents') ?? const [];
  Future<void> setPendingEvents(List<String> v) => _p.setStringList('pendingEvents', v);

  /// Normalisasi & validasi URL server (http/https).
  static String? normalize(String raw) {
    final u = Uri.tryParse(raw.trim());
    if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
    return u.replace(path: '', query: null, fragment: null).toString().replaceAll(RegExp(r'/+$'), '');
  }
}
