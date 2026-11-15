import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/theme.dart';
import 'common.dart';
import 'motion.dart';

/// Umpan balik khas RAVE — padanan web `components/ui` (ToastCard & confirmDialog).
///
/// Toast = "stiker": kertas/mustard/berry bertepi ink + bayangan sablon, kicker Space Mono (BERES!/CATAT/WADUH),
/// sampul opsional, aksi opsional (mis. Urungkan), sedikit miring, pita hitung mundur, hilang sendiri.
/// Maks. 3 sekaligus; pesan sama beruntun mengganti yang lama. Tampil di atas (tidak menutupi mini-player).

enum ToastKind { ok, info, error }

class ToastAction {
  const ToastAction(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
}

class _ToastItem {
  _ToastItem(this.id, this.kind, this.text, this.kicker, this.closeLabel, {this.title, this.image, this.action, required this.duration});
  final int id;
  final ToastKind kind;
  final String text, kicker, closeLabel;
  final String? title, image;
  final ToastAction? action;
  final Duration duration;
}

class _ToastHost {
  _ToastHost(this.overlay);
  final OverlayState overlay;
  final items = ValueNotifier<List<_ToastItem>>(const []);
  OverlayEntry? entry;

  void push(_ToastItem t) {
    final next = [t, ...items.value.where((x) => x.text != t.text)].take(3).toList();
    items.value = next;
    if (entry == null) {
      entry = OverlayEntry(builder: (_) => _ToastLayer(host: this));
      overlay.insert(entry!);
    }
  }

  void remove(int id) {
    items.value = items.value.where((x) => x.id != id).toList();
    if (items.value.isEmpty) {
      entry?.remove();
      entry = null;
    }
  }
}

final _hosts = Expando<_ToastHost>('rave-toasts');
var _toastSeq = 0;

/// Tampilkan stiker toast. `image` = URL sampul (relatif API boleh).
void showToast(BuildContext context, String text, {ToastKind kind = ToastKind.info, String? title, String? image, ToastAction? action, Duration? duration}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || !overlay.mounted) return;
  final s = App.maybeRead(context)?.s ?? S.of('id');
  final host = _hosts[overlay] ??= _ToastHost(overlay);
  final kicker = switch (kind) { ToastKind.ok => s.toastOk, ToastKind.error => s.toastErr, ToastKind.info => s.toastInfo };
  host.push(_ToastItem(
    ++_toastSeq,
    kind,
    text,
    kicker,
    s.close,
    title: title,
    image: image,
    action: action,
    duration: duration ?? (action != null || kind == ToastKind.error ? const Duration(seconds: 6) : const Duration(milliseconds: 3800)),
  ));
}

/// Galat → stiker berry (WADUH). Pesan galat generik bila objek tidak punya teks.
void toastError(BuildContext context, Object e) {
  final s = App.maybeRead(context)?.s ?? S.of('id');
  showToast(context, friendlyError(s, e), kind: ToastKind.error);
}

class _ToastLayer extends StatelessWidget {
  const _ToastLayer({required this.host});
  final _ToastHost host;
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<List<_ToastItem>>(
          valueListenable: host.items,
          builder: (context, items, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final t in items)
                Padding(
                  key: ValueKey(t.id),
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Dismissible(
                        key: ValueKey('d${t.id}'),
                        direction: DismissDirection.horizontal,
                        onDismissed: (_) => host.remove(t.id),
                        child: _ToastCard(t: t, onDone: () => host.remove(t.id)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({required this.t, required this.onDone});
  final _ToastItem t;
  final VoidCallback onDone;
  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with TickerProviderStateMixin {
  late final _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 420))..forward();
  late final _bar = AnimationController(vsync: this, duration: widget.t.duration)
    ..forward()
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) _close();
    });

  bool _closing = false;

