import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/api.dart';
import '../core/theme.dart';
import 'motion.dart';

/// Amplop spektrum per lagu dari server (`GET /v1/catalog/tracks/:id/spectrum`, kontrak sama dengan web & desktop):
/// [frames]×[bands] byte (frame-major, 0..255), [bands] pita log 40 Hz–16 kHz rendah → tinggi, [fps] frame per detik.
class SpectrumEnvelope {
  SpectrumEnvelope({required this.fps, required this.bands, required this.frames, required this.durationMs, required this.data});
  final double fps;
  final int bands, frames, durationMs;
  final Uint8List data;

  /// Respons JSON → amplop; null bila bentuknya tak valid (klien jatuh ke animasi dekoratif, tak pernah melempar).
  static SpectrumEnvelope? tryParse(Object? j) {
    if (j is! Map) return null;
    try {
      final fps = (j['fps'] as num).toDouble();
      final bands = (j['bands'] as num).toInt();
      final raw = j['data'];
      if (fps <= 0 || bands <= 0 || raw is! String) return null;
      final data = base64Decode(raw);
      final frames = min((j['frames'] as num?)?.toInt() ?? data.length ~/ bands, data.length ~/ bands);
      if (frames <= 0) return null;
      return SpectrumEnvelope(fps: fps, bands: bands, frames: frames, durationMs: (j['duration_ms'] as num?)?.toInt() ?? (frames / fps * 1000).round(), data: data);
    } catch (_) {
      return null;
    }
  }

  /// Indeks frame (pecahan) pada posisi putar: `positionMs / 1000 * fps`, dijepit ke rentang data.
  double frameAt(int positionMs) => (positionMs / 1000 * fps).clamp(0.0, (frames - 1).toDouble());

  /// Isi [out] (panjang = jumlah bilah) dengan level 0..1 di [positionMs]: interpolasi linear antar-frame, lalu
  /// pita di-resample ke jumlah bilah secara linear sepanjang frekuensi-log (pita sudah berjarak log → linear di
  /// indeks pita). Bilah pertama = pita terendah, bilah terakhir = pita tertinggi.
  void sample(int positionMs, List<double> out) {
    final f = frameAt(positionMs);
    final f0 = f.floor(), f1 = min(f0 + 1, frames - 1);
    final t = f - f0;
    final n = out.length;
    for (var i = 0; i < n; i++) {
      final pos = n <= 1 ? 0.0 : i * (bands - 1) / (n - 1);
      final b0 = pos.floor(), b1 = min(b0 + 1, bands - 1);
      final u = pos - b0;
      final a = data[f0 * bands + b0] * (1 - u) + data[f0 * bands + b1] * u;
      final c = data[f1 * bands + b0] * (1 - u) + data[f1 * bands + b1] * u;
      out[i] = (a * (1 - t) + c * t) / 255;
    }
  }
}

/// Jumlah bilah dari lebar (kontrak: bilah 3–4 px + celah 2 px) → `clamp(floor(w / 6), 16, 64)`.
int spectrumBars(double width) => (width / 6).floor().clamp(16, 64);

/// Animasi dekoratif (tanpa amplop: episode, iklan, 202/404/galat jaringan) — selebar & sebanyak bilah yang sama.
void decorativeSpectrum(double t, List<double> out) {
  final n = out.length;
  for (var i = 0; i < n; i++) {
    final x = n <= 1 ? 0.0 : i / (n - 1);
    final a = 0.5 + 0.5 * sin(t * 6.9 + i * 0.9);
    final b = 0.5 + 0.5 * sin(t * 4.3 - i * 0.37 + 1.3);
    out[i] = (0.12 + 0.8 * (0.55 * a + 0.45 * b) * (1 - 0.35 * x)).clamp(0.0, 1.0);
  }
}

enum SpectrumStatus { ready, pending, missing, error }

class SpectrumResult {
  const SpectrumResult(this.status, [this.envelope]);
  final SpectrumStatus status;
  final SpectrumEnvelope? envelope;
}

/// Ambil & simpan amplop di memori (LRU [capacity] lagu). 404 disimpan sebagai "tidak ada" untuk sesi ini; 202
/// tidak disimpan (boleh dicoba ulang ±30 dtk kemudian, maks [maxRetries]× per lagu per sesi); galat jaringan
/// tidak disimpan. Permintaan yang sedang berjalan untuk lagu yang sama dipakai bersama.
class SpectrumRepo {
  SpectrumRepo(this._fetch, {this.capacity = 20});
  final Future<Object?> Function(String trackId) _fetch;
  final int capacity;
  static const maxRetries = 2;
  static const retryAfter = Duration(seconds: 30);

