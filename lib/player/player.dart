import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../core/api.dart';
import '../core/i18n.dart';
import '../core/models.dart' hide MediaItem;
import '../core/settings.dart';
import 'audio_fx.dart';

/// Item yang bisa diputar: lagu atau episode podcast.
class Playable {
  final String id, kind, title, subtitle;
  final String? artistKey, releaseId, imageUrl;
  final int durationMs;
  final bool premium, contentWarning, explicit, hasLyrics;
  const Playable({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.artistKey,
    this.releaseId,
    this.imageUrl,
    required this.durationMs,
    this.premium = false,
    this.contentWarning = false,
    this.explicit = false,
    this.hasLyrics = false,
  });
  factory Playable.fromTrack(Track t) => Playable(
        id: t.id,
        kind: 'track',
        title: t.title,
        subtitle: t.artist.name,
        artistKey: t.artist.slug,
        releaseId: t.releaseId,
        imageUrl: t.coverUrl,
        durationMs: t.durationMs,
        explicit: t.explicit,
        hasLyrics: t.hasLyrics,
      );
  factory Playable.fromEpisode(Episode e, String show, {bool contentWarning = false}) => Playable(
        id: e.id,
        kind: 'episode',
        title: e.title,
        subtitle: show,
        imageUrl: e.coverUrl,
        durationMs: e.durationMs,
        premium: e.premium,
        contentWarning: contentWarning,
      );
}

/// Status jeda iklan (tier Gratis) untuk UI.
class AdState {
  final AdCreative ad;
  final int index, total;
  final Duration elapsed;
  final bool paused;
  const AdState(this.ad, this.index, this.total, this.elapsed, this.paused);
  int get skipIn => ad.skippableAfterS == null ? -1 : max(0, ad.skippableAfterS! - elapsed.inSeconds);
}

/// Pemutar RAVE: satu sesi playback per item (URL stream bertanda tangan & kedaluwarsa), laporan putar untuk royalti,
/// pemulihan stream, pratinjau 30 dtk, dan jeda iklan tier Gratis — perilaku sama dengan web (stores/player.ts).
/// Kontrol latar belakang (notifikasi, layar kunci, headset) lewat audio_service.
class Player extends ChangeNotifier {
  Player(this.api, this.settings) {
    audio = _newAudio(withFx: _fxPlatform && !settings.fxUnsupported);
  }
  final Api api;
  final Settings settings;

  /// Pemutar utama. Bukan `final`: bila efek audio (equalizer/loudness) gagal dibuat di perangkat, pemutar
  /// dibuat ulang tanpa efek (lihat [_dropFx]) — pemutaran tidak boleh rusak karena equalizer.
  late AudioPlayer audio;
  final _adAudio = AudioPlayer();
  final _subs = <StreamSubscription<dynamic>>[];

  // ---- Efek audio Android (AudioPipeline harus dipasang saat AudioPlayer dibuat) ----
  static bool get _fxPlatform => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AndroidEqualizer? _eq;
  AndroidLoudnessEnhancer? _loud;
  AndroidEqualizerParameters? _eqParams;
  String _fxApplied = '';

  /// Equalizer bisa dipakai di perangkat ini (Android + efek berhasil dibuat).
  bool get eqSupported => _eq != null;

  /// Parameter pita equalizer perangkat (null sampai pemutar aktif pertama kali).
  AndroidEqualizerParameters? get eqParams => _eqParams;

