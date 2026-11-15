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

  // ---- Preferensi pemutar & tampilan di perangkat ini (sama dengan web stores/prefs.ts) ----
  /// Normalisasi volume memakai `loudness_gain_db` sesi pemutaran.
  bool get normalizeVolume => _p.getBool('normalize') ?? false;
  /// Equalizer (khusus Premium; tetap dilewati untuk akun Gratis walau tersimpan aktif).
  bool get eqOn => _p.getBool('eqOn') ?? false;
  /// Preset equalizer terakhir (`flat`, `bass`, …) atau `custom`.
  String get eqPreset => _p.getString('eqPreset') ?? 'flat';
  /// Gain kustom per pita perangkat (dB). Kosong/beda jumlah pita → pakai [eqPreset].
  List<double> get eqGains => (_p.getStringList('eqGains') ?? const []).map((e) => double.tryParse(e) ?? 0).toList();
  bool get compactLibrary => _p.getBool('compactLibrary') ?? false;
  bool get vinylMotion => _p.getBool('vinylMotion') ?? true;
  /// Efek audio (equalizer/loudness) gagal dibuat di perangkat ini → jangan dipasang lagi (pemutaran tetap jalan).
  bool get fxUnsupported => _p.getBool('fxUnsupported') ?? false;

  // ---- Tema (web lib/theme.ts): pilihan perangkat + kebijakan platform terakhir (agar start offline tetap benar) ----
  /// Pilihan tema di perangkat ini (tamu & cadangan bila akun belum memilih). null = belum memilih.
  String? get themePref => _p.getString('themePref');
  /// `appearance.player_theme` terakhir dari platform (bawaan gelap).
  String get platformTheme => _p.getString('platformTheme') ?? 'dark';
  /// `appearance.allow_user_theme` terakhir dari platform.
  bool get allowUserTheme => _p.getBool('allowUserTheme') ?? true;

  Future<void> setThemePref(String? v) async {
    v == null ? await _p.remove('themePref') : await _p.setString('themePref', v);
    notifyListeners();
  }

  /// Simpan kebijakan tema platform (dari `GET /v1/platform/config`); berubah → bangun ulang tema.
  Future<void> setPlatformAppearance({required String theme, required bool allowUser}) async {
    if (theme == platformTheme && allowUser == allowUserTheme) return;
    await _p.setString('platformTheme', theme);
    await _p.setBool('allowUserTheme', allowUser);
    notifyListeners();
  }

  Future<void> setBool(String key, bool v) async {
    await _p.setBool(key, v);
    notifyListeners();
  }

  Future<void> setEq({String? preset, List<double>? gains}) async {
    if (preset != null) await _p.setString('eqPreset', preset);
    if (gains != null) await _p.setStringList('eqGains', gains.map((g) => g.toStringAsFixed(1)).toList());
    notifyListeners();
  }

  /// Kualitas yang diminta ke server: hemat data → rendah, selain itu pilihan pengguna.
  String get requestQuality => dataSaver ? 'low' : quality;

  /// Kualitas yang dikirim untuk akun ini: Gratis/tamu → bawaan server (`auto`, atau `low` saat hemat data) —
  /// tidak pernah meminta kualitas Premium; Premium → pilihan pengguna.
  String requestQualityFor({required bool premium}) => dataSaver ? 'low' : (premium ? quality : 'auto');

  /// Akun Gratis: pilihan tersimpan di atas plafon Gratis dikembalikan ke `auto` (mis. setelah Premium berakhir).
  Future<void> enforceFreeQuality({required bool premium, String freeMax = 'normal'}) async {
    if (premium || quality == 'auto') return;
    if (QualityPolicy.rank(quality) > QualityPolicy.rank(freeMax)) await setQuality('auto');
  }

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

/// Kebijakan kualitas streaming dari Super Admin (`GET /v1/platform/config` → `settings.streaming.*`), ditegakkan server
/// saat sesi pemutaran dibuat — klien hanya menyesuaikan pilihan (sama dengan web Settings.tsx):
/// opsi di atas plafon Premium disembunyikan; di atas plafon Gratis dikunci untuk akun Gratis.
class QualityPolicy {
  const QualityPolicy({this.freeMax = 'normal', this.premiumMax = 'lossless', this.losslessRes = '24-bit/96 kHz'});
  static const order = ['auto', 'low', 'normal', 'high', 'lossless'];
  static const _res = {'16_44': '16-bit/44.1 kHz', '24_48': '24-bit/48 kHz', '24_96': '24-bit/96 kHz'};
  final String freeMax, premiumMax, losslessRes;

  factory QualityPolicy.fromSettings(Map<String, dynamic> cfg) {
    String pick(Object? v, List<String> allowed, String d) => v is String && allowed.contains(v) ? v : d;
    final losslessOn = cfg['streaming.lossless_enabled'] != false;
    final premiumRaw = pick(cfg['streaming.premium_max_quality'], const ['normal', 'high', 'lossless'], 'lossless');
    return QualityPolicy(
      freeMax: pick(cfg['streaming.free_max_quality'], const ['low', 'normal', 'high'], 'normal'),
      premiumMax: !losslessOn && premiumRaw == 'lossless' ? 'high' : premiumRaw,
      losslessRes: _res[cfg['streaming.lossless_max_resolution']] ?? '24-bit/96 kHz',
    );
  }

  static int rank(String q) => order.indexOf(q);

  /// Pilihan yang ditampilkan (≤ plafon Premium).
  List<String> get options => order.where((q) => rank(q) <= rank(premiumMax)).toList();

  /// Dikunci (label Premium) untuk akun Gratis.
  bool locked(String q, {required bool premium}) => !premium && q != 'auto' && rank(q) > rank(freeMax);

  /// Pilihan tersimpan di atas plafon Premium → turunkan ke plafon.
  String clamp(String q) => rank(q) > rank(premiumMax) ? premiumMax : q;
}