  static final _byApi = Expando<SpectrumRepo>();

  /// Satu repo per klien API (cache bertahan selama aplikasi hidup).
  static SpectrumRepo forApi(Api api) =>
      _byApi[api] ??= SpectrumRepo((id) => api.request<Object?>('/v1/catalog/tracks/${Uri.encodeComponent(id)}/spectrum', timeout: const Duration(seconds: 15)));

  final _cache = <String, SpectrumEnvelope?>{}; // urutan sisip = urutan LRU
  final _inflight = <String, Future<SpectrumResult>>{};
  final _retries = <String, int>{};

  /// Hasil tersimpan (menyegarkan urutan LRU), atau null bila belum pernah diambil.
  SpectrumResult? peek(String id) {
    if (!_cache.containsKey(id)) return null;
    final e = _cache.remove(id);
    _cache[id] = e;
    return e == null ? const SpectrumResult(SpectrumStatus.missing) : SpectrumResult(SpectrumStatus.ready, e);
  }

  Future<SpectrumResult> load(String id) {
    final hit = peek(id);
    if (hit != null) return Future.value(hit);
    // Blok (bukan `=>`): whenComplete menunggu Future yang dikembalikan — mengembalikan Future ini sendiri = macet.
    return _inflight[id] ??= _go(id).whenComplete(() {
      _inflight.remove(id);
    });
  }

  /// Boleh mencoba ulang setelah 202? Sekaligus mencatat percobaannya.
  bool takeRetry(String id) {
    final n = _retries[id] ?? 0;
    if (n >= maxRetries) return false;
    _retries[id] = n + 1;
    return true;
  }

  Future<SpectrumResult> _go(String id) async {
    try {
      final j = await _fetch(id);
      if (j is Map && j['status'] == 'pending' && j['data'] == null) return const SpectrumResult(SpectrumStatus.pending);
      final env = SpectrumEnvelope.tryParse(j);
      if (env == null) return const SpectrumResult(SpectrumStatus.error);
      _put(id, env);
      return SpectrumResult(SpectrumStatus.ready, env);
    } on ApiError catch (e) {
      if (e.status == 404) {
        _put(id, null);
        return const SpectrumResult(SpectrumStatus.missing);
      }
      return const SpectrumResult(SpectrumStatus.error);
    } catch (_) {
      return const SpectrumResult(SpectrumStatus.error);
    }
  }

  void _put(String id, SpectrumEnvelope? e) {
    _cache.remove(id);
    _cache[id] = e;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
  }
}

/// Status bilah (level + topi puncak) — juga `repaint` listenable bagi [SpectrumPainter]: tiap frame hanya
/// menggambar ulang kanvas, tanpa membangun ulang widget.
class SpectrumEngine extends ChangeNotifier {
  /// Lantai saat jeda / berhenti.
  static const idle = 0.05;
  static const attackMs = 40.0, releaseMs = 180.0, pausedReleaseMs = 260.0;
  static const peakHoldMs = 320.0, peakFallPerS = 0.9;

  Float64List levels = Float64List(0), peaks = Float64List(0), _hold = Float64List(0);

  /// Topi puncak digambar (mati saat gerak dikurangi).
  bool caps = true;
  int get bars => levels.length;

  /// Ganti jumlah bilah (tanpa notifikasi — dipanggil saat tata letak).
  void resize(int n) {
    if (n == bars) return;
    final old = levels;
    levels = Float64List(n);
    peaks = Float64List(n);
    _hold = Float64List(n);
    for (var i = 0; i < n; i++) {
      // Pertahankan bentuk lama (sampel terdekat) agar ganti ukuran tak berkedip.
      levels[i] = old.isEmpty ? idle : old[min(old.length - 1, (i * old.length / n).floor())];
      peaks[i] = levels[i];
    }
  }

  /// Semua bilah sudah turun ke lantai (ticker boleh berhenti saat jeda).
  bool get settled {
    for (var i = 0; i < bars; i++) {
      if (levels[i] > idle + 0.004 || (caps && peaks[i] > idle + 0.004)) return false;
    }
    return true;
  }

  /// Maju [dtMs]: [target] null = jeda (turun pelan ke lantai, topi jatuh). [snap] = lompat langsung (seek).
  void step(double dtMs, List<double>? target, {bool snap = false}) {
    final up = 1 - exp(-dtMs / attackMs);
    final down = 1 - exp(-dtMs / (target == null ? pausedReleaseMs : releaseMs));
    for (var i = 0; i < bars; i++) {
      final want = target == null ? idle : target[i].clamp(idle, 1.0);
      final l = levels[i];
      levels[i] = snap ? want : l + (want - l) * (want > l ? up : down);
      if (!caps) {
        peaks[i] = levels[i];
      } else if (snap || levels[i] >= peaks[i]) {
        peaks[i] = levels[i];
        _hold[i] = snap ? 0 : peakHoldMs;
      } else if (_hold[i] > 0) {
        _hold[i] = max(0, _hold[i] - dtMs);
      } else {
        peaks[i] = max(levels[i], peaks[i] - peakFallPerS * dtMs / 1000);
      }
    }
    notifyListeners();
  }

