import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Nama platform embed (sama dengan EMBED_PROVIDERS di server: packages/domain/src/podcast.ts).
const embedLabels = {
  'spotify': 'Spotify',
  'youtube': 'YouTube',
  'apple': 'Apple Podcasts',
  'soundcloud': 'SoundCloud',
  'anchor': 'Spotify for Creators',
};

/// Halaman publik platform asal untuk tombol "Buka di …" (aplikasi Spotify/YouTube bila terpasang).
String embedPageUrl(EpisodeEmbed e) {
  final yt = RegExp(r'youtube-nocookie\.com/embed/([\w-]{11})').firstMatch(e.src);
  if (yt != null) return 'https://www.youtube.com/watch?v=${yt.group(1)}';
  final ytl = RegExp(r'videoseries\?list=([\w-]+)').firstMatch(e.src);
  if (ytl != null) return 'https://www.youtube.com/playlist?list=${ytl.group(1)}';
  if (e.provider == 'spotify') return e.src.replaceFirst('/embed/', '/');
  if (e.provider == 'apple') return e.src.replaceFirst('embed.podcasts.apple.com', 'podcasts.apple.com');
  final sc = RegExp(r'[?&]url=([^&]+)').firstMatch(e.src);
  if (sc != null) return Uri.decodeComponent(sc.group(1)!);
  return e.src.replaceFirst('/embed', '');
}

/// Pemutar episode embed dari platform lain di dalam aplikasi (WebView). `src` sudah dinormalisasi server (host resmi,
/// https) — WebView hanya memuat iframe itu; navigasi ke luar host embed dibuka di aplikasi/peramban eksternal.
/// Tidak dihitung sebagai stream RAVE.
class EmbedPlayer extends StatefulWidget {
  const EmbedPlayer({super.key, required this.embed, required this.title});
  final EpisodeEmbed embed;
  final String title;

  @override
  State<EmbedPlayer> createState() => _EmbedPlayerState();
}

class _EmbedPlayerState extends State<EmbedPlayer> {
  late final WebViewController _web;
  bool _loading = true;

  static const _escape = HtmlEscape(HtmlEscapeMode.attribute);

  @override
  void initState() {
    super.initState();
    final src = Uri.parse(widget.embed.src);
    final html = '<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<style>html,body{margin:0;padding:0;height:100%;background:transparent;overflow:hidden}iframe{border:0;width:100%;height:100%}</style>'
        '</head><body><iframe src="${_escape.convert(widget.embed.src)}" allow="autoplay; encrypted-media; fullscreen; picture-in-picture" allowfullscreen '
        'referrerpolicy="strict-origin-when-cross-origin"></iframe></body></html>';
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onNavigationRequest: (req) {
          final u = Uri.tryParse(req.url);
          // Dokumen pembungkus & iframe embed boleh dimuat; tautan lain (mis. "Buka di Spotify") → aplikasi eksternal.
          if (u == null || u.scheme == 'about' || u.scheme == 'data' || u.host == 'localhost' || u.host == src.host) return NavigationDecision.navigate;
          if (!req.isMainFrame) return NavigationDecision.navigate;
          launchUrl(u, mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      // Origin https agar pemutar (mis. YouTube) menerima referrer yang sah.
      ..loadHtmlString(html, baseUrl: 'https://localhost/');
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final label = embedLabels[widget.embed.provider] ?? widget.embed.provider;
    final video = widget.embed.kind == 'video';
    final player = Stack(children: [
      WebViewWidget(controller: _web),
      if (_loading) const Positioned.fill(child: Center(child: SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)))),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRect(child: video ? AspectRatio(aspectRatio: 16 / 9, child: player) : SizedBox(height: widget.embed.height.toDouble(), child: player)),
      const SizedBox(height: 6),
      Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 4, children: [
        Text(app.s.embedVia(label), style: Rave.body(size: 11.5, color: context.rc.subtle)),
        InkWell(
          onTap: () => launchUrl(Uri.parse(embedPageUrl(widget.embed)), mode: LaunchMode.externalApplication),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.open_in_new_rounded, size: 13, color: context.rc.accent),
            const SizedBox(width: 3),
            Text(app.s.openIn(label), style: Rave.body(size: 12, weight: FontWeight.w700, color: context.rc.accent)),
          ]),
        ),
      ]),
    ]);
  }
}