  /// Keluar dengan animasi (mengecil + pudar + naik), lalu dilepas dari tumpukan.
  void _close() {
    if (_closing) return;
    _closing = true;
    if (RaveMotion.reduced(context)) return widget.onDone();
    _in.duration = const Duration(milliseconds: 200);
    _in.reverse().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _in.dispose();
    _bar.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final (Color bg, Color fg, Color kBg, Color kFg, Color bar, double rot) = switch (t.kind) {
      ToastKind.ok => (Rave.mustard, Rave.ink, Rave.ink, Rave.mustard, Rave.ink, -0.017),
      ToastKind.info => (Rave.paper, Rave.ink, Rave.purple, Rave.paper, Rave.purple, 0.017),
      ToastKind.error => (Rave.berry, Colors.white, Rave.ink, const Color(0xFFFF9A9A), const Color(0xCCFFFFFF), -0.017),
    };
    final anim = CurvedAnimation(parent: _in, curve: Curves.easeOutBack);
    return Semantics(
      liveRegion: true,
      container: true,
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _in, curve: const Interval(0, 0.5)),
        child: AnimatedBuilder(
          animation: anim,
          builder: (_, child) => Transform.translate(offset: Offset(0, -16 * (1 - anim.value)), child: Transform.scale(scale: 0.9 + 0.1 * anim.value, child: child)),
          child: Transform.rotate(
            angle: rot,
            child: GestureDetector(
              // Tahan = jeda hitung mundur (seperti hover di web).
              onLongPressStart: (_) => _bar.stop(),
              onLongPressEnd: (_) => _bar.forward(),
              child: Container(
                decoration: BoxDecoration(color: bg, border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(5, 5))]),
                child: Stack(children: [
                  IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (t.image != null)
                        Container(
                          width: 56,
                          decoration: const BoxDecoration(border: Border(right: BorderSide(color: Rave.ink, width: 2))),
                          child: Cover(t.image, size: 56),
                        ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 6, 12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              color: kBg,
                              child: Text(t.kicker.toUpperCase(), style: Rave.label(size: 10, color: kFg)),
                            ),
                            if (t.title != null) ...[
                              const SizedBox(height: 4),
                              Text(t.title!.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.poster(19, color: fg)),
                            ],
                            SizedBox(height: t.title != null ? 2 : 4),
                            Text(t.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13.5, weight: FontWeight.w600, color: fg.withValues(alpha: t.title != null ? 0.8 : 1), height: 1.25)),
                          ]),
                        ),
                      ),
                      if (t.action != null)
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              t.action!.onTap();
                              _close();
                            },
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 36),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(color: Rave.ink, border: Border.all(color: Rave.ink, width: 2)),
                              child: Text(t.action!.label.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)),
                            ),
                          ),
                        ),
                      Semantics(
                        button: true,
                        label: t.closeLabel,
                        child: InkResponse(
                          onTap: _close,
                          radius: 20,
                          child: Padding(padding: const EdgeInsets.all(10), child: Icon(Icons.close_rounded, size: 18, color: fg.withValues(alpha: 0.6))),
                        ),
                      ),
                    ]),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: AnimatedBuilder(
                      animation: _bar,
                      builder: (_, _) => Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(widthFactor: 1 - _bar.value, child: Container(height: 3, color: bar)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Konfirmasi RAVE (pengganti AlertDialog): panel gelap bertepi ink + bayangan sablon, bilah aksen (mustard; berry
/// untuk aksi berbahaya), kicker "Konfirmasi", judul Staatliches, sampul opsional, Batal + aksi.
/// Aksi berbahaya: fokus awal di Batal. `image`: URL sampul; `showImage` tanpa URL = kotak plum kosong.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? body,
  required String confirmLabel,
  String? cancelLabel,
  bool danger = false,
  String? image,
  bool showImage = false,
}) async {
  final s = App.maybeRead(context)?.s ?? S.of('id');
  final ok = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: s.close,
    barrierColor: const Color(0xB80A090B),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Curves.easeOutBack)), child: child),
    ),
    pageBuilder: (dctx, _, _) => _ConfirmPanel(
      title: title,
      body: body,
      kicker: s.confirmKicker,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel ?? s.cancel,
      closeLabel: s.close,
      danger: danger,
      image: image,
      showImage: showImage || image != null,
    ),
  );
  return ok == true;
}

