import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/i18n.dart';
import '../core/models.dart';
import '../core/share.dart';
import '../core/theme.dart';
import 'brand_marks.dart';
import 'common.dart';
import 'feedback.dart';

/// Ikon bagikan tunggal di seluruh aplikasi (glyph tiga simpul = lucide `Share2` di web & desktop).
const shareIcon = Icons.share;

/// Facebook App ID (opsional, `--dart-define=RAVE_FB_APP_ID=…`): mengaktifkan intent resmi Instagram
/// `ADD_TO_STORY` (+ `content_url`). Tanpa ID → kartu dikirim ke aktivitas "Cerita" Instagram lewat ACTION_SEND.
const _fbAppId = String.fromEnvironment('RAVE_FB_APP_ID');

const _channel = MethodChannel('id.dijiwa.rave/share');

/// Pengaturan bagikan dari config platform yang sudah dimuat aplikasi (shell memuatnya saat start).
/// Belum dimuat / server lama → bawaan aktif; data bagikan server tetap menjadi penentu akhir.
ShareFlags shareFlagsOf(AppState app) {
  final j = app.cache.peek('cfg:platform');
  final cfg = j is Json && j['settings'] is Json ? j['settings'] as Json : const <String, dynamic>{};
  return ShareFlags.fromConfig(cfg);
}

/// Tombol bagikan ditampilkan? (false = Super Admin mematikan `share.enabled` → disembunyikan di semua tempat.)
bool shareEnabled(AppState app) => shareFlagsOf(app).enabled;

/// Lembar bagikan lagu (RAVE): Instagram Story, X, Facebook (hanya yang aktif), Salin tautan, Lainnya….
Future<void> showShareSheet(BuildContext context, {required String trackId, required String title, required String artist, String? cover}) async {
  final app = App.read(context);
  if (!shareEnabled(app)) return;
  HapticFeedback.selectionClick();
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => ShareSheet(trackId: trackId, title: title, artist: artist, cover: cover, host: context),
  );
}

class ShareSheet extends StatefulWidget {
  const ShareSheet({super.key, required this.trackId, required this.title, required this.artist, this.cover, required this.host});
  final String trackId, title, artist;
  final String? cover;

  /// Konteks pemanggil (tetap hidup setelah lembar ditutup) untuk toast & share sheet sistem.
  final BuildContext host;

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  ShareLoad? _load;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  void _fetch() {
    final repo = ShareRepo.of(App.read(context).api);
    final hit = repo.peek(widget.trackId);
    if (hit != null) {
      _load = hit;
      return;
    }
    setState(() => _load = null);
    unawaited(repo.load(widget.trackId).then((r) {
      if (mounted) setState(() => _load = r);
    }));
  }

  AppState get _app => App.read(context);

  /// Tutup lembar lalu jalankan [then] dengan konteks pemanggil (bila masih terpasang).
  void _closeThen(void Function(BuildContext host) then) {
    if (mounted) Navigator.of(context).pop();
    if (widget.host.mounted) then(widget.host);
  }

  Future<void> _copy(TrackShare s) async {
    final app = _app;
    recordShare(app.api, s.trackId, 'copy');
    await Clipboard.setData(ClipboardData(text: s.fullText));
    _closeThen((h) => showToast(h, app.s.linkCopied, kind: ToastKind.ok));
  }

