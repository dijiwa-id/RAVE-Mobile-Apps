import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Sampul/foto dari API dengan cache disk; cadangan piringan hitam bila kosong/gagal.
class Cover extends StatelessWidget {
  const Cover(this.url, {super.key, this.size, this.round = false, this.radius = 0});
  final String? url;
  final double? size;
  final bool round;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final src = App.of(context).api.media(url);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fallback = const _Groove();
    Widget img = src == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: src,
            fit: BoxFit.cover,
            memCacheWidth: size == null ? null : (size! * dpr).round(),
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => const ColoredBox(color: Rave.raised),
            errorWidget: (_, _, _) => fallback,
          );
    img = SizedBox(width: size, height: size, child: ColoredBox(color: Rave.raised, child: img));
    if (round) return ClipOval(child: img);
    if (radius > 0) return ClipRRect(borderRadius: BorderRadius.circular(radius), child: img);
    return img;
  }
}

class _Groove extends StatelessWidget {
  const _Groove();
  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, c) {
          final d = min(c.maxWidth, c.maxHeight);
          return Center(
            child: Container(
              width: d * 0.76,
              height: d * 0.76,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [Color(0xFF1D1B1F), Color(0xFF111111), Color(0xFF1D1B1F), Color(0xFF111111)], stops: [0.2, 0.21, 0.6, 1]),
              ),
            ),
          );
        },
      );
}

/// Tombol putar khas RAVE: kotak mustard, ikon ink, bayangan sablon (bukan lingkaran).
class PlayButton extends StatelessWidget {
  const PlayButton({super.key, required this.playing, required this.onTap, this.size = 52, this.semantic});
  final bool playing;
  final VoidCallback onTap;
  final double size;
  final String? semantic;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantic,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
            child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Rave.ink, size: size * 0.55),
          ),
        ),
      );
}

/// Teks label mono kapital.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color = Rave.muted, this.size = 10.5});
  final String text;
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Rave.label(size: size, color: color));
}

/// Judul rak/seksi bergaya poster.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 26, 16, 10),
        child: Row(children: [Expanded(child: Text(text.toUpperCase(), style: Rave.poster(26))), ?action]),
      );
}

/// Memuat data API dengan cache SWR; tampilan muat/galat/ulang seragam. Tarik ke bawah untuk menyegarkan.
class ApiView<T> extends StatefulWidget {
  const ApiView({super.key, required this.path, required this.parse, required this.builder, this.query, this.loading});
  final String path;
  final Map<String, String>? query;
  final T Function(Json) parse;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  final Widget? loading;

  @override
  State<ApiView<T>> createState() => _ApiViewState<T>();
}

class _ApiViewState<T> extends State<ApiView<T>> {
  T? data;
  Object? error;
  String get key => widget.query == null ? widget.path : '${widget.path}?${Uri(queryParameters: widget.query).query}';

  @override
  void initState() {
    super.initState();
    final cached = App.read(context).cache.peek(key);
    if (cached is T) data = cached;
    _load();
  }

  @override
  void didUpdateWidget(ApiView<T> old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || old.query?.toString() != widget.query?.toString()) {
      data = null;
      error = null;
      _load();
    }
  }

  Future<void> _load({bool force = false}) async {
    final app = App.read(context);
    try {
      final v = await app.cache.load(key, () async => widget.parse(await app.api.get(widget.path, query: widget.query)) as Object, force: force);
      if (mounted) setState(() => (data = v as T, error = null));
    } catch (e) {
      if (mounted && data == null) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    if (data != null) {
      return RefreshIndicator(
        color: Rave.mustard,
        backgroundColor: Rave.raised,
        onRefresh: () => _load(force: true),
        child: widget.builder(context, data as T, () => _load(force: true)),
      );
    }
    if (error != null) {
      return ErrorState(
        message: error is OfflineError ? s.offline : error.toString(),
        retry: () {
          setState(() => error = null);
          _load(force: true);
        },
      );
    }
    return widget.loading ?? const Center(child: CircularProgressIndicator(color: Rave.mustard, strokeWidth: 2.5));
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.retry});
  final String message;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, color: Rave.berry, size: 36),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: Rave.body(color: Rave.muted)),
            const SizedBox(height: 16),
            OutlineButton(label: App.of(context).s.retry, onTap: retry),
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          const SizedBox(width: 64, height: 64, child: _Groove()),
          const SizedBox(height: 12),
          Text(title.toUpperCase(), textAlign: TextAlign.center, style: Rave.poster(24)),
        ]),
      );
}

/// Tombol garis (sekunder).
class OutlineButton extends StatelessWidget {
  const OutlineButton({super.key, required this.label, required this.onTap, this.active = false});
  final String label;
  final VoidCallback? onTap;
  final bool active;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(border: Border.all(color: active ? Rave.paper : Rave.line, width: 1.5)),
          child: Text(label.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)),
        ),
      );
}

/// Tombol primer: mustard berteks ink dengan bayangan sablon.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Rave.ink))
                : Text(label.toUpperCase(), style: Rave.label(size: 12.5, color: Rave.ink)),
          ),
        ),
      );
}

/// Ekualiser kecil penanda lagu yang sedang diputar.
class Equalizer extends StatefulWidget {
  const Equalizer({super.key, required this.playing});
  final bool playing;
  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  @override
  void initState() {
    super.initState();
    if (widget.playing) c.repeat();
  }

  @override
  void didUpdateWidget(Equalizer old) {
    super.didUpdateWidget(old);
    widget.playing ? c.repeat() : c.stop();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: c,
        builder: (_, _) => Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(3, (i) {
            final h = 0.25 + 0.75 * (0.5 + 0.5 * sin((c.value + i / 3) * 2 * pi));
            return Container(width: 3, height: 14 * h, margin: const EdgeInsets.symmetric(horizontal: 1), color: Rave.mustard);
          }),
        ),
      );
}

/// Format durasi m:ss / h:mm:ss.
String fmtDuration(int ms) {
  final s = max(0, ms ~/ 1000);
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, ss = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

String fmtTotal(int ms, bool id) {
  final min = (ms / 60000).round();
  if (min < 60) return '$min ${id ? 'mnt' : 'min'}';
  return '${min ~/ 60} ${id ? 'j' : 'hr'} ${min % 60} ${id ? 'mnt' : 'min'}';
}

String fmtCompact(int n, String locale) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)} ${locale == 'id' ? 'jt' : 'M'}';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)} ${locale == 'id' ? 'rb' : 'K'}';
  return '$n';
}

void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 3)));
}
