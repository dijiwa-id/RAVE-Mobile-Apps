import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Server default saat build: `--dart-define=RAVE_API=https://…`; dapat diganti pengguna di Pengaturan.
/// 10.0.2.2 = localhost komputer dari emulator Android.
const defaultServer = String.fromEnvironment('RAVE_API', defaultValue: 'http://10.0.2.2:8088');

/// Pengaturan lokal (bukan rahasia): server, bahasa, kualitas streaming.
class Settings extends ChangeNotifier {
  Settings._(this._p);
  final SharedPreferences _p;

  static Future<Settings> load() async => Settings._(await SharedPreferences.getInstance());

  String get server => _p.getString('server') ?? defaultServer;
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
