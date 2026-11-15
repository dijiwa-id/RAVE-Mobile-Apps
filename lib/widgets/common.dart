import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'feedback.dart';
import 'motion.dart';

/// Pesan galat yang ramah: offline → ajakan cek koneksi; galat API 4xx → pesan server (sudah ramah pengguna);
/// selain itu (5xx, galat Dart mentah seperti FormatException/TimeoutException) → pesan generik + ajakan coba lagi.
String friendlyError(S s, Object e) {
  if (e is OfflineError) return s.offline;
  if (e is ApiError && e.status >= 400 && e.status < 500 && e.message.trim().isNotEmpty && !e.message.startsWith('HTTP ')) return e.message;
  return s.genericError;
}

/// Sampul/foto dari API dengan cache disk; cadangan piringan hitam bila kosong/gagal.
class Cover extends StatelessWidget {
  const Cover(this.url, {super.key, this.size, this.round = false, this.radius = 0, this.placeholderIcon});
  final String? url;
  final double? size;
  final bool round;
  final double radius;

  /// Tanpa gambar: kotak berikon (mis. playlist tanpa sampul) alih-alih piringan — ukuran tetap, tidak kolaps.
  final IconData? placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final src = App.of(context).api.media(url);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final rc = context.rc;
    final bg = rc.isLight ? rc.hover : Rave.raised;
    final Widget fallback = placeholderIcon == null
        ? const _Groove()
        : LayoutBuilder(
            builder: (_, c) => DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: rc.isLight ? [rc.hover, rc.base] : const [Rave.hover, Rave.raised])),
              child: Center(child: Icon(placeholderIcon, color: rc.subtle, size: (c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 48) * 0.42)),
            ),
          );
    Widget img = src == null
        ? fallback
        : CachedNetworkImage(
            imageUrl: src,
            fit: BoxFit.cover,
            memCacheWidth: size == null ? null : (size! * dpr).round(),
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (_, _) => ColoredBox(color: bg),
            errorWidget: (_, _, _) => fallback,
          );
    img = SizedBox(width: size, height: size, child: ColoredBox(color: bg, child: img));
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

/// SATU tombol putar/jeda untuk seluruh aplikasi (web `PlayFab`): kotak mustard bertepi ink + bayangan sablon.
///  - [playKey] (disarankan): tombol tahu sendiri apakah itemnya sedang diputar → ikon Jeda (berganti dengan animasi),
///    dan ketukan saat aktif menjeda/melanjutkan (tidak mengulang). Kunci: `release:` · `playlist:` · `artist:` ·
///    `liked` · `show:` · `track:`/`episode:`.
///  - tanpa [playKey]: pemanggil mengatur [playing] & aksinya sendiri.
/// Ukuran: 32 (baris) · 40 (kartu ringkas) · 48 (kartu) · 56 (header halaman).
class PlayFab extends StatelessWidget {
  const PlayFab({super.key, required this.onPlay, this.playKey, this.playing = false, this.size = 48, this.semantic});
  final VoidCallback onPlay;
  final String? playKey;
  final bool playing;
  final double size;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final shadow = context.rc.shadow;
    if (playKey == null) return _fab(App.maybeRead(context)?.s ?? S.of('id'), playing, false, onPlay, shadow);
    final app = App.of(context);
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final p = app.player;
        final active = p.isActive(playKey);
        return _fab(app.s, p.isPlayingKey(playKey), active && p.buffering && p.error == null, active ? p.toggle : onPlay, shadow);
      },
    );
  }

  Widget _fab(S s, bool on, bool loading, VoidCallback tap, Color shadow) {
    final icon = size * (size <= 32 ? 0.6 : 0.55);
    final key = loading ? 'load' : on ? 'pause' : 'play';
    return Semantics(
      button: true,
      toggled: playKey == null ? null : on,
      label: on ? s.pause : (semantic ?? s.play),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          tap();
        },
        child: Pressable(
          scale: 0.92,
          child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Rave.mustard,
            border: Border.all(color: Rave.ink, width: 2),
            boxShadow: [BoxShadow(color: shadow, offset: size <= 32 ? const Offset(2, 2) : const Offset(3, 3))],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutBack,
            // Putar ↔ Jeda: berputar seperempat putaran + membesar (morf ala tombol tape).
            transitionBuilder: (child, a) => RotationTransition(
              turns: Tween(begin: -0.25, end: 0.0).animate(a),
              child: ScaleTransition(scale: Tween(begin: 0.4, end: 1.0).animate(a), child: FadeTransition(opacity: a, child: child)),
            ),
            child: loading
                ? SizedBox(key: ValueKey(key), width: icon * 0.7, height: icon * 0.7, child: const CircularProgressIndicator(strokeWidth: 2.2, color: Rave.ink))
                : Icon(on ? Icons.pause_rounded : Icons.play_arrow_rounded, key: ValueKey(key), color: Rave.ink, size: icon),
          ),
        ),
        ),
      ),
    );
  }
}