class _ConfirmPanel extends StatelessWidget {
  const _ConfirmPanel({
    required this.title,
    required this.body,
    required this.kicker,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.closeLabel,
    required this.danger,
    required this.image,
    required this.showImage,
  });
  final String title, kicker, confirmLabel, cancelLabel, closeLabel;
  final String? body, image;
  final bool danger, showImage;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? Rave.berry : Rave.mustard;
    final rc = context.rc;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: rc.isLight ? const Color(0xFFFFFDF8) : const Color(0xFF1A171C),
              child: Semantics(
                container: true,
                explicitChildNodes: true,
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: Rave.ink, width: 2), boxShadow: rc.hard(6)),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(height: 4, color: accent),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 6, 0),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (showImage) ...[
                          Container(
                            decoration: BoxDecoration(border: Border.all(color: Rave.ink, width: 2), boxShadow: rc.hard()),
                            child: image != null
                                ? Cover(image, size: 60)
                                : Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.plum])),
                                  ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(kicker.toUpperCase(), style: Rave.label(size: 10, color: danger ? (rc.isLight ? Rave.berry : const Color(0xFFFF8F8F)) : rc.accent)),
                            const SizedBox(height: 4),
                            Text(title.toUpperCase(), style: Rave.poster(28)),
                          ]),
                        ),
                        IconButton(
                          tooltip: closeLabel,
                          onPressed: () => Navigator.pop(context, false),
                          icon: Icon(Icons.close_rounded, color: rc.muted),
                        ),
                      ]),
                    ),
                    if (body != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        child: Text(body!, style: Rave.body(size: 14, color: rc.text.withValues(alpha: 0.75), height: 1.45)),
                      )
                    else
                      const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      decoration: BoxDecoration(
                        color: rc.isLight ? const Color(0xFFF3EDE1) : const Color(0x33000000),
                        border: Border(top: BorderSide(color: rc.isLight ? const Color(0x1A181818) : const Color(0x14FFFFFF))),
                      ),
                      child: Wrap(alignment: WrapAlignment.end, spacing: 10, runSpacing: 10, children: [
                        DialogButton(label: cancelLabel, autofocus: danger, onTap: () => Navigator.pop(context, false)),
                        DialogButton(label: confirmLabel, variant: danger ? DialogVariant.danger : DialogVariant.primary, autofocus: !danger, onTap: () => Navigator.pop(context, true)),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum DialogVariant { ghost, primary, danger }

/// Tombol aksi dialog: ghost (garis), primary (mustard), danger (berry). Tinggi 44, gaya sablon RAVE.
class DialogButton extends StatelessWidget {
  const DialogButton({super.key, required this.label, required this.onTap, this.variant = DialogVariant.ghost, this.autofocus = false});
  final String label;
  final VoidCallback onTap;
  final DialogVariant variant;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color border) = switch (variant) {
      DialogVariant.primary => (Rave.mustard, Rave.ink, Rave.ink),
      DialogVariant.danger => (Rave.berry, Colors.white, Rave.ink),
      DialogVariant.ghost => (Colors.transparent, context.rc.text, context.rc.isLight ? const Color(0x33181818) : const Color(0x33FFFFFF)),
    };
    return Pressable(
      child: Material(
      color: bg,
      shape: RoundedRectangleBorder(side: BorderSide(color: border, width: 2)),
      child: InkWell(
        autofocus: autofocus,
        onTap: onTap,
        focusColor: Colors.white24,
        child: Container(
          constraints: const BoxConstraints(minWidth: 96, minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(label, style: Rave.body(size: 14, weight: FontWeight.w800, color: fg)),
        ),
      ),
      ),
    );
  }
}
