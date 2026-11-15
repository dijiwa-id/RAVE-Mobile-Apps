import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/collection.dart';
import '../widgets/common.dart';
import '../widgets/embed_player.dart';
import '../widgets/motion.dart';

class ShowScreen extends StatelessWidget {
  const ShowScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ApiView<Show>(
      path: '/v1/catalog/shows/$id',
      parse: Show.fromJson,
      loading: const Scaffold(body: SafeArea(child: ListSkeleton())),
      builder: (context, sh, _) => ListenableBuilder(
        listenable: app.player,
        builder: (context, _) {
          final p = app.player;
          // Episode embed diputar di WebView platform asal — tidak masuk antrean pemutar RAVE.
          final eps = sh.episodes.where((e) => !e.isEmbed).map((e) => Playable.fromEpisode(e, sh.title, contentWarning: sh.contentWarning)).toList();
          final key = 'show:${sh.id}';
          void playEp(String id) {
            final i = eps.indexWhere((x) => x.id == id);
            if (i < 0) return;
            p.current?.id == id ? p.toggle() : p.playQueue(eps, i, key);
          }
          void playAt(int i) => playEp(eps[i].id);
          return CollectionPage(
            kind: s.kind('show'),
            title: sh.title,
            cover: sh.coverUrl,
            tint: Rave.berry,
            meta: Text('${sh.publisher} · ${sh.category} · ${sh.episodes.length} ${s.episodes}'),
            actions: [
              const Spacer(),
              if (eps.isNotEmpty) PlayFab(size: 56, playKey: key, semantic: s.play, onPlay: () => playAt(0)),
            ],
            slivers: [
              if (sh.description != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(sh.description!, style: Rave.body(size: 14, color: context.rc.text.withValues(alpha: 0.85), height: 1.45)),
                  ),
                ),
              SliverList.separated(
                itemCount: sh.episodes.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final e = sh.episodes[i];
                  final cur = p.current?.id == e.id;
                  return InkWell(
                    onTap: e.isEmbed ? null : () => playEp(e.id),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(e.title, style: Rave.body(size: 15, weight: FontWeight.w700, color: cur ? context.rc.accent : context.rc.text))),
                              if (e.premium) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.lock_rounded, size: 14, color: context.rc.accent)),
                            ]),
                            if (e.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(e.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: context.rc.muted)),
                              ),
                            if (e.embed != null) Padding(padding: const EdgeInsets.only(top: 10), child: EmbedPlayer(embed: e.embed!, title: e.title)),
                            const SizedBox(height: 6),
                            Eyebrow(
                                '${e.publishedAt.length >= 10 ? e.publishedAt.substring(0, 10) : ''}${e.durationMs > 0 ? ' · ${fmtTotal(e.durationMs, app.settings.locale == 'id')}' : ''}',
                                color: context.rc.subtle,
                                size: 9.5),
                          ]),
                        ),
                        if (!e.isEmbed) ...[
                          const SizedBox(width: 10),
                          PlayFab(size: 40, playKey: 'episode:${e.id}', semantic: '${s.play} ${e.title}', onPlay: () => playEp(e.id)),
                        ],
                      ]),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
