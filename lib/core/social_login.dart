import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Login sosial dari aplikasi (gaya device flow, sama dengan desktop):
/// POST /v1/auth/oauth/:provider/app → buka `start_path` di browser sistem → polling POST /v1/auth/oauth/poll.
/// Browser menampilkan kode pencocokan; aplikasi menampilkan kode yang sama.

const socialProviders = ['google', 'apple', 'facebook', 'dev'];

class SocialLaunch {
  const SocialLaunch({required this.provider, required this.startPath, required this.pollToken, required this.userCode, required this.expiresIn, required this.interval});
  final String provider;
  final String startPath;
  final String pollToken;
  final String userCode;
  final int expiresIn;
  final int interval;

  factory SocialLaunch.fromJson(String provider, Json j) => SocialLaunch(
        provider: provider,
        startPath: j['start_path'] as String,
        pollToken: j['poll_token'] as String,
        userCode: j['user_code'] as String,
        expiresIn: (j['expires_in'] as num?)?.toInt() ?? 600,
        interval: ((j['interval'] as num?)?.toInt() ?? 2).clamp(1, 10),
      );
}

enum SocialPollState { pending, done, error, expired }

class SocialPollResult {
  const SocialPollResult(this.state, {this.tokens, this.message});
  final SocialPollState state;
  final Json? tokens;
  final String? message;
}

/// Petakan respons HTTP polling → status (428 menunggu, 200 token, 400 gagal, 410/lainnya kedaluwarsa).
SocialPollResult socialPollFromResponse(int status, Object? body) {
  final j = body is Json ? body : const <String, dynamic>{};
  if (status == 200 && j['access_token'] is String) return SocialPollResult(SocialPollState.done, tokens: j);
  if (status == 428) return const SocialPollResult(SocialPollState.pending);
  if (status == 400 || status == 403) return SocialPollResult(SocialPollState.error, message: (j['detail'] ?? j['title'])?.toString());
  return SocialPollResult(SocialPollState.expired, message: j['detail']?.toString());
}

/// Mesin polling: [tick] satu langkah (diuji langsung), timer memanggilnya tiap `interval` detik.
/// Dijeda saat aplikasi di latar belakang; [resume] langsung memeriksa sekali (pengguna baru kembali dari browser).
class SocialLoginFlow extends ChangeNotifier {
  SocialLoginFlow(this.launch, {required this.poll, required this.onDone, DateTime Function()? now}) : _now = now ?? DateTime.now {
    _deadline = _now().add(Duration(seconds: launch.expiresIn));
  }

  final SocialLaunch launch;
  final Future<SocialPollResult> Function(String pollToken) poll;
  final Future<void> Function(Json tokens) onDone;
  final DateTime Function() _now;
  late final DateTime _deadline;

  SocialPollState state = SocialPollState.pending;
  String? message;
  Timer? _timer;
  bool _inFlight = false, _closed = false;

  bool get finished => state != SocialPollState.pending;

  void start() {
    if (_closed) return;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: launch.interval), (_) => tick());
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_closed || finished) return;
    tick();
    start();
  }

  void cancel() {
    _closed = true;
    pause();
  }

  Future<SocialPollState> tick() async {
    if (_closed || finished || _inFlight) return state;
    if (_now().isAfter(_deadline)) return _finish(SocialPollState.expired, null);
    _inFlight = true;
    try {
      final r = await poll(launch.pollToken);
      if (_closed) return state;
      switch (r.state) {
        case SocialPollState.pending:
          return state;
        case SocialPollState.done:
          await onDone(r.tokens!);
          return _finish(SocialPollState.done, null);
        case SocialPollState.error:
        case SocialPollState.expired:
          return _finish(r.state, r.message);
      }
    } catch (_) {
      // Jaringan putus sesaat: coba lagi di tick berikutnya (batas waktu tetap berlaku).
      return state;
    } finally {
      _inFlight = false;
    }
  }

  SocialPollState _finish(SocialPollState s, String? msg) {
    state = s;
    message = msg;
    pause();
    notifyListeners();
    return s;
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
