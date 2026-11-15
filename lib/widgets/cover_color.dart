import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Warna dominan sampul untuk latar ambient (web `useCoverColor`): gambar didekode kecil (24×24, lewat cache disk
/// gambar yang sama), piksel berwarna diutamakan (berat ∝ saturasi, piksel nyaris hitam/putih diredam), lalu
/// saturasi ≤ 62% dan kecerahan 16–30% agar teks putih & aksen mustard tetap terbaca. Tanpa paket tambahan.
final _cache = <String, Color>{};

Color? cachedCoverColor(String? url) => url == null ? null : _cache[url];

Future<Color?> coverColor(String url) async {
  final hit = _cache[url];
  if (hit != null) return hit;
  ui.Image? img;
  try {
    img = await _decodeSmall(ResizeImage(CachedNetworkImageProvider(url), width: 24, height: 24)).timeout(const Duration(seconds: 8));
    final data = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final c = dominantFromRgba(data.buffer.asUint8List());
    if (c != null) _cache[url] = c;
    return c;
  } catch (_) {
    return null;
  } finally {
    img?.dispose();
  }
}

Future<ui.Image> _decodeSmall(ImageProvider provider) {
  final done = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener l;
  l = ImageStreamListener((info, _) {
    if (!done.isCompleted) done.complete(info.image.clone());
    info.dispose();
    stream.removeListener(l);
  }, onError: (Object e, StackTrace? st) {
    if (!done.isCompleted) done.completeError(e, st);
    stream.removeListener(l);
  });
  stream.addListener(l);
  return done.future;
}

/// Rata-rata berbobot saturasi dari piksel RGBA → warna yang dibatasi (HSL). Null bila tak ada piksel.
Color? dominantFromRgba(List<int> px) {
  double r = 0, g = 0, b = 0, wsum = 0;
  for (var i = 0; i + 3 < px.length; i += 4) {
    if (px[i + 3] < 16) continue;
    final rr = px[i], gg = px[i + 1], bb = px[i + 2];
    final mx = [rr, gg, bb].reduce((a, c) => a > c ? a : c), mn = [rr, gg, bb].reduce((a, c) => a < c ? a : c);
    final lum = (mx + mn) / 2;
    final w = (mx - mn + 8) * (lum < 24 || lum > 236 ? 0.15 : 1.0);
    r += rr * w;
    g += gg * w;
    b += bb * w;
    wsum += w;
  }
  if (wsum == 0) return null;
  final avg = Color.fromARGB(255, (r / wsum).round(), (g / wsum).round(), (b / wsum).round());
  final hsl = HSLColor.fromColor(avg);
  return hsl.withSaturation(hsl.saturation.clamp(0.0, 0.62)).withLightness(hsl.lightness.clamp(0.16, 0.30)).toColor();
}

/// Bangun ulang dengan warna sampul (transisi halus); [fallback] (ungu RAVE) selama memuat / tanpa sampul.
class CoverColorBuilder extends StatefulWidget {
  const CoverColorBuilder({super.key, required this.url, required this.builder, this.fallback = Rave.purple});
  final String? url;
  final Color fallback;
  final Widget Function(BuildContext, Color) builder;
  @override
  State<CoverColorBuilder> createState() => _CoverColorBuilderState();
}

class _CoverColorBuilderState extends State<CoverColorBuilder> {
  late Color _color = cachedCoverColor(widget.url) ?? widget.fallback;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(CoverColorBuilder old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _resolve();
  }

  void _resolve() {
    final url = widget.url;
    if (url == null) {
      _color = widget.fallback;
      return;
    }
    coverColor(url).then((c) {
      if (mounted && widget.url == url) setState(() => _color = c ?? widget.fallback);
    });
  }

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: _color),
        duration: const Duration(milliseconds: 900),
        builder: (context, c, _) => widget.builder(context, c ?? _color),
      );
}