  Future<void> _system(TrackShare s) async {
    final app = _app;
    recordShare(app.api, s.trackId, 'system');
    _closeThen((_) {});
    try {
      await SharePlus.instance.share(ShareParams(text: s.fullText, subject: '${s.title} — ${s.artist}'));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: s.fullText));
      final h = widget.host;
      if (h.mounted) showToast(h, app.s.linkCopied, kind: ToastKind.ok);
    }
  }

  Future<void> _intent(TrackShare s, SharePlatformLink p) async {
    final app = _app;
    recordShare(app.api, s.trackId, p.id);
    _closeThen((_) {});
    var ok = false;
    try {
      // App X/Facebook terpasang → tautan intent dibuka di aplikasinya (App Links); selain itu browser.
      ok = await launchUrl(Uri.parse(p.url!), mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: s.fullText));
      final h = widget.host;
      if (h.mounted) showToast(h, app.s.shareOpenFailed);
    }
  }

  Future<void> _instagram(TrackShare s) async {
    if (_busy != null) return;
    final app = _app;
    final str = app.s;
    setState(() => _busy = 'instagram');
    recordShare(app.api, s.trackId, 'instagram');
    // Tautan selalu disalin dulu → bisa ditempel sebagai stiker tautan di Story.
    await Clipboard.setData(ClipboardData(text: s.url));
    Uint8List? png;
    try {
      final cover = await loadShareCover(app.api, s.imageUrl ?? widget.cover);
      png = await renderStoryCard(s, tagline: '${str.shareNowPlaying} RAVE', cover: cover);
      cover?.dispose();
    } catch (_) {
      png = null;
    }
    if (!mounted) return;
    setState(() => _busy = null);
    _closeThen((_) {});
    final h = widget.host;
    if (png == null) {
      if (h.mounted) showToast(h, str.shareIgFailed);
      return;
    }
    var sent = false;
    try {
      sent = await _channel.invokeMethod<bool>('instagramStory', {'png': png, 'contentUrl': s.url, 'appId': _fbAppId}) ?? false;
    } catch (_) {
      sent = false;
    }
    if (!sent) {
      // Instagram tidak ada / gagal → share sheet sistem dengan gambar + teks.
      try {
        await SharePlus.instance.share(ShareParams(
          text: s.fullText,
          subject: '${s.title} — ${s.artist}',
          files: [XFile.fromData(png, mimeType: 'image/png')],
          fileNameOverrides: [storyFileName(s.title)],
        ));
      } catch (_) {}
    }
    if (h.mounted) showToast(h, str.shareIgPaste, kind: ToastKind.ok, duration: const Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final rc = context.rc;
    final load = _load;
    Widget body;
    if (load is ShareReady) {
      final share = load.share;
      final platforms = visiblePlatforms(share, shareFlagsOf(app));
      body = Column(mainAxisSize: MainAxisSize.min, children: [
        if (platforms.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Rave.gutter, 4, Rave.gutter, 8),
            child: Row(children: [
              for (final p in platforms) ...[
                if (p != platforms.first) const SizedBox(width: 10),
                Expanded(
                  child: _PlatformTile(
                    key: Key('share-${p.id}'),
                    platform: p.id,
                    label: _label(s, p.id),
                    busy: _busy == p.id,
                    onTap: _busy != null ? null : () => p.id == 'instagram' ? unawaited(_instagram(share)) : unawaited(_intent(share, p)),
                  ),
                ),
              ],
            ]),
          ),
        if (_busy == 'instagram')
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(s.shareMaking, style: Rave.label(size: 10, color: rc.muted))),
        const SizedBox(height: 4),
        _Row(key: const Key('share-copy'), icon: Icons.link_rounded, label: s.shareCopy, onTap: _busy != null ? null : () => unawaited(_copy(share))),
        _Row(key: const Key('share-system'), icon: Icons.more_horiz_rounded, label: s.shareSystem, onTap: _busy != null ? null : () => unawaited(_system(share))),
      ]);
    } else if (load is ShareUnavailable || load is ShareFailed) {
      final offline = load is ShareFailed;
      body = Padding(
        key: const Key('share-unavailable'),
        padding: const EdgeInsets.fromLTRB(Rave.gutter, 8, Rave.gutter, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(offline ? Icons.wifi_off_rounded : Icons.hourglass_empty_rounded, size: 20, color: rc.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(s.shareUnavailable, style: Rave.body(size: 15, weight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(offline ? s.shareOffline : s.shareUnavailableBody, style: Rave.body(size: 13.5, color: rc.muted)),
          if (offline) ...[
            const SizedBox(height: 12),
            OutlineButton(key: const Key('share-retry'), label: s.shareRetry, onTap: _fetch),
          ],
        ]),
      );
    } else {
      body = Padding(
        key: const Key('share-loading'),
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: rc.accent)),
          const SizedBox(width: 10),
          Text(s.shareLoading, style: Rave.body(color: rc.muted)),
        ]),
      );
    }
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(Rave.gutter, 0, Rave.gutter, 6), child: Eyebrow(s.shareTrack)),
        ListTile(
          leading: Cover(widget.cover, size: 48),
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 16, weight: FontWeight.w700)),
          subtitle: Text(widget.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(color: rc.muted)),
        ),
        const Divider(height: 1),
        const SizedBox(height: 10),
        AnimatedSize(duration: const Duration(milliseconds: 180), alignment: Alignment.topCenter, child: body),
        const SizedBox(height: 8),
      ]),
    );
  }

  static String _label(S s, String id) => switch (id) { 'instagram' => s.shareInstagram, 'x' => s.shareX, _ => s.shareFacebook };
}

