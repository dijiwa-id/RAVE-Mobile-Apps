import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/collection.dart';
import '../widgets/common.dart';

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
      loading: const Scaffold(body: Center(child: CircularProgressIndicator(color: Rave.mustard))),
      builder: (context, sh, _) => ListenableBuilder(
        listenable: app.player,
        builder: (context, _) {
          final p = app.player;
          final eps = sh.episodes.map((e) => Playable.fromEpisode(e, sh.title, contentWarning: sh.contentWarning)).toList();
          void playAt(int i) => p.current?.id == eps[i].id ? p.toggle() : p.playQueue(eps, i);
          return CollectionPage(
            kind: s.kind('show'),
            title: sh.title,
            cover: sh.coverUrl,
            tint: Rave.berry,
            meta: Text('${sh.publisher} · ${sh.category} · ${sh.episodes.length} ${s.episodes}'),
            actions: [
              const Spacer(),
              if (eps.isNotEmpty) PlayButton(playing: eps.any((e) => e.id == p.current?.id) && p.playing, semantic: s.play, onTap: () => playAt(0)),
            ],
            slivers: [
              if (sh.description != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(sh.description!, style: Rave.body(size: 14, color: Rave.paper.withValues(alpha: 0.85), height: 1.45)),
                  ),
                ),
              SliverList.separated(
                itemCount: sh.episodes.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final e = sh.episodes[i];
                  final cur = p.current?.id == e.id;
                  return InkWell(
                    onTap: () => playAt(i),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Flexible(child: Text(e.title, style: Rave.body(size: 15, weight: FontWeight.w700, color: cur ? Rave.mustard : Rave.paper))),
                              if (e.premium) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.lock_rounded, size: 14, color: Rave.mustard)),
                            ]),
                            if (e.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(e.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: Rave.muted)),
                              ),
                            const SizedBox(height: 6),
                            Eyebrow('${e.publishedAt.length >= 10 ? e.publishedAt.substring(0, 10) : ''} · ${fmtTotal(e.durationMs, app.settings.locale == 'id')}', color: Rave.subtle, size: 9.5),
                          ]),
                        ),
                        const SizedBox(width: 10),
                        PlayButton(size: 40, playing: cur && p.playing, semantic: s.play, onTap: () => playAt(i)),
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