  AudioPlayer _newAudio({required bool withFx}) {
    _eq = null;
    _loud = null;
    _eqParams = null;
    _fxApplied = '';
    if (!withFx) return AudioPlayer();
    try {
      final eq = AndroidEqualizer(), loud = AndroidLoudnessEnhancer();
      final p = AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [loud, eq]));
      _eq = eq;
      _loud = loud;
      // Pita perangkat baru diketahui setelah pemutar native aktif (lagu pertama dimuat).
      eq.parameters.then((params) {
        if (!identical(_eq, eq)) return;
        _eqParams = params;
        _fxApplied = '';
        unawaited(syncFx());
        notifyListeners();
      }, onError: (Object _) {});
      return p;
    } catch (_) {
      _eq = null;
      _loud = null;
      return AudioPlayer();
    }
  }

  /// Efek gagal di perangkat: buang pemutar ber-efek, pasang pemutar polos, ingat agar tidak dicoba lagi.
  Future<void> _dropFx() async {
    final old = audio;
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    audio = _newAudio(withFx: false);
    _wire();
    unawaited(settings.setBool('fxUnsupported', true));
    try {
      await old.dispose();
    } catch (_) {}
    notifyListeners();
  }

  /// Muat URL; bila gagal karena efek audio Android, ulangi sekali dengan pemutar tanpa efek.
  Future<void> _setUrl(String url, Duration resume) async {
    try {
      await audio.setUrl(url, initialPosition: resume);
    } catch (e) {
      if ((_eq == null && _loud == null) || !looksLikeFxError(e)) rethrow;
      await _dropFx();
      await _applyLoudness();
      await audio.setUrl(url, initialPosition: resume);
    }
  }

  /// Terapkan equalizer (khusus Premium; dilewati untuk akun Gratis) — tidak pernah melempar galat.
  Future<void> syncFx() async {
    final eq = _eq;
    if (eq == null) return;
    final on = settings.eqOn && (api.user?.premium ?? false);
    final params = _eqParams;
    final gains = params == null ? const <double>[] : eqGainsFor(params);
    final sig = '$on|${gains.join(',')}';
    if (sig == _fxApplied) return;
    _fxApplied = sig;
    try {
      if (on && params != null) {
        for (var i = 0; i < params.bands.length && i < gains.length; i++) {
          await params.bands[i].setGain(gains[i]);
        }
      }
      await eq.setEnabled(on && params != null);
    } catch (_) {
      // efek ditolak perangkat → biarkan dilewati, pemutaran tetap jalan
    }
  }

  /// Gain per pita perangkat: kurva kustom tersimpan (bila jumlah pita cocok) atau preset yang dipetakan.
  List<double> eqGainsFor(AndroidEqualizerParameters p) {
    final saved = settings.eqGains;
    if (settings.eqPreset == 'custom' && saved.length == p.bands.length) {
      return [for (final g in saved) g.clamp(p.minDecibels, p.maxDecibels).toDouble()];
    }
    return mapCurve(eqPresets[settings.eqPreset] ?? eqPresets['flat']!, [for (final b in p.bands) b.centerFrequency], p.minDecibels, p.maxDecibels);
  }

  /// Normalisasi volume: gain negatif → volume pemutar diperkecil; positif → LoudnessEnhancer (bila tersedia).
  Future<void> _applyLoudness() async {
    final g = settings.normalizeVolume ? normalizeGain(session?.loudnessGainDb) : 0.0;
    final loud = _loud;
    try {
      await audio.setVolume(volumeForGain(g));
    } catch (_) {}
    if (loud == null) return;
    try {
      final boost = g > 0 ? g : 0.0;
      await loud.setTargetGain(boost);
      await loud.setEnabled(boost > 0);
    } catch (_) {}
  }
  late final _Handler _handler;
  S get _s => S.of(settings.locale);

  List<Playable> queue = [];
  int index = -1;
  Playable? current;
  PlaybackSession? session;
  bool buffering = false;
  bool shuffle = false;
  LoopMode repeat = LoopMode.off;
  String? error;

  /// Status iklan berjalan. Mulai/selesai iklan memanggil [notifyListeners] (kunci kontrol); hitungan waktu tiap
  /// 250 md hanya memperbarui notifier ini agar seluruh UI pemutar tidak ikut dibangun ulang.
  final adTick = ValueNotifier<AdState?>(null);
  AdState? get ad => adTick.value;

  /// Naik tiap [_load]; hasil async dari muatan lama yang selesai belakangan dibuang.
  int _loadGen = 0;

  /// Asal antrean (sama dengan web `PlayerState.context`): `release:<id>` · `playlist:<id>` · `artist:<id>` ·
  /// `liked` · `show:<id>`. Tombol putar sebuah koleksi menjadi Jeda bila antrean berasal darinya.
  String? context;

  /// Kunci [key] sedang aktif: `track:`/`episode:` = item itu yang dimuat; selain itu = asal antrean.
  bool isActive(String? key) => keyActive(key, current?.id, context);

  /// Logika [isActive] tanpa status pemutar (mudah diuji).
  static bool keyActive(String? key, String? currentId, String? context) {
    if (key == null || currentId == null) return false;
    if (key.startsWith('track:') || key.startsWith('episode:')) return currentId == key.substring(key.indexOf(':') + 1);
    return context == key;
  }

  /// Aktif dan sedang berbunyi (atau memuat) → tombol menampilkan Jeda.
  bool isPlayingKey(String? key) => isActive(key) && (playing || buffering) && error == null;
  bool _adBusy = false;

  bool get playing => audio.playing;
  Stream<Duration> get position => audio.positionStream;
  Duration get duration => audio.duration ?? Duration(milliseconds: session?.durationMs ?? current?.durationMs ?? 0);

  // ---- Laporan putar (TDD §11.3): start, progress tiap 15 dtk, complete, skip ----
  final _pending = <Json>[];
  Timer? _flushTimer;
  int _playedMs = 0, _lastProgressAt = 0;
  DateTime? _lastTick;
  int _recoveries = 0;
  bool _premiumNotified = false;
  final _messages = StreamController<String>.broadcast();
  final _losslessNotified = <String>{};

  /// Pesan singkat untuk ditampilkan UI (snackbar).
  Stream<String> get messages => _messages.stream;

  Future<void> init() async {
    for (final e in settings.pendingEvents) {
      try {
        _pending.add(jsonDecode(e) as Json);
      } catch (_) {}
    }
    if (_pending.isNotEmpty) unawaited(flush());
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _handler = await AudioService.init(
      builder: () => _Handler(this),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'id.dijiwa.rave.playback',
        androidNotificationChannelName: 'Pemutaran RAVE',
        androidNotificationIcon: 'drawable/ic_stat_rave',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
    _wire();
    // Equalizer mengikuti status Premium & preferensi; normalisasi mengikuti preferensi.
    var lastNormalize = settings.normalizeVolume;
    settings.addListener(() {
      unawaited(syncFx());
      _publishState(); // izin geser (streaming.free_seek_enabled) → aksi layar kunci
      if (settings.normalizeVolume != lastNormalize) {
        lastNormalize = settings.normalizeVolume;
        unawaited(_applyLoudness());
      }
    });
    api.addListener(() {
      unawaited(syncFx());
      _publishState(); // Gratis ↔ Premium → aksi seek layar kunci
      // Turun ke Gratis / keluar → pilihan kualitas Premium yang tersimpan dikembalikan ke auto.
      if (api.authed) unawaited(settings.enforceFreeQuality(premium: api.user?.premium ?? false));
    });
    // Telepon masuk / headset dicabut → jeda (praktik aplikasi musik).
    session.becomingNoisyEventStream.listen((_) => audio.pause());
    session.interruptionEventStream.listen((e) {
      if (e.begin) audio.pause();
    });
  }

  /// Langganan stream pemutar utama (diulang bila pemutar dibuat ulang tanpa efek).
  void _wire() {
    _subs.add(audio.playerStateStream.listen((st) {
      final b = st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering;
      if (b != buffering) buffering = b;
      if (st.processingState == ProcessingState.completed) unawaited(_onCompleted());
      _publishState();
      notifyListeners();
    }));
    _subs.add(audio.positionStream.listen(_onPosition));
    _subs.add(audio.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) => _onStreamError()));
  }

  void _onPosition(Duration p) {
    final now = DateTime.now();
    if (audio.playing && _lastTick != null) _playedMs += min(1000, now.difference(_lastTick!).inMilliseconds);
    _lastTick = now;
    final s = session;
    if (s != null && s.previewOnly && s.previewMs != null && p.inMilliseconds >= s.previewMs! && !_previewHandled) {
      final n = _nextIndex();
      if (anonymousAdsEligible && n != null) {
        // Sekali per item: satu iklan lalu lanjut ke cuplikan berikutnya.
        _previewHandled = true;
        unawaited(_previewAdvance(n));
      } else {
        audio.pause();
        error = _s.previewEnded;
        notifyListeners();
      }
    }
    if (_playedMs - _lastProgressAt >= 15000) {
      _lastProgressAt = _playedMs;
      _queueEvent('progress');
    }
  }

  void _queueEvent(String type) {
    final s = session, c = current;
    if (s == null || c == null || !api.authed) return;
    _pending.add({
      'session_id': s.sessionId,
      c.kind == 'track' ? 'track_id' : 'episode_id': c.id,
      'type': type,
      'position_ms': audio.position.inMilliseconds,
      'played_ms': _playedMs,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    unawaited(_persist());
    if (type != 'progress' || _pending.length >= 4) {
      _lastFlush = flush();
      unawaited(_lastFlush);
    } else {
      _flushTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
    }
  }

  /// Pengiriman event terakhir yang dipicu langsung (mis. `complete`) — ditunggu sebelum jeda iklan.
  Future<void>? _lastFlush;

  /// Kirim event tertunda. Offline/5xx/429 → disimpan untuk dikirim lagi; 4xx lain dibuang.
  Future<void> flush() async {
    if (_pending.isEmpty) return;
    final events = List<Json>.of(_pending);
    _pending.clear();
    try {
      await api.post('/v1/events/play', {'events': events});
    } catch (e) {
      final retry = e is! ApiError || e.status >= 500 || e.status == 429;
      if (retry) _pending.insertAll(0, events.take(200));
    } finally {
      if (_pending.isEmpty) {
        _flushTimer?.cancel();
        _flushTimer = null;
      }
      unawaited(_persist());
    }
  }

  /// Simpan antrean event ke perangkat (dipanggil setelah flush & saat aplikasi ke latar belakang).
  Future<void> _persist() => settings.setPendingEvents(_pending.take(200).map(jsonEncode).toList());

  /// Aplikasi ke latar belakang / ditutup: kirim & simpan event tertunda.
  Future<void> onBackground() async {
    await flush();
    await _persist();
  }

  /// Cuplikan item ini sudah ditangani (iklan + lanjut) — direset tiap [_load].
  bool _previewHandled = false;

  /// Pendengar tanpa akun & platform mengizinkan iklan anonim (`ads.anonymous_enabled`).
  bool get anonymousAdsEligible => api.user == null && settings.adsAnonymous;

  /// Akhir cuplikan 30 dtk (tamu): pesan "cuplikan selesai", satu jeda iklan, lalu cuplikan item [next].
  /// Antrean yang diubah selama iklan dihormati (mis. pengguna memilih lagu lain → [index] baru dipakai).
  Future<void> _previewAdvance(int next) async {
    if (audio.playing) await audio.pause();
    _messages.add(_s.previewEnded);
    index = next;
    final gen = _loadGen;
    await (debugAdBreak ?? _adBreak)(queue[next]);
    if (gen != _loadGen || current == null || queue.isEmpty) return; // sudah dimuat lain / di-reset
    if (index < 0 || index >= queue.length) index = 0;
    await (debugLoad ?? _load)(queue[index]);
  }

  /// Uji: pengganti jeda iklan & pemuatan item (tanpa jaringan/kanal platform).
  @visibleForTesting
  Future<void> Function(Playable next)? debugAdBreak;
  @visibleForTesting
  Future<void> Function(Playable item)? debugLoad;

  /// Uji: picu penanganan akhir cuplikan seolah posisi melewati `preview_ms`.
  @visibleForTesting
  void debugPreviewReached() => _onPosition(Duration(milliseconds: session?.previewMs ?? 30000));

  /// [resume] > 0: pemulihan item yang sama (stream kedaluwarsa/putus) — lanjut dari posisi terakhir.
  Future<void> _load(Playable item, {Duration resume = Duration.zero}) async {
    final gen = ++_loadGen;
    final fresh = resume == Duration.zero;
    _previewHandled = false;
    if (fresh) {
      _recoveries = 0;
      if (current != null && audio.playing && audio.position < duration - const Duration(seconds: 2)) _queueEvent('skip');
      _playedMs = 0;
      _lastProgressAt = 0;
    }
    await audio.stop();
    if (gen != _loadGen) return;
    current = item;
    session = null;
    error = null;
    buffering = true;
    notifyListeners();
    _publishItem();
    try {
      final j = await api.post('/v1/playback/sessions', {item.kind == 'track' ? 'track_id' : 'episode_id': item.id, 'quality': settings.requestQualityFor(premium: api.user?.premium ?? false)}) as Json;
      if (gen != _loadGen) return;
      session = PlaybackSession.fromJson(j);
      final cap = session!.qualityCapped;
      if (cap != null && cap != 'preview' && !_premiumNotified) {
        _premiumNotified = true;
        _messages.add(cap == 'premium' ? _s.premiumQuality : cap == 'disabled' ? _s.qualityDisabled : _s.qualityUnavailable);
      }
      // Lossless diminta tetapi FLAC sedang disiapkan server → beri tahu sekali per lagu.
      if (session!.losslessPending && _losslessNotified.add(item.id)) _messages.add(_s.losslessPending);
      await _applyLoudness();
      if (gen != _loadGen) return;
      await _setUrl(api.media(session!.streamUrl)!, resume);
      _publishItem();
      unawaited(audio.play());
      if (fresh) _queueEvent('start');
    } catch (e) {
      if (gen != _loadGen) return;
      error = e is ApiError && e.status == 402 ? _s.premiumEpisode : e is ApiError ? e.message : _s.offline;
      buffering = false;
      notifyListeners();
    }
  }

  void _onStreamError() {
    final c = current;
    if (c == null || session == null) return;
    if (_recoveries < 2) {
      _recoveries++;
      unawaited(_load(c, resume: audio.position));
      return;
    }
    error = _s.streamLost;
    notifyListeners();
  }

  int? _nextIndex() {
    if (queue.isEmpty) return null;
    final n = shuffle && queue.length > 1 ? (index + 1 + Random().nextInt(queue.length - 1)) % queue.length : index + 1;
    if (n < queue.length) return n;
    return repeat == LoopMode.all ? 0 : null;
  }

  bool _completing = false;

  /// Selesai alami → satu-satunya titik jeda iklan (tier Gratis), sebelum item berikutnya mulai.
  Future<void> _onCompleted() async {
    if (_completing) return;
    _completing = true;
    try {
      _queueEvent('complete');
      // Lagu harus sudah tercatat server (stream ≥ 30 dtk) sebelum jeda iklan diminta — tanpa ini, lagu yang event
      // progresnya belum terkirim belum terhitung dan jeda "setiap lagu" terlewat. Maks 2 dtk (offline → lanjut).
      if (adBreakAllowed) await _lastFlush?.timeout(const Duration(seconds: 2), onTimeout: () {});
      if (repeat == LoopMode.one && current != null) {
        await _adBreak(current!);
        await audio.seek(Duration.zero);
        unawaited(audio.play());
        return;
      }
      final n = _nextIndex();
      if (n == null) {
        await audio.pause();
        await audio.seek(Duration.zero);
        return;
      }
      index = n;
      await _adBreak(queue[n]);
      await _load(queue[index]);
    } finally {
      _completing = false;
    }
  }

  // ---- Iklan (best-effort: galat apa pun → lanjut memutar) ----
  /// Jeda iklan berlaku: Premium tidak pernah; akun Gratis selalu; tamu hanya bila `ads.anonymous_enabled`.
  bool get adBreakAllowed {
    final u = api.user;
    return u == null ? settings.adsAnonymous : !u.premium;
  }

  Future<void> _adBreak(Playable next) async {
    final u = api.user;
    if (_adBusy || !adBreakAllowed) return;
    _adBusy = true;
    try {
      final j = await api.post('/v1/ads/break', {
        'placement': next.kind == 'episode' ? 'podcast_preroll' : 'between_tracks',
        'content': {'kind': next.kind, 'id': next.id, if (next.premium) 'premium': true, if (next.contentWarning) 'content_warning': true},
      }).timeout(const Duration(seconds: 4)) as Json;
      var ads = (j['ads'] as List? ?? const []).map((a) => AdCreative.fromJson(a as Json)).toList();
      if (u == null) ads = ads.take(1).toList(); // tamu: paling banyak satu iklan
      for (var i = 0; i < ads.length; i++) {
        await _playAd(ads[i], i, ads.length);
      }
    } catch (_) {
      // tanpa iklan
    } finally {
      adTick.value = null;
      _adBusy = false;
      notifyListeners();
    }
  }

  Completer<void>? _adDone;
  Future<void> _playAd(AdCreative a, int i, int total) async {
    _adEvent(a, 'start');
    adTick.value = AdState(a, i, total, Duration.zero, false);
    notifyListeners();
    _adDone = Completer();
    final started = DateTime.now();
    Timer? t;
    StreamSubscription<PlayerState>? sub;
    if (a.type == 'audio' && a.audioUrl != null) {
      try {
        await _adAudio.setUrl(api.media(a.audioUrl)!);
        await _adAudio.setVolume(1.0);
        sub = _adAudio.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed && !(_adDone?.isCompleted ?? true)) {
            _adEvent(a, 'complete');
            _adDone!.complete();
          }
        });
        unawaited(_adAudio.play());
      } catch (_) {}
    }
    // Penghitung waktu (kartu display / cadangan bila audio iklan gagal).
    t = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final st = ad;
      if (st == null || _adDone == null || _adDone!.isCompleted) return;
      final el = st.paused ? st.elapsed : (a.type == 'audio' && _adAudio.playing ? _adAudio.position : DateTime.now().difference(started));
      adTick.value = AdState(a, i, total, el, st.paused);
      if (el.inSeconds >= a.durationS) {
        _adEvent(a, 'complete');
        _adDone!.complete();
      }
    });
    await _adDone!.future;
    t.cancel();
    await sub?.cancel();
    await _adAudio.stop();
  }

  void _adEvent(AdCreative a, String event) => unawaited(api.post('/v1/ads/impressions/${a.impressionId}/events', {'event': event}).catchError((_) => null));

  void skipAd() {
    final st = ad;
    if (st == null || st.skipIn != 0 || (_adDone?.isCompleted ?? true)) return;
    _adEvent(st.ad, 'skip');
    _adDone!.complete();
  }

  void adClicked() {
    if (ad != null) _adEvent(ad!.ad, 'click');
  }

  // ---- API publik untuk UI ----
  /// [context]: asal antrean (lihat [context]); null = antrean lepas (mis. hasil pencarian).
  Future<void> playQueue(List<Playable> items, [int start = 0, String? context]) async {
    if (items.isEmpty) return;
    queue = List.of(items);
    index = start;
    this.context = context;
    _publishQueue();
    if (_adBusy) return;
    await _load(items[start]);
  }

  Future<void> playOne(Playable item) async {
    context = null;
    queue = [...queue.take(index + 1), item, ...queue.skip(index + 1)];
    index = index + 1;
    _publishQueue();
    if (_adBusy) return;
    await _load(item);
  }

  void addToQueue(Playable item) {
    queue = [...queue, item];
    _publishQueue();
    notifyListeners();
  }

  Future<void> jump(int i) async {
    if (_adBusy || i < 0 || i >= queue.length) return;
    index = i;
    await _load(queue[i]);
  }

  Future<void> toggle() async {
    if (_adBusy) return;
    if (current == null) return;
    if (error != null && session == null) return retry();
    audio.playing ? await audio.pause() : unawaited(audio.play());
  }

  Future<void> next() async {
    if (_adBusy) return;
    final n = _nextIndex();
    if (n == null) return;
    index = n;
    await _load(queue[n]);
  }

  Future<void> prev() async {
    if (_adBusy) return;
    // >3 dtk (atau item pertama) → ulang dari awal — itu seek mundur, jadi hanya bila [canSeek].
    // Gratis tanpa izin geser: ke lagu sebelumnya bila ada; di item pertama tidak terjadi apa-apa.
    if (canSeek && (index <= 0 || audio.position > const Duration(seconds: 3))) return (debugSeek ?? audio.seek)(Duration.zero);
    if (index <= 0) return;
    index--;
    await _load(queue[index]);
  }

  /// Pendengar boleh menggeser posisi: Premium, atau Gratis bila `streaming.free_seek_enabled` aktif.
  /// Hanya membatasi seek dari pengguna ([seek]: slider, lirik, notifikasi/layar kunci, ±10 dtk) — seek internal
  /// (pemulihan stream, ulang satu lagu, kembali ke awal saat antrean habis) tetap jalan.
  bool get canSeek => Settings.seekAllowed(premium: api.user?.premium == true, freeSeek: settings.freeSeek);

  /// Pengganti `audio.seek` untuk pengujian (tanpa kanal platform just_audio).
  @visibleForTesting
  Future<void> Function(Duration)? debugSeek;

  /// Seek dari pengguna. Mengembalikan false bila ditolak (iklan berjalan, belum ada item, atau tier Gratis).
  Future<bool> seek(Duration d) async {
    if (_adBusy || current == null || !canSeek) return false;
    await (debugSeek ?? audio.seek)(d);
    return true;
  }

  Future<void> retry() async {
    if (current == null) return;
    _recoveries = 0;
    await _load(current!, resume: audio.position);
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    _publishState();
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = switch (repeat) { LoopMode.off => LoopMode.all, LoopMode.all => LoopMode.one, LoopMode.one => LoopMode.off };
    _publishState();
    notifyListeners();
  }

  /// Logout: hentikan pemutaran & buang event milik akun sebelumnya.
  Future<void> reset() async {
    _pending.clear();
    _flushTimer?.cancel();
    _flushTimer = null;
    _adDone?.isCompleted == false ? _adDone!.complete() : null;
    await audio.stop();
    queue = [];
    index = -1;
    context = null;
    current = null;
    session = null;
    error = null;
    _publishQueue();
    _handler.mediaItem.add(null);
    notifyListeners();
  }

  // ---- Sinkron ke audio_service (notifikasi & layar kunci) ----
  MediaItem _media(Playable p) => MediaItem(
        id: p.id,
        title: p.title,
        artist: p.subtitle,
        album: 'RAVE',
        duration: audio.duration ?? Duration(milliseconds: session?.durationMs ?? p.durationMs),
        artUri: api.media(p.imageUrl) == null ? null : Uri.parse(api.media(p.imageUrl)!),
      );

  void _publishItem() {
    if (current != null) _handler.mediaItem.add(_media(current!));
  }

  void _publishQueue() => _handler.queue.add(queue.map(_media).toList());

  void _publishState() {
    final st = audio.playerState;
    _handler.playbackState.add(PlaybackState(
      controls: [MediaControl.skipToPrevious, st.playing ? MediaControl.pause : MediaControl.play, MediaControl.skipToNext],
      // Gratis tanpa izin geser: notifikasi/layar kunci tidak menawarkan seek (bilah progres tak bisa digeser).
      systemActions: canSeek ? const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward} : const {},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (st.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      playing: st.playing,
      updatePosition: audio.position,
      bufferedPosition: audio.bufferedPosition,
      speed: audio.speed,
      queueIndex: index < 0 ? null : index,
      shuffleMode: shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
      repeatMode: switch (repeat) { LoopMode.off => AudioServiceRepeatMode.none, LoopMode.all => AudioServiceRepeatMode.all, LoopMode.one => AudioServiceRepeatMode.one },
    ));
  }
}

/// Jembatan audio_service: tombol notifikasi / layar kunci / headset → Player.
class _Handler extends BaseAudioHandler with SeekHandler {
  _Handler(this.p);
  final Player p;
  @override
  Future<void> play() => p.audio.play();
  @override
  Future<void> pause() => p.audio.pause();
  @override
  Future<void> stop() async {
    await p.flush();
    await p.audio.stop();
    return super.stop();
  }

  /// Juga dipakai SeekHandler untuk fastForward/rewind/seekForward — semuanya ditolak untuk Gratis (lihat [Player.canSeek]).
  @override
  Future<void> seek(Duration position) => p.seek(position);
  @override
  Future<void> skipToNext() => p.next();
  @override
  Future<void> skipToPrevious() => p.prev();
  @override
  Future<void> skipToQueueItem(int index) => p.jump(index);
}
