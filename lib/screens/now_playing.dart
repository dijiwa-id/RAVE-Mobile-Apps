import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/cover_color.dart';
import '../widgets/media.dart';
import '../widgets/motion.dart';
import '../widgets/vinyl.dart';
import '../widgets/deck.dart';
import 'shell.dart';

void openNowPlaying(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      // Tidak opak: saat ditarik ke bawah, layar sebelumnya terlihat di baliknya.
      opaque: false,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const NowPlayingScreen(),
      transitionsBuilder: (context, a, _, child) => RaveMotion.reduced(context) ? child : SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

/// Pemutar layar penuh. Geser ke bawah untuk menutup.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    // Layar ambient berwarna sampul = "pulau gelap" di kedua tema (teks terang, bilah status terang).
    return DarkZone(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: Rave.overlayFor(Brightness.dark),
      child: ListenableBuilder(
      listenable: Listenable.merge([app.player, app.likes]),
      builder: (context, _) {
        final p = app.player;
        final c = p.current;
        if (c == null) return const Scaffold();
        final liked = app.likes.has(c.id);
        final imageUrl = app.api.media(c.imageUrl);
        return Scaffold(
          backgroundColor: Colors.transparent,
          // Tarik ke bawah mengikuti jari (menampakkan layar di bawahnya), lepas → tutup / pantul kembali.
          body: DragToDismiss(
            onDismiss: () => Navigator.pop(context),
            // Latar ambient mengikuti warna dominan sampul (web NowPlayingPanel + useCoverColor).
            child: CoverColorBuilder(
              url: imageUrl,
              builder: (context, tint) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [tint, Color.lerp(tint, Rave.canvas, 0.6)!, Rave.canvas],
                  stops: const [0, 0.45, 0.85],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  // Semua baris memakai gutter yang sama ([Rave.gutter]); tombol ikon di tepi diberi padding
                  // gutter − sisipan ikon → MUKA ikon yang terlihat sejajar tepi isi, area sentuh tetap 48 dp.
                  const g = Rave.gutter;
                  final cw = box.maxWidth - 2 * g;
                  final disc = app.settings.vinylMotion;
                  EdgeInsets edge({double l = 0, double r = 0}) => EdgeInsets.fromLTRB(g - l, 0, g - r, 0);
                  return Column(children: [
                      Padding(
                        padding: edge(l: _inset(32), r: _inset(24)),
                        child: Row(children: [
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
                          Expanded(child: Column(children: [Eyebrow(s.playingFrom, size: 9.5), const SizedBox(height: 2), Text('RAVE', style: Rave.body(weight: FontWeight.w700))])),
                          IconButton(
                            tooltip: s.queue,
                            onPressed: () => _sheet(context, const _QueueSheet()),
                            icon: const Icon(Icons.queue_music_rounded),
                          ),
                        ]),
                      ),
                      // Sampul (+ piringan) selebar isi; di layar pendek mengecil mengikuti tinggi (tak pernah overflow).
                      Expanded(
                        child: Padding(
                          padding: edge(),
                          child: LayoutBuilder(builder: (context, area) {
                            final ratio = VinylCover.ratio(disc);
                            final w = min(cw, (area.maxHeight - 24) / ratio).clamp(80.0, 560.0);
                            return Align(
                              alignment: w >= cw - 0.5 ? Alignment.centerLeft : Alignment.center,
                              child: VinylCover(
                                key: const Key('np-art'),
                                width: w,
                                image: c.imageUrl,
                                labelColor: tint,
                                disc: disc,
                                spinning: p.playing && !p.buffering && disc && !RaveMotion.reduced(context),
                                tape: p.ad != null ? null : p.session?.codecLabel,
                              ),
                            );
                          }),
                        ),
                      ),
                      Padding(
                        padding: edge(r: app.api.authed && c.kind == 'track' ? _inset(28) : 0),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.title.toUpperCase(), key: const Key('np-title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.poster(34)),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: c.artistKey == null
                                    ? null
                                    : () {
                                        Navigator.pop(context);
                                        _openInTab(context, 'artist', c.artistKey!);
                                      },
                                child: Text(c.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 16, color: Rave.muted)),
                              ),
                            ]),
                          ),
                          if (app.api.authed && c.kind == 'track')
                            IconButton(
                              tooltip: liked ? s.unlike : s.like,
                              iconSize: 28,
                              onPressed: () => toggleLike(context, c.id, image: c.imageUrl),
                              icon: LikeHeart(liked: liked, size: 28, color: Rave.paper),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      Padding(padding: edge(), child: const _Progress()),
                      if (p.error != null)
                        Padding(
                          padding: edge().copyWith(top: 2),
                          child: Text(p.error!, textAlign: TextAlign.center, style: Rave.body(size: 12.5, color: Rave.mustard)),
                        )
                      else if (p.session?.losslessPending ?? false)
                        Padding(
                          padding: edge().copyWith(top: 2),
                          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            const Icon(Icons.hourglass_top_rounded, size: 13, color: Rave.mustard),
                            const SizedBox(width: 6),
                            Flexible(child: Text(s.losslessPendingShort.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.label(size: 10, color: Rave.mustard))),
                          ]),
                        ),
                      const SizedBox(height: 14),
                      // Transport ala web (NowPlaying `.deck-tray`): lima tuts rapat dalam SATU baki selebar isi —
                      // tepi baki tepat di gutter, tuts berproporsi tetap (toggle 1 · lompat 1,25 · PLAY 1,6) dengan
                      // celah 4 dp, semua dipusatkan pada satu garis. Lebar tuts terkecil tetap ≥ 48 dp (target sentuh).
                      Padding(
                        padding: edge(),
                        child: Builder(builder: (context) {
                          const pad = 6.0, gap = 4.0, flex = [1.0, 1.25, 1.6, 1.25, 1.0];
                          final unit = (cw - 2 * (pad + 1) - 4 * gap) / flex.fold<double>(0, (a, b) => a + b);
                          final main = (unit * 1.12).clamp(Rave.tap, 60.0), small = main * 0.74;
                          final w = [for (final f in flex) unit * f];
                          return DeckTray(
                            key: const Key('np-tray'),
                            gap: gap,
                            padding: pad,
                            children: [
                              DeckKey(semantic: s.shuffle, toggle: true, active: p.shuffle, locked: p.ad != null, width: w[0], height: small, onTap: () => toggleShuffleWithToast(context), child: const Icon(Icons.shuffle_rounded)),
                              DeckKey(semantic: s.prev, locked: p.ad != null, width: w[1], height: main, onTap: p.prev, child: const Icon(Icons.skip_previous_rounded)),
                              DeckKey(
                                semantic: p.playing ? s.pause : s.play,
                                play: true,
                                width: w[2],
                                height: main,
                                onTap: p.error != null ? p.retry : p.toggle,
                                child: p.buffering && p.error == null
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Rave.ink))
                                    : Icon(p.error != null ? Icons.refresh_rounded : p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              ),
                              DeckKey(semantic: s.next, locked: p.ad != null, width: w[3], height: main, onTap: p.next, child: const Icon(Icons.skip_next_rounded)),
                              DeckKey(
                                key: const Key('np-last'),
                                semantic: s.repeat,
                                toggle: true,
                                active: p.repeat != LoopMode.off,
                                locked: p.ad != null,
                                width: w[4],
                                height: small,
                                onTap: () => cycleRepeatWithToast(context),
                                child: Icon(p.repeat == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded),
                              ),
                            ],
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                      Padding(
                        padding: edge(r: _inset(22)),
                        child: Row(children: [
                          Flexible(child: _Chip(icon: Icons.queue_music_rounded, label: s.queue, onTap: () => _sheet(context, const _QueueSheet()))),
                          const SizedBox(width: 10),
                          if (c.kind == 'track') Flexible(child: _Chip(icon: Icons.lyrics_outlined, label: s.lyrics, onTap: () => _sheet(context, const _LyricsSheet()))),
                          const Spacer(),
                          IconButton(tooltip: s.share, onPressed: () => _share(context, c), icon: const Icon(Icons.ios_share_rounded, size: 22)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                    ]);
                }),
              ),
            ),
            ),
          ),
        );
      },
    ),
      ),
    );
  }

  void _openInTab(BuildContext context, String kind, String id) => openInActiveTab(kind, id);

  /// Sisipan visual ikon berukuran [icon] di dalam IconButton 48 dp (jarak muka ikon ke tepi area sentuh).
  static double _inset(double icon) => (Rave.tap - icon) / 2;

  /// Bagikan: salin tautan web lagu ke papan klip (tanpa paket share tambahan).
  void _share(BuildContext context, Playable c) {
    final app = App.read(context);
    final url = '${app.settings.server}/app/${c.kind == 'track' ? (c.releaseId != null ? 'album/${c.releaseId}' : 'track/${c.id}') : 'episode/${c.id}'}';
    Clipboard.setData(ClipboardData(text: '${c.title} — ${c.subtitle}\n$url'));
    toast(context, app.s.linkCopied, kind: ToastKind.ok);
  }

  void _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Rave.base,
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: child),
      );
}

