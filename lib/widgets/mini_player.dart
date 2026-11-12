import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../screens/now_playing.dart';
import 'common.dart';

/// Mini-player di atas tab bar: sampul, judul, suka, putar/jeda, progres tipis. Ketuk → pemutar layar penuh,
/// geser ke atas juga membuka. Selama jeda iklan menampilkan kartu iklan.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: Listenable.merge([app.player, app.likes]),
      builder: (context, _) {
        final p = app.player;
        final ad = p.ad;
        if (ad != null) return _AdMini(state: ad);
        final c = p.current;
        if (c == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => openNowPlaying(context),
          onVerticalDragEnd: (d) => (d.primaryVelocity ?? 0) < -200 ? openNowPlaying(context) : null,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
            decoration: BoxDecoration(color: Rave.raised, border: Border.all(color: Rave.line), boxShadow: Rave.hardShadow),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                padding: const EdgeInsets.all(6),
                child: Row(children: [
                  Hero(tag: 'cover', child: Cover(c.imageUrl, size: 44)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700)),
                      Text(p.error ?? c.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, color: p.error != null ? Rave.mustard : Rave.muted)),
                    ]),
                  ),
                  if (app.api.authed && c.kind == 'track')
                    IconButton(
                      tooltip: app.likes.has(c.id) ? s.unlike : s.like,
                      onPressed: () => app.likes.toggle(c.id, app.cache).catchError((_) {}),
                      icon: Icon(app.likes.has(c.id) ? Icons.favorite : Icons.favorite_border, color: app.likes.has(c.id) ? Rave.mustard : Rave.paper),
                    ),
                  SizedBox(
                    width: 44,
                    child: p.buffering && p.error == null
                        ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Rave.paper)))
                        : IconButton(
                            tooltip: p.playing ? s.pause : s.play,
                            onPressed: p.error != null ? p.retry : p.toggle,
                            icon: Icon(p.error != null ? Icons.refresh_rounded : p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30),
                          ),
                  ),
                ]),
              ),
              StreamBuilder<Duration>(
                stream: p.position,
                builder: (_, snap) {
                  final d = p.duration.inMilliseconds;
                  final v = d == 0 ? 0.0 : ((snap.data?.inMilliseconds ?? 0) / d).clamp(0.0, 1.0);
                  return LinearProgressIndicator(value: v, minHeight: 2, color: Rave.paper, backgroundColor: Rave.line);
                },
              ),
            ]),
          ),
        );
      },
    );
  }
}

class _AdMini extends StatelessWidget {
  const _AdMini({required this.state});
  final AdState state;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final a = state.ad;
    final left = (a.durationS - state.elapsed.inSeconds).clamp(0, 999);
    final skipIn = state.skipIn;
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Rave.plum, border: Border.all(color: Rave.mustard, width: 1.5)),
      child: Row(children: [
        Cover(a.imageUrl, size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow('${s.ad} · ${a.advertiser} · ${left}s', color: Rave.mustard, size: 9.5),
            Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700)),
          ]),
        ),
        if (skipIn >= 0)
          OutlineButton(label: skipIn > 0 ? s.skipIn(skipIn) : s.skip, onTap: skipIn > 0 ? null : app.player.skipAd),
      ]),
    );
  }
}