  /// Set level langsung (gerak dikurangi / bilah statis). [notify] false saat dipanggil dari build.
  void set(List<double> values, {bool notify = true}) {
    for (var i = 0; i < bars && i < values.length; i++) {
      levels[i] = values[i].clamp(idle, 1.0);
      peaks[i] = levels[i];
      _hold[i] = 0;
    }
    if (notify) notifyListeners();
  }

  void floor({bool notify = true}) => set(List.filled(bars, idle), notify: notify);
}

/// Bilah spektrum LCD — palet mustard (#f4c21f dasar, #ffd650 tengah, #ff6a3d ujung), cahaya tipis, topi puncak.
/// Bilah memenuhi lebar penuh: bilah pertama mulai di x = 0, bilah terakhir berakhir tepat di tepi kanan.
class SpectrumPainter extends CustomPainter {
  SpectrumPainter(this.engine, {this.dim = false}) : super(repaint: engine);
  final SpectrumEngine engine;
  final bool dim;

  static const base = Color(0xFFF4C21F), mid = Color(0xFFFFD650), tip = Color(0xFFFF6A3D);

  /// Geometri bilah [i] dari [n] di lebar [w]: (x, lebar). Celah 2 px (lebih sempit bila bilah sangat rapat).
  static (double, double) bar(int i, int n, double w) {
    final gap = min(2.0, w / n * 0.34);
    final pitch = (w + gap) / n;
    return (i * pitch, pitch - gap);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = engine.bars;
    if (n == 0 || size.isEmpty) return;
    final h = size.height, capH = 1.5, room = h - capH - 1;
    final bars = Path(), caps = Path();
    for (var i = 0; i < n; i++) {
      final (x, bw) = bar(i, n, size.width);
      final bh = max(1.0, engine.levels[i] * room);
      bars.addRect(Rect.fromLTWH(x, h - bh, bw, bh));
      if (engine.caps && !dim) {
        final py = h - max(bh, engine.peaks[i] * room) - capH - 1;
        caps.addRect(Rect.fromLTWH(x, py, bw, capH));
      }
    }
    if (dim) {
      canvas.drawPath(bars, Paint()..color = base.withValues(alpha: 0.3));
      return;
    }
    canvas.drawPath(bars, Paint()
      ..color = const Color(0x40F4C21F)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    canvas.drawPath(
      bars,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Rave.mustard, base, mid, tip],
          stops: [0, 0.55, 0.8, 1],
        ).createShader(Offset.zero & size),
    );
    if (engine.caps) canvas.drawPath(caps, Paint()..color = mid);
  }

  @override
  bool shouldRepaint(SpectrumPainter old) => old.engine != engine || old.dim != dim;
}

/// Spektrum LCD yang mengikuti lagu: amplop server diputar sinkron dengan posisi pemutar (interpolasi antar-frame,
/// attack/release, topi puncak), memenuhi lebar yang tersedia. Tanpa amplop → animasi dekoratif selebar sama.
///
/// Ticker hanya berjalan saat diputar (atau saat bilah masih turun setelah jeda), aplikasi aktif, dan rute terlihat
/// (TickerMode). Gerak dikurangi → bilah statis dari frame saat ini, diperbarui ≤ 4×/dtk, tanpa topi puncak.
class DeckSpectrum extends StatefulWidget {
  const DeckSpectrum({super.key, this.trackId, required this.playing, this.position, this.repo, this.dim = false, this.height = 28});

  /// Lagu yang amplopnya dipakai; null = selalu dekoratif (episode, iklan, live).
  final String? trackId;
  final bool playing, dim;

  /// Posisi putar saat ini (just_audio mengekstrapolasi `position` saat berputar → mulus per frame).
  final Duration Function()? position;
  final SpectrumRepo? repo;
  final double height;

  @override
  State<DeckSpectrum> createState() => DeckSpectrumState();
}

