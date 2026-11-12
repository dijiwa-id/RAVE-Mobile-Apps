import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

void openNowPlaying(BuildContext context) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => const NowPlayingScreen(),
      transitionsBuilder: (_, a, _, child) => SlideTransition(
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
    return ListenableBuilder(
      listenable: Listenable.merge([app.player, app.likes]),
      builder: (context, _) {
        final p = app.player;
        final c = p.current;
        if (c == null) return const Scaffold();
        final liked = app.likes.has(c.id);
        return Scaffold(
          body: GestureDetector(
            onVerticalDragEnd: (d) => (d.primaryVelocity ?? 0) > 300 ? Navigator.pop(context) : null,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Rave.purple, Rave.plum, Rave.canvas], stops: [0, 0.45, 0.85]),
              ),
              child: SafeArea(
                child: LayoutBuilder(builder: (context, box) {
                  final art = (box.maxWidth - 48).clamp(160.0, box.maxHeight * 0.46);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(children: [
                      Row(children: [
                        IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 32)),
                        Expanded(child: Column(children: [Eyebrow(s.playingFrom, size: 9.5), const SizedBox(height: 2), Text('RAVE', style: Rave.body(weight: FontWeight.w700))])),
                        IconButton(
                          tooltip: s.queue,
                          onPressed: () => _sheet(context, const _QueueSheet()),
                          icon: const Icon(Icons.queue_music_rounded),
                        ),
                      ]),
                      const Spacer(),
                      Hero(
                        tag: 'cover',
                        child: DecoratedBox(
                          decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Color(0x99000000), blurRadius: 36, offset: Offset(0, 16))]),
                          child: Cover(c.imageUrl, size: art),
                        ),
                      ),
                      const Spacer(),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c.title.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.poster(34)),
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
                            onPressed: () => app.likes.toggle(c.id, app.cache).catchError((_) {}),
                            icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Rave.mustard : Rave.paper),
                          ),
                      ]),
                      const SizedBox(height: 14),
                      const _Progress(),
                      if (p.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(p.error!, textAlign: TextAlign.center, style: Rave.body(size: 12.5, color: Rave.mustard)),
                        ),
                      const SizedBox(height: 6),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        IconButton(
                          tooltip: s.shuffle,
                          onPressed: p.toggleShuffle,
                          icon: Icon(Icons.shuffle_rounded, color: p.shuffle ? Rave.mustard : Rave.paper),
                        ),
                        IconButton(iconSize: 40, onPressed: p.prev, icon: const Icon(Icons.skip_previous_rounded)),
                        PlayButton(
                          size: 72,
                          playing: p.playing,
                          semantic: p.playing ? s.pause : s.play,
                          onTap: p.error != null ? p.retry : p.toggle,
                        ),
                        IconButton(iconSize: 40, onPressed: p.next, icon: const Icon(Icons.skip_next_rounded)),
                        IconButton(
                          onPressed: p.cycleRepeat,
                          icon: Icon(p.repeat == LoopMode.one ? Icons.repeat_one_rounded : Icons.repeat_rounded, color: p.repeat == LoopMode.off ? Rave.paper : Rave.mustard),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        if (p.session != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(border: Border.all(color: Rave.line)),
                            child: Text(p.session!.codecLabel, style: Rave.label(size: 9, color: Rave.muted)),
                          ),
                        const Spacer(),
                        if (c.kind == 'track')
                          TextButton.icon(
                            onPressed: () => _sheet(context, const _LyricsSheet()),
                            icon: const Icon(Icons.lyrics_outlined, color: Rave.paper, size: 18),
                            label: Text(s.lyrics.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)),
                          ),
                      ]),
                      const SizedBox(height: 8),
                    ]),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openInTab(BuildContext context, String kind, String id) => openInActiveTab(kind, id);

  void _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Rave.base,
        builder: (_) => FractionallySizedBox(heightFactor: 0.85, child: child),
      );
}

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
    return StreamBuilder<Duration>(
      stream: p.position,
      builder: (_, snap) {
        final dur = p.duration.inMilliseconds.toDouble();
        final pos = drag ?? (snap.data?.inMilliseconds.toDouble() ?? 0).clamp(0, dur == 0 ? 1 : dur).toDouble();
        return Column(children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 3, overlayShape: SliderComponentShape.noOverlay),
            child: Slider(
              min: 0,
              max: dur == 0 ? 1 : dur,
              value: pos.clamp(0, dur == 0 ? 1 : dur),
              onChanged: (v) => setState(() => drag = v),
              onChangeEnd: (v) {
                p.seek(Duration(milliseconds: v.round()));
                setState(() => drag = null);
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(fmtDuration(pos.round()), style: Rave.label(size: 10, color: Rave.muted)),
            Text(fmtDuration(dur.round()), style: Rave.label(size: 10, color: Rave.muted)),
          ]),
        ]);
      },
    );
  }
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
              onTap: widget.lyrics.synced ? () => p.seek(Duration(milliseconds: l.timeMs)) : null,
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