/// Tombol platform besar ala stiker RAVE (bingkai tinta + bayangan keras).
class _PlatformTile extends StatelessWidget {
  const _PlatformTile({super.key, required this.platform, required this.label, required this.onTap, this.busy = false});
  final String platform, label;
  final VoidCallback? onTap;
  final bool busy;
  @override
  Widget build(BuildContext context) {
    final rc = context.rc;
    final (bg, fg) = switch (platform) {
      'instagram' => (const Color(0xFFC13584), Colors.white),
      'x' => (const Color(0xFF0B0A0C), Colors.white),
      _ => (const Color(0xFF1877F2), Colors.white),
    };
    return Semantics(
      button: true,
      label: label,
      child: Opacity(
        opacity: onTap == null && !busy ? 0.55 : 1,
        child: Material(
          color: rc.raised,
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
              decoration: BoxDecoration(border: Border.all(color: rc.isLight ? Rave.ink : Rave.line, width: 1.5)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: bg, border: Border.all(color: Rave.ink, width: 2), boxShadow: rc.hard()),
                  alignment: Alignment.center,
                  child: busy
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                      : SocialGlyph(platform, size: 24, color: fg),
                ),
                const SizedBox(height: 10),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: Rave.body(size: 12.5, weight: FontWeight.w700)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        enabled: onTap != null,
        leading: Icon(icon, color: context.rc.text),
        title: Text(label, style: Rave.body(size: 15, weight: FontWeight.w600)),
        onTap: onTap,
      );
}

// ---- Logo media sosial (vektor satu warna, tanpa paket SVG) ----
// X: Simple Icons (CC0), viewBox 24×24.
const _xPath = 'M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z';

class SocialGlyph extends StatelessWidget {
  const SocialGlyph(this.platform, {super.key, this.size = 24, this.color = Colors.white});
  final String platform;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (platform == 'facebook') return Icon(Icons.facebook, size: size, color: color);
    return CustomPaint(size: Size.square(size), painter: _GlyphPainter(platform, color));
  }
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.platform, this.color);
  final String platform;
  final Color color;
  static final _x = parseSvgPath(_xPath);
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.save();
    canvas.scale(k);
    final fill = Paint()..color = color..isAntiAlias = true;
    if (platform == 'x') {
      canvas.drawPath(_x, fill);
    } else {
      // Instagram: kotak membulat + lensa + titik.
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..isAntiAlias = true;
      canvas.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(2.5, 2.5, 19, 19), const Radius.circular(5.5)), stroke);
      canvas.drawCircle(const Offset(12, 12), 4.4, stroke);
      canvas.drawCircle(const Offset(17.4, 6.6), 1.35, fill);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.platform != platform || old.color != color;
}

// ---- Kartu cerita Instagram 1080×1920 ----

const storyCardSize = Size(1080, 1920);

String storyFileName(String title) {
  final slug = title.replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return 'RAVE-${slug.isEmpty ? 'story' : (slug.length > 40 ? slug.substring(0, 40) : slug)}.png';
}

/// Sampul untuk kartu: media lokal server (`/v1/...`) diambil lewat alamat server aplikasi (URL absolut publik
/// server dev bisa tak terjangkau dari ponsel), lainnya apa adanya. Gagal → null (kartu tanpa sampul).
Future<ui.Image?> loadShareCover(Api api, String? url, {http.Client? client}) async {
  if (url == null || url.isEmpty) return null;
  try {
    var u = Uri.parse(api.media(url)!);
    if (u.path.startsWith('/v1/')) u = Uri.parse('${api.base}${u.path}${u.hasQuery ? '?${u.query}' : ''}');
    final c = client ?? http.Client();
    try {
      final r = await c.get(u).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200 || r.bodyBytes.isEmpty) return null;
      final codec = await ui.instantiateImageCodec(r.bodyBytes, targetWidth: 1080, allowUpscaling: false);
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } finally {
      if (client == null) c.close();
    }
  } catch (_) {
    return null;
  }
}

/// Kartu cerita sebagai widget (dirender di luar layar oleh [renderStoryCard]; tata letak sama dengan web storyCard.ts).
class StoryCard extends StatelessWidget {
  const StoryCard({super.key, required this.title, required this.artist, required this.link, required this.tagline, this.cover, this.logo});
  final String title, artist, link, tagline;
  final ui.Image? cover;

  /// Logo RAVE asli (`assets/brand/rave-logo.webp`: huruf putih + piringan ungu). Null → cadangan ikon V + teks.
  final ui.Image? logo;