/// Info singkat saat akun Gratis mencoba menggeser posisi (slider / ketuk baris lirik).
void showSeekLocked(BuildContext context) => toast(context, App.of(context).s.seekPremium);

class _Progress extends StatefulWidget {
  const _Progress();
  @override
  State<_Progress> createState() => _ProgressState();
}

class _ProgressState extends State<_Progress> {
  double? drag;
  @override
  Widget build(BuildContext context) {
    final p = App.of(context).player;
    // adTick: hitungan iklan diperbarui tanpa notifyListeners pemutar (lihat RavePlayer.adTick).
    return ValueListenableBuilder<AdState?>(
      valueListenable: p.adTick,
      builder: (_, _, _) => StreamBuilder<Duration>(
      stream: p.position,
      builder: (_, snap) {
        final dur = p.duration.inMilliseconds.toDouble();
        final pos = drag ?? (snap.data?.inMilliseconds.toDouble() ?? 0);
        final ad = p.ad;
        final seekable = p.canSeek;
        final status = ad != null ? 'AD' : p.buffering && p.error == null ? 'BUFFER' : p.playing ? 'PLAY' : p.current != null ? 'PAUSE' : 'STOP';
        return Column(children: [
          DeckLcd(
            key: const Key('np-lcd'),
            status: status,
            codec: ad != null ? null : p.session?.codecLabel,
            time: fmtDuration(ad != null ? ad.elapsed.inMilliseconds : pos.round()),
            on: p.playing && !p.buffering,
            dim: p.current == null,
            // Spektrum mengikuti lagu: hanya lagu katalog (episode & iklan → animasi dekoratif).
            trackId: ad == null && p.current?.kind == 'track' ? p.current!.id : null,
            position: () => p.audio.position,
            spectrum: SpectrumRepo.forApi(App.of(context).api),
          ),
          const SizedBox(height: 10),
          DeckSlider(
            key: const Key('np-slider'),
            semantic: App.of(context).s.position,
            value: pos,
            max: dur,
            // Gratis tanpa izin geser: hanya tampilan progres; mencoba menggeser → info Premium.
            locked: ad != null || !seekable,
            onLocked: ad == null && !seekable ? () => showSeekLocked(context) : null,
            onDrag: (v) => setState(() => drag = v),
            onChanged: (v) => p.seek(Duration(milliseconds: v.round())),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmtDuration(pos.round()), style: Rave.label(size: 10, color: Rave.muted)),
            if (ad == null && !seekable)
              Tooltip(
                message: App.of(context).s.seekPremium,
                child: const Icon(Icons.lock_rounded, key: Key('np-seek-lock'), size: 12, color: Rave.muted),
              ),
            Text(fmtDuration(dur.round()), style: Rave.label(size: 10, color: Rave.muted)),
          ]),
        ]);
      },
    ),
    );
  }
}

