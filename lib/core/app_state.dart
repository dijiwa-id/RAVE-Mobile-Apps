import 'package:flutter/widgets.dart';

import '../player/player.dart';
import 'api.dart';
import 'i18n.dart';
import 'models.dart';
import 'settings.dart';

/// Dependensi aplikasi (tanpa paket DI/state tambahan): diakses lewat `App.of(context)`.
class AppState {
  AppState(this.settings, this.api, this.player, this.likes);
  final Settings settings;
  final Api api;
  final Player player;
  final Likes likes;
  final cache = DataCache();
  S get s => S.of(settings.locale);
}

class App extends InheritedWidget {
  const App({super.key, required this.state, required super.child});
  final AppState state;
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<App>()!.state;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<App>()!.state;
  @override
  bool updateShouldNotify(App old) => true;
}

/// Cache data mungil (stale-while-revalidate): kunci = path API. Data lama langsung tampil, lalu diperbarui.
class DataCache {
  final _data = <String, ({Object value, DateTime at})>{};
  final _inflight = <String, Future<Object>>{};
  static const fresh = Duration(seconds: 30);

  Object? peek(String key) => _data[key]?.value;
  bool isFresh(String key) => _data[key] != null && DateTime.now().difference(_data[key]!.at) < fresh;

  /// Muat dengan dedup per kunci. Catatan: callback `whenComplete` TIDAK boleh mengembalikan Future yang sedang
  /// ditunggu (dulu `() => _inflight.remove(key)` mengembalikan Future itu sendiri → menunggu dirinya → macet selamanya).
  Future<Object> load(String key, Future<Object> Function() fetch, {bool force = false}) {
    if (!force && isFresh(key)) return Future.value(_data[key]!.value);
    final running = _inflight[key];
    if (running != null && !force) return running;
    late final Future<Object> f;
    f = fetch().then((v) {
      if (identical(_inflight[key], f)) _data[key] = (value: v, at: DateTime.now());
      return v;
    });
    _inflight[key] = f;
    f.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (identical(_inflight[key], f)) _inflight.remove(key);
    });
    return f;
  }

  /// Buang data & permintaan berjalan (mis. server diganti → jawaban server lama tidak boleh masuk cache).
  void invalidate(String prefix) {
    _data.removeWhere((k, _) => k.startsWith(prefix));
    _inflight.removeWhere((k, _) => k.startsWith(prefix));
  }

  void clear() {
    _data.clear();
    _inflight.clear();
  }
}

/// Status "Disukai" per lagu: dicek batch untuk daftar yang tampil, diubah optimistis.
class Likes extends ChangeNotifier {
  Likes(this.api);
  final Api api;
  final liked = <String>{};
  final _known = <String>{};
  final _pending = <String>{};
  bool _scheduled = false;

  bool has(String id) => liked.contains(id);

  void check(Iterable<String> ids) {
    if (!api.authed) return;
    _pending.addAll(ids.where((i) => !_known.contains(i)));
    if (_pending.isEmpty || _scheduled) return;
    _scheduled = true;
    Future.delayed(const Duration(milliseconds: 40), () async {
      _scheduled = false;
      final batch = _pending.take(200).toList();
      _pending.removeAll(batch);
      try {
        final r = await api.get('/v1/library/likes/contains', query: {'ids': batch.join(',')});
        final ids = (r['ids'] as List).cast<String>();
        _known.addAll(batch);
        liked.addAll(ids);
        notifyListeners();
      } catch (_) {}
    });
  }

  Future<void> toggle(String id, DataCache cache) async {
    final was = liked.contains(id);
    was ? liked.remove(id) : liked.add(id);
    notifyListeners();
    try {
      await api.request<dynamic>('/v1/library/likes/$id', method: was ? 'DELETE' : 'PUT');
      cache.invalidate('/v1/library');
    } catch (_) {
      was ? liked.add(id) : liked.remove(id);
      notifyListeners();
      rethrow;
    }
  }

  void reset() {
    liked.clear();
    _known.clear();
    notifyListeners();
  }
}

/// Akun baru/belum onboarding + pilihan tamu lengkap → kirim ke /v1/me/onboarding (ikuti artis, kota, genre).
Future<void> syncOnboarding(AppState app) async {
  final u = app.api.user;
  final st = app.settings;
  if (u == null || u.onboarded || st.city == null || st.artistIds.length < 3) return;
  try {
    final me = await app.api.post('/v1/me/onboarding', {'city': st.city, 'genres': st.genres, 'artist_ids': st.artistIds}) as Json;
    await app.api.setUser(Me.fromJson(me));
    app.cache.invalidate('/v1/');
  } catch (_) {
    // best-effort: dapat diulang dari Pengaturan nanti
  }
}

/// Muat item yang bisa diputar dari sebuah kartu (album/artis/playlist/episode).
Future<List<Playable>> playablesOf(AppState app, String kind, String id) async {
  final api = app.api;
  switch (kind) {
    case 'release':
      return Release.fromJson(await api.get('/v1/catalog/releases/$id')).tracks.map(Playable.fromTrack).toList();
    case 'artist':
      return Artist.fromJson(await api.get('/v1/catalog/artists/${Uri.encodeComponent(id)}')).topTracks.map(Playable.fromTrack).toList();
    case 'playlist':
      final j = await api.get('/v1/library/playlists/$id');
      return (j['items'] as List).map((x) => Playable.fromTrack(Track.fromJson(x['track'] as Json))).toList();
    case 'episode':
      final j = await api.get('/v1/catalog/episodes/$id');
      final e = Episode.fromJson(j);
      return [Playable.fromEpisode(e, (j['show'] as Json?)?['title'] ?? '')];
  }
  return const [];
}