/// Choice chips RAVE (filter tunggal, web `ChoiceChips`): kotak bertepi tipis; terpilih = mustard bertepi ink +
/// bayangan sablon. Bergulir horizontal.
class RaveChoiceChips<T> extends StatelessWidget {
  const RaveChoiceChips({super.key, required this.value, required this.options, required this.onChanged, this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 6)});
  final T value;
  final List<({T value, String label, IconData? icon, bool dot})> options;
  final ValueChanged<T> onChanged;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => FadedEdges(
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        padding: padding,
        child: Row(children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 3),
              child: RaveChip(label: o.label, icon: o.icon, dot: o.dot, selected: o.value == value, onTap: () => onChanged(o.value)),
            ),
        ]),
      ),
      );
}

class RaveChip extends StatelessWidget {
  const RaveChip({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.dot = false});
  final String label;
  final bool selected, dot;
  final IconData? icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final fg = selected ? Rave.ink : rc.text;
    final d = RaveMotion.reduced(context) ? Duration.zero : const Duration(milliseconds: 240);
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: () {
          if (!selected) HapticFeedback.selectionClick();
          onTap();
        },
        child: Pressable(
          child: AnimatedContainer(
            duration: d,
            curve: Curves.easeOutBack,
            height: 36,
            transform: Matrix4.translationValues(selected ? -1 : 0, selected ? -1 : 0, 0),
            decoration: BoxDecoration(
              color: rc.chip,
              border: Border.all(color: selected ? Rave.ink : rc.chipBorder, width: selected ? 2 : 1),
              boxShadow: selected ? rc.hard() : [BoxShadow(color: rc.shadow.withValues(alpha: 0), offset: Offset.zero)],
            ),
            // Isi mustard "menyapu" dari kiri saat dipilih.
            child: Stack(alignment: Alignment.centerLeft, children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: d,
                    curve: Curves.easeOutCubic,
                    widthFactor: selected ? 1 : 0,
                    heightFactor: 1,
                    child: const ColoredBox(color: Rave.mustard),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 7)],
                  Text(label, style: Rave.body(size: 13.5, weight: FontWeight.w700, color: fg)),
                  if (dot) ...[const SizedBox(width: 7), Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle))],
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Saklar RAVE: trek kotak bertepi ink, kenop kotak; aktif = mustard (web `.rave-switch`).
class RaveSwitch extends StatelessWidget {
  const RaveSwitch({super.key, required this.value, required this.onChanged, this.label});
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final rc = context.rc;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 48,
              height: 26,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? Rave.mustard : (rc.isLight ? const Color(0xFFD9D1C1) : const Color(0xFF2A272D)),
                border: Border.all(color: Rave.ink, width: 2),
                boxShadow: value || rc.isLight ? rc.hard(2) : const [],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 16, height: 16, decoration: BoxDecoration(color: value ? Rave.ink : (rc.isLight ? rc.base : Rave.muted), border: Border.all(color: Rave.ink, width: 1))),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Teks label mono kapital.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color, this.size = 10.5});
  final String text;
  /// Tanpa warna → teks sekunder tema.
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: Rave.label(size: size, color: color ?? context.rc.muted));
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
  const ApiView({super.key, required this.path, required this.parse, required this.builder, this.query, this.loading, this.revision = 0});
  final String path;
  final Map<String, String>? query;
  final T Function(Json) parse;
  final Widget Function(BuildContext, T, Future<void> Function() reload) builder;
  final Widget? loading;
  /// Berubah → muat ulang di latar (data lama tetap tampil, tanpa spinner).
  final int revision;

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
    } else if (old.revision != widget.revision) {
      _load(force: true);
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
      // Tarik-segarkan RAVE: isi meregang seperti kain + stiker kaset (tanpa celah kosong di atas).
      return RaveRefresh(
        onRefresh: () => _load(force: true),
        child: widget.builder(context, data as T, () => _load(force: true)),
      );
    }
    if (error != null) {
      return ErrorState(
        message: friendlyError(s, error!),
        retry: () {
          setState(() => error = null);
          _load(force: true);
        },
      );
    }
    return widget.loading ?? const ListSkeleton();
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
            Text(message, textAlign: TextAlign.center, style: Rave.body(color: context.rc.muted)),
            const SizedBox(height: 16),
            OutlineButton(label: App.of(context).s.retry, onTap: retry),
          ]),
        ),
      );
}

