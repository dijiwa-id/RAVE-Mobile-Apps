import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/collection.dart';
import '../widgets/common.dart';
import '../widgets/media.dart';

/// Playlist dan "Lagu yang Disukai" (sumber berbeda, tampilan sama).
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final liked = id == 'liked';
    return ApiView<({String title, String? cover, String owner, String? description, List<Track> tracks})>(
      path: liked ? '/v1/library/likes' : '/v1/library/playlists/$id',
      parse: (j) {
        if (liked) return (title: '', cover: null, owner: '', description: null, tracks: (j['data'] as List).map((x) => Track.fromJson(x as Json)).toList());
        final p = PlaylistSummary.fromJson(j);
        return (
          title: p.title,
          cover: p.coverUrl,
          owner: p.ownerName ?? 'RAVE',
          description: p.description,
          tracks: (j['items'] as List).map((x) => Track.fromJson(x['track'] as Json)).toList(),
        );
      },
      loading: const Scaffold(body: Center(child: CircularProgressIndicator(color: Rave.mustard))),
      builder: (context, d, _) {
        final app = App.of(context);
        final s = app.s;
        return ListenableBuilder(
          listenable: app.player,
          builder: (context, _) {
            final p = app.player;
            final inThis = d.tracks.any((t) => t.id == p.current?.id);
            final total = d.tracks.fold<int>(0, (a, t) => a + t.durationMs);
            return CollectionPage(
              kind: 'Playlist',
              title: liked ? s.liked : d.title,
              cover: d.cover,
              tint: liked ? Rave.purple : Rave.teal,
              art: liked
                  ? Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.plum, Rave.berry])),
                      child: const Icon(Icons.favorite, size: 84, color: Rave.mustard),
                    )
                  : null,
              meta: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (d.description != null && d.description!.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(d.description!, style: Rave.body(size: 13, color: Rave.muted))),
                Text('${liked ? (app.api.user?.displayName ?? '') : d.owner} · ${s.songs(d.tracks.length)}${d.tracks.isEmpty ? '' : ', ${fmtTotal(total, app.settings.locale == 'id')}'}'),
              ]),
              actions: [
                const Spacer(),
                IconButton(onPressed: p.toggleShuffle, icon: Icon(Icons.shuffle_rounded, color: p.shuffle ? Rave.mustard : Rave.paper)),
                const SizedBox(width: 8),
                if (d.tracks.isNotEmpty)
                  PlayButton(
                    playing: inThis && p.playing,
                    semantic: s.play,
                    onTap: () => inThis ? p.toggle() : p.playQueue(d.tracks.map(Playable.fromTrack).toList()),
                  ),
              ],
              slivers: [
                if (d.tracks.isEmpty) SliverToBoxAdapter(child: EmptyState(s.empty)) else TrackSliver(tracks: d.tracks),
              ],
            );
          },
        );
      },
    );
  }
}