/// Tombol pil sekunder (Antrean / Lirik) — sama dengan web.
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white.withValues(alpha: 0.10),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 18, color: Rave.paper),
              const SizedBox(width: 8),
              Flexible(child: Text(label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.label(size: 11, color: Rave.paper))),
            ]),
          ),
        ),
      );
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final p = app.player;
        final upcoming = p.queue.skip(p.index + 1).toList();
        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Eyebrow(s.nowPlaying)),
          if (p.current != null)
            ListTile(
              leading: Cover(p.current!.imageUrl, size: 44),
              title: Text(p.current!.title, style: Rave.body(weight: FontWeight.w700, color: Rave.mustard)),
              subtitle: Text(p.current!.subtitle, style: Rave.body(size: 13, color: Rave.muted)),
            ),
          Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 8), child: Eyebrow(s.nextUp)),
          if (upcoming.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(s.noQueue, style: Rave.body(color: Rave.muted))),
          for (var i = 0; i < upcoming.length; i++)
            ListTile(
              onTap: () => p.jump(p.index + 1 + i),
              leading: Cover(upcoming[i].imageUrl, size: 44),
              title: Text(upcoming[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w600)),
              subtitle: Text(upcoming[i].subtitle, style: Rave.body(size: 13, color: Rave.muted)),
            ),
        ]);
      },
    );
  }
}