  @override
  Widget build(BuildContext context) {
    const w = 1080.0, h = 1920.0, art = 760.0, top = 330.0;
    final img = cover;
    return SizedBox(
      width: w,
      height: h,
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        const Positioned.fill(child: ColoredBox(color: Rave.ink)),
        if (img != null)
          Positioned.fill(
            child: ClipRect(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60, tileMode: TileMode.clamp),
                child: Transform.scale(
                  scale: 1.15,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0x73000000), BlendMode.darken),
                    child: RawImage(image: img, fit: BoxFit.cover, width: w, height: h),
                  ),
                ),
              ),
            ),
          ),
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x8C5B2A6E), Color(0x59181818), Color(0xEB0B0A0C)],
                stops: [0, 0.55, 1],
              ),
            ),
          ),
        ),
        Positioned(
          left: 80,
          right: 80,
          top: 214,
          child: Text(tagline.toUpperCase(), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.label(size: 30, color: Rave.mustard)),
        ),
        // Sampul persegi + bayangan sablon RAVE.
        Positioned(left: (w - art) / 2 + 22, top: top + 22, width: art, height: art, child: const ColoredBox(color: Rave.shadow)),
        Positioned(
          left: (w - art) / 2,
          top: top,
          width: art,
          height: art,
          child: Container(
            foregroundDecoration: BoxDecoration(border: Border.all(color: Rave.shadow, width: 6)),
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.mustard])),
            child: img == null
                ? const Center(child: RaveMark(size: 260, color: Color(0xCCFFFFFF)))
                : ClipRect(child: RawImage(image: img, fit: BoxFit.cover, width: art, height: art)),
          ),
        ),
        Positioned(
          left: 80,
          right: 80,
          top: 1170,
          child: Column(children: [
            Text(title.toUpperCase(), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.poster(92, color: Rave.paper).copyWith(height: 1.0)),
            const SizedBox(height: 22),
            Text(artist, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 46, weight: FontWeight.w600, color: const Color(0xBFEDEDED))),
          ]),
        ),
        // Merek: logo asli selebar 400 px, tepi bawah di y=1690 (±55 px di atas pil tautan) — sama dengan web storyCard.ts.
        if (logo != null)
          Positioned(
            left: (w - 400) / 2,
            top: 1690 - 400 * logo!.height / logo!.width,
            width: 400,
            height: 400 * logo!.height / logo!.width,
            child: RawImage(image: logo, fit: BoxFit.contain, filterQuality: FilterQuality.high),
          )
        else
          Positioned(
            left: 80,
            right: 80,
            top: 1590,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const RaveMark(size: 150, color: Rave.paper),
              const SizedBox(width: 18),
              Text('RAVE', style: Rave.poster(124, color: Rave.paper)),
            ]),
          ),
        Positioned(
          left: 60,
          right: 60,
          top: 1745,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
              decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 4)),
              child: Text(link, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.label(size: 28, color: Rave.ink).copyWith(letterSpacing: 0.5)),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Render [StoryCard] di luar layar (pohon widget tersendiri → RepaintBoundary.toImage) → PNG 1080×1920.
/// Logo RAVE asli disertakan di kartu (gagal dimuat → cadangan ikon V + teks).
Future<Uint8List> renderStoryCard(TrackShare s, {required String tagline, ui.Image? cover, bool withLogo = true}) async {
  final logo = withLogo ? await loadRaveLogo() : null;
  try {
    return await renderWidgetPng(
      StoryCard(title: s.title, artist: s.artist, link: s.shortUrl, tagline: tagline, cover: cover, logo: logo),
      storyCardSize,
    );
  } finally {
    logo?.dispose();
  }
}

/// `assets/brand/rave-logo.webp` (420×246, untuk latar gelap) → ui.Image; galat → null.
Future<ui.Image?> loadRaveLogo({AssetBundle? bundle}) async {
  try {
    final data = await (bundle ?? rootBundle).load('assets/brand/rave-logo.webp');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// Render widget apa pun ke PNG tanpa menampilkannya (tanpa gambar jaringan: semua aset harus sudah dimuat).
Future<Uint8List> renderWidgetPng(Widget widget, Size size, {double pixelRatio = 1}) async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final boundary = RenderRepaintBoundary();
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(logicalConstraints: BoxConstraints.tight(size), devicePixelRatio: 1),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focus = FocusManager();
  final build = BuildOwner(focusManager: focus);
  RenderObjectToWidgetElement<RenderBox>? root;
  try {
    root = RenderObjectToWidgetAdapter<RenderBox>(
      container: boundary,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Directionality(textDirection: TextDirection.ltr, child: DefaultTextStyle(style: const TextStyle(decoration: TextDecoration.none), child: widget)),
      ),
    ).attachToRenderTree(build);
    build.buildScope(root);
    build.finalizeTree();
    pipeline.flushLayout();
    pipeline.flushCompositingBits();
    pipeline.flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('png');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    // Lepas pohon sementara (anak dikosongkan → elemen & render object, termasuk klon gambar, dibuang).
    try {
      if (root != null) {
        RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(build, root);
        build.buildScope(root);
        build.finalizeTree();
      }
    } catch (_) {}
    focus.dispose();
    pipeline.rootNode = null;
    pipeline.dispose();
  }
}
