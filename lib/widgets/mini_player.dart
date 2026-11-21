import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../screens/now_playing.dart';
import 'common.dart';
import 'deck.dart';
import 'links.dart';
import 'media.dart';
import 'motion.dart';
import 'share_sheet.dart';

/// Mini-player di atas tab bar: sampul, judul, suka, putar/jeda, progres tipis. Ketuk → pemutar layar penuh,
/// geser ke atas juga membuka. Selama jeda iklan menampilkan kartu iklan.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  /// Jarak kotak mini-player ke tepi layar, tebal bingkai, dan padding dalam — jumlahnya = [Rave.gutter].
  static const margin = 8.0, border = 1.0, inset = Rave.gutter - margin - border;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    // Mini-player & tombol deck tetap gelap di tema terang ("pulau gelap", sama dengan web).
    return DarkZone(
      child: ListenableBuilder(
      listenable: Listenable.merge([app.player, app.likes]),
      builder: (context, _) {
        final p = app.player;
        final ad = p.ad;
        if (ad != null) {
          return ValueListenableBuilder<AdState?>(valueListenable: p.adTick, builder: (_, st, _) => st == null ? const SizedBox.shrink() : _AdMini(state: st));
        }
        final c = p.current;
        if (c == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => openNowPlaying(context),
          // Tahan lama → lembar bagikan lagu (bilah mini terlalu sempit untuk tombol ke-3; sama dengan baris lagu).
          onLongPress: c.kind == 'track' && shareEnabled(app) ? () => showShareSheet(context, trackId: c.id, title: c.title, artist: c.subtitle, cover: c.imageUrl) : null,
          onVerticalDragEnd: (d) => (d.primaryVelocity ?? 0) < -200 ? openNowPlaying(context) : null,
          child: Container(
            margin: const EdgeInsets.fromLTRB(MiniPlayer.margin, 0, MiniPlayer.margin, 4),
            decoration: BoxDecoration(color: Rave.raised, border: Border.all(color: Rave.line, width: MiniPlayer.border), boxShadow: Rave.hardShadow),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(
                // margin + bingkai + padding = gutter → sampul & tombol terakhir sejajar tepi isi halaman.
                padding: const EdgeInsets.symmetric(horizontal: MiniPlayer.inset, vertical: 2),
                child: Row(children: [
                  Hero(tag: 'cover', child: Cover(c.imageUrl, key: const Key('mini-cover'), size: 44)),
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
                      onPressed: () => toggleLike(context, c.id, image: c.imageUrl),
                      icon: LikeHeart(liked: app.likes.has(c.id), color: Rave.paper),
                    ),
                  const SizedBox(width: 4),
                  DeckKey(
                    key: const Key('mini-last'),
                    semantic: p.playing ? s.pause : s.play,
                    play: true,
                    width: 48,
                    height: 40,
                    onTap: p.error != null ? p.retry : p.toggle,
                    child: p.buffering && p.error == null
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Rave.ink))
                        : Icon(p.error != null ? Icons.refresh_rounded : p.playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  ),
                ]),
              ),
              StreamBuilder<Duration>(
                stream: p.position,
                builder: (_, snap) {
                  final d = p.duration.inMilliseconds;
                  final v = d == 0 ? 0.0 : ((snap.data?.inMilliseconds ?? 0) / d).clamp(0.0, 1.0);
                  return LinearProgressIndicator(value: v, minHeight: 3, color: Rave.mustard, backgroundColor: const Color(0xFF0A090C));
                },
              ),
            ]),
          ),
        );
      },
    ),
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
      margin: const EdgeInsets.fromLTRB(MiniPlayer.margin, 0, MiniPlayer.margin, 4),
      padding: const EdgeInsets.symmetric(horizontal: Rave.gutter - MiniPlayer.margin - 1.5, vertical: 8),
      decoration: BoxDecoration(color: Rave.plum, border: Border.all(color: Rave.mustard, width: 1.5)),
      child: Row(children: [
        Cover(a.imageUrl, size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Eyebrow('${a.isHouse ? s.houseAd : s.ad} · ${a.advertiser} · ${left}s', color: Rave.mustard, size: 9.5),
            Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700)),
          ]),
        ),
        if (a.clickUrl != null)
          IconButton(
            tooltip: a.ctaLabel ?? s.open,
            onPressed: () {
              app.player.adClicked();
              openUrl(a.clickUrl!);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
          ),
        if (skipIn >= 0)
          OutlineButton(label: skipIn > 0 ? s.skipIn(skipIn) : s.skip, onTap: skipIn > 0 ? null : app.player.skipAd),
      ]),
    );
  }
}