/// Keadaan kosong: judul poster + (opsional) dorongan ramah + CTA.
class EmptyState extends StatelessWidget {
  const EmptyState(this.title, {super.key, this.body, this.action, this.onAction});
  final String title;
  final String? body, action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          const SizedBox(width: 64, height: 64, child: _Groove()),
          const SizedBox(height: 12),
          Text(title.toUpperCase(), textAlign: TextAlign.center, style: Rave.poster(24)),
          if (body != null) ...[
            const SizedBox(height: 8),
            Text(body!, textAlign: TextAlign.center, style: Rave.body(color: context.rc.muted)),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 18),
            OutlineButton(label: action!, onTap: onAction),
          ],
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
          decoration: BoxDecoration(border: Border.all(color: active ? context.rc.text : (context.rc.isLight ? context.rc.chipBorder : Rave.line), width: 1.5)),
          child: Text(label.toUpperCase(), style: Rave.label(size: 11, color: context.rc.text)),
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
          child: Pressable(
            child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: context.rc.hard()),
            child: busy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Rave.ink))
                : Text(label.toUpperCase(), style: Rave.label(size: 12.5, color: Rave.ink)),
          ),
          ),
        ),
      );
}

/// Bilah EQ kecil penanda lagu yang sedang diputar (diam saat dijeda).
class EqBars extends StatefulWidget {
  const EqBars({super.key, required this.playing, this.color, this.height = 14});
  final bool playing;
  /// Tanpa warna → aksen tema (mustard gelap / ungu terang).
  final Color? color;
  final double height;
  @override
  State<EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<EqBars> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  @override
  void initState() {
    super.initState();
    if (widget.playing) c.repeat();
  }

  @override
  void didUpdateWidget(EqBars old) {
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
          children: List.generate(4, (i) {
            final h = widget.playing ? 0.25 + 0.75 * (0.5 + 0.5 * sin((c.value * (1 + i * 0.15) + i / 4) * 2 * pi)) : const [0.4, 0.7, 0.5, 0.85][i];
            return Container(width: 3, height: widget.height * h, margin: const EdgeInsets.symmetric(horizontal: 1), color: widget.color ?? context.rc.accent);
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

/// Stiker toast singkat (lihat `feedback.dart` untuk opsi: jenis, judul, sampul, aksi).
void toast(BuildContext context, String text, {ToastKind kind = ToastKind.info, String? title, String? image, ToastAction? action}) =>
    showToast(context, text, kind: kind, title: title, image: image, action: action);