class _LyricsSheet extends StatelessWidget {
  const _LyricsSheet();
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final c = app.player.current;
    if (c == null) return const SizedBox.shrink();
    return ApiView<Lyrics>(
      path: '/v1/catalog/tracks/${c.id}/lyrics',
      parse: Lyrics.fromJson,
      builder: (_, l, _) => _LyricsBody(lyrics: l),
    );
  }
}

class _LyricsBody extends StatefulWidget {
  const _LyricsBody({required this.lyrics});
  final Lyrics lyrics;
  @override
  State<_LyricsBody> createState() => _LyricsBodyState();
}

class _LyricsBodyState extends State<_LyricsBody> {
  final _keys = <int, GlobalKey>{};
  int _active = -1;

  @override
  Widget build(BuildContext context) {
    final p = App.of(context).player;
    final lines = widget.lyrics.lines;
    if (lines.isEmpty) return EmptyState(App.of(context).s.noLyrics);
    return StreamBuilder<Duration>(
      stream: p.position,
      builder: (_, snap) {
        final pos = snap.data?.inMilliseconds ?? 0;
        var active = -1;
        if (widget.lyrics.synced) {
          for (var i = 0; i < lines.length; i++) {
            if (lines[i].timeMs <= pos + 150) active = i;
          }
        }
        if (active != _active) {
          _active = active;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _keys[active]?.currentContext;
            if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.4, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          });
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
          itemCount: lines.length,
          itemBuilder: (_, i) {
            final l = lines[i];
            final color = !widget.lyrics.synced
                ? Rave.paper
                : i == active
                    ? Rave.mustard
                    : i < active
                        ? Rave.paper.withValues(alpha: 0.45)
                        : Rave.paper.withValues(alpha: 0.8);
            return GestureDetector(
              key: _keys.putIfAbsent(i, GlobalKey.new),
              onTap: !widget.lyrics.synced ? null : p.canSeek ? () => p.seek(Duration(milliseconds: l.timeMs)) : () => showSeekLocked(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(l.text, style: Rave.body(size: 22, weight: FontWeight.w800, color: color, height: 1.25)),
              ),
            );
          },
        );
      },
    );
  }
}
