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
  Player(this.api, this.settings);
  final Api api;
  final Settings settings;
  final audio = AudioPlayer();
  final _adAudio = AudioPlayer();
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
  AdState? ad;
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
    audio.playerStateStream.listen((st) {
      final b = st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering;
      if (b != buffering) buffering = b;
      if (st.processingState == ProcessingState.completed) unawaited(_onCompleted());
      _publishState();
      notifyListeners();
    });
    audio.positionStream.listen(_onPosition);
    audio.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace _) => _onStreamError());
    // Telepon masuk / headset dicabut → jeda (praktik aplikasi musik).
    session.becomingNoisyEventStream.listen((_) => audio.pause());
    session.interruptionEventStream.listen((e) {
      if (e.begin) audio.pause();
    });
  }

  void _onPosition(Duration p) {
    final now = DateTime.now();
    if (audio.playing && _lastTick != null) _playedMs += min(1000, now.difference(_lastTick!).inMilliseconds);
    _lastTick = now;
    final s = session;
    if (s != null && s.previewOnly && s.previewMs != null && p.inMilliseconds >= s.previewMs!) {
      audio.pause();
      error = _s.previewEnded;
      notifyListeners();
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
      unawaited(flush());
    } else {
      _flushTimer ??= Timer.periodic(const Duration(seconds: 30), (_) => flush());
    }
  }

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

  /// [resume] > 0: pemulihan item yang sama (stream kedaluwarsa/putus) — lanjut dari posisi terakhir.
  Future<void> _load(Playable item, {Duration resume = Duration.zero}) async {
    final fresh = resume == Duration.zero;
    if (fresh) {
      _recoveries = 0;
      if (current != null && audio.playing && audio.position < duration - const Duration(seconds: 2)) _queueEvent('skip');
      _playedMs = 0;
      _lastProgressAt = 0;
    }
    await audio.stop();
    current = item;
    session = null;
    error = null;
    buffering = true;
    notifyListeners();
    _publishItem();
    try {
      final j = await api.post('/v1/playback/sessions', {item.kind == 'track' ? 'track_id' : 'episode_id': item.id, 'quality': settings.requestQuality}) as Json;
      if (current?.id != item.id) return;
      session = PlaybackSession.fromJson(j);
      final cap = session!.qualityCapped;
      if (cap != null && cap != 'preview' && !_premiumNotified) {
        _premiumNotified = true;
        _messages.add(cap == 'premium' ? _s.premiumQuality : cap == 'disabled' ? _s.qualityDisabled : _s.qualityUnavailable);
      }
      await audio.setUrl(api.media(session!.streamUrl)!, initialPosition: resume);
      _publishItem();
      unawaited(audio.play());
      if (fresh) _queueEvent('start');
    } catch (e) {
      if (current?.id != item.id) return;
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
  Future<void> _adBreak(Playable next) async {
    final u = api.user;
    if (u == null || u.premium || _adBusy) return;
    _adBusy = true;
    try {
      final j = await api.post('/v1/ads/break', {
        'placement': next.kind == 'episode' ? 'podcast_preroll' : 'between_tracks',
        'content': {'kind': next.kind, 'id': next.id, if (next.premium) 'premium': true, if (next.contentWarning) 'content_warning': true},
      }).timeout(const Duration(seconds: 4)) as Json;
      final ads = (j['ads'] as List? ?? const []).map((a) => AdCreative.fromJson(a as Json)).toList();
      for (var i = 0; i < ads.length; i++) {
        await _playAd(ads[i], i, ads.length);
      }
    } catch (_) {
      // tanpa iklan
    } finally {
      ad = null;
      _adBusy = false;
      notifyListeners();
    }
  }

  Completer<void>? _adDone;
  Future<void> _playAd(AdCreative a, int i, int total) async {
    _adEvent(a, 'start');
    ad = AdState(a, i, total, Duration.zero, false);
    notifyListeners();
    _adDone = Completer();
    final started = DateTime.now();
    Timer? t;
    StreamSubscription<PlayerState>? sub;
    if (a.type == 'audio' && a.audioUrl != null) {
      try {
        await _adAudio.setUrl(api.media(a.audioUrl)!);
        await _adAudio.setVolume(audio.volume);
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
      ad = AdState(a, i, total, el, st.paused);
      notifyListeners();
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
  Future<void> playQueue(List<Playable> items, [int start = 0]) async {
    if (items.isEmpty) return;
    queue = List.of(items);
    index = start;
    _publishQueue();
    if (_adBusy) return;
    await _load(items[start]);
  }

  Future<void> playOne(Playable item) async {
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
    if (audio.position > const Duration(seconds: 3) || index <= 0) return audio.seek(Duration.zero);
    index--;
    await _load(queue[index]);
  }

  Future<void> seek(Duration d) async {
    if (_adBusy || current == null) return;
    await audio.seek(d);
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
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
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

  @override
  Future<void> seek(Duration position) => p.seek(position);
  @override
  Future<void> skipToNext() => p.next();
  @override
  Future<void> skipToPrevious() => p.prev();
  @override
  Future<void> skipToQueueItem(int index) => p.jump(index);
}