@visibleForTesting
class DeckSpectrumState extends State<DeckSpectrum> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final engine = SpectrumEngine();
  late final Ticker _ticker = createTicker(_onTick);
  Float64List _target = Float64List(0);
  SpectrumEnvelope? _env;
  int _req = 0;
  Timer? _retry, _reducedTimer;
  bool _resumed = true, _reduced = false;
  Duration _lastTick = Duration.zero;
  int? _lastPos;
  double _t = 0;

  /// Amplop aktif (null = dekoratif).
  SpectrumEnvelope? get envelope => _env;

  /// Ticker animasi sedang berjalan.
  bool get animating => _ticker.isActive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final st = WidgetsBinding.instance.lifecycleState;
    _resumed = st == null || st == AppLifecycleState.resumed;
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = RaveMotion.reduced(context);
    engine.caps = !_reduced;
    _sync();
  }

  @override
  void didUpdateWidget(DeckSpectrum oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trackId != widget.trackId || oldWidget.repo != widget.repo) _load();
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _req++;
    _retry?.cancel();
    _reducedTimer?.cancel();
    _ticker.dispose();
    engine.dispose();
    super.dispose();
  }

  void _load() {
    _retry?.cancel();
    final req = ++_req;
    _env = null;
    _lastPos = null;
    final id = widget.trackId, repo = widget.repo;
    if (id == null || repo == null) return;
    final hit = repo.peek(id);
    if (hit != null) {
      _env = hit.envelope;
      return;
    }
    _fetch(repo, id, req);
  }

  void _fetch(SpectrumRepo repo, String id, int req) {
    repo.load(id).then((r) {
      // Respons basi (lagu sudah berganti / widget dilepas) diabaikan.
      if (!mounted || req != _req) return;
      if (r.status == SpectrumStatus.ready) {
        _env = r.envelope;
        _lastPos = null;
        _sync();
      } else if (r.status == SpectrumStatus.pending && repo.takeRetry(id)) {
        _retry = Timer(SpectrumRepo.retryAfter, () {
          if (mounted && req == _req) _fetch(repo, id, req);
        });
      }
    }, onError: (Object _) {});
  }

  /// Nyalakan/matikan ticker (atau timer 4×/dtk saat gerak dikurangi) sesuai status.
  void _sync() {
    if (!mounted) return;
    if (_reduced) {
      if (_ticker.isActive) _ticker.stop();
      final run = widget.playing && _resumed && _env != null;
      if (run && _reducedTimer == null) {
        _reducedTimer = Timer.periodic(const Duration(milliseconds: 250), (_) => _applyReduced());
      } else if (!run) {
        _reducedTimer?.cancel();
        _reducedTimer = null;
      }
      _applyReduced();
      return;
    }
    _reducedTimer?.cancel();
    _reducedTimer = null;
    final run = _resumed && (widget.playing || !engine.settled);
    if (run && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!run && _ticker.isActive) {
      _ticker.stop();
    }
  }

  /// Gerak dikurangi: frame saat ini (berputar + amplop), bilah dekoratif statis (berputar tanpa amplop), atau lantai.
  void _applyReduced({bool notify = true}) {
    if (engine.bars == 0) return;
    if (widget.playing && _env != null && widget.position != null) {
      _env!.sample(widget.position!().inMilliseconds, _target);
      engine.set(_target, notify: notify);
    } else if (widget.playing) {
      decorativeSpectrum(0.6, _target);
      engine.set(_target, notify: notify);
    } else {
      engine.floor(notify: notify);
    }
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _lastTick).inMicroseconds / 1000).clamp(0.0, 100.0);
    _lastTick = elapsed;
    advance(dt);
    if (!widget.playing && engine.settled) _ticker.stop();
  }

  /// Satu langkah animasi sebesar [dtMs] (dipanggil ticker; publik untuk uji).
  @visibleForTesting
  void advance(double dtMs) {
    if (engine.bars == 0) return;
    _t += dtMs / 1000;
    if (!widget.playing) return engine.step(dtMs, null);
    final env = _env;
    var snap = false;
    if (env != null && widget.position != null) {
      final pos = widget.position!().inMilliseconds;
      final prev = _lastPos;
      // Seek (posisi melompat jauh dari perkiraan) → bilah langsung ke frame baru, tanpa smoothing.
      snap = prev != null && (pos - prev - dtMs).abs() > 750;
      _lastPos = pos;
      env.sample(pos, _target);
    } else {
      decorativeSpectrum(_t, _target);
    }
    engine.step(dtMs, _target, snap: snap);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : 160.0;
        final n = spectrumBars(w);
        if (n != engine.bars) {
          engine.resize(n);
          _target = Float64List(n);
          if (_reduced) _applyReduced(notify: false);
        }
        return RepaintBoundary(
          child: CustomPaint(
            key: const Key('lcd-spectrum'),
            size: Size(w, widget.height),
            painter: SpectrumPainter(engine, dim: widget.dim),
          ),
        );
      });
}
