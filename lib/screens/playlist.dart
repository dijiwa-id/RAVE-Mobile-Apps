import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/collection.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/feedback.dart';
import '../widgets/media.dart';
import 'shell.dart';

/// Playlist dan "Lagu yang Disukai" (sumber berbeda, tampilan sama).
class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final liked = id == 'liked';
    return ApiView<({String title, String? cover, String owner, String? ownerId, String? description, List<Track> tracks})>(
      path: liked ? '/v1/library/likes' : '/v1/library/playlists/$id',
      parse: (j) {
        if (liked) return (title: '', cover: null, owner: '', ownerId: null, description: null, tracks: (j['data'] as List).map((x) => Track.fromJson(x as Json)).toList());
        final p = PlaylistSummary.fromJson(j);
        return (
          title: p.title,
          cover: p.coverUrl,
          owner: p.ownerName ?? 'RAVE',
          ownerId: p.ownerId,
          description: p.description,
          tracks: (j['items'] as List).map((x) => Track.fromJson(x['track'] as Json)).toList(),
        );
      },
      loading: const Scaffold(body: SafeArea(child: ListSkeleton())),
      builder: (context, d, _) {
        final app = App.of(context);
        final s = app.s;
        return ListenableBuilder(
          listenable: app.player,
          builder: (context, _) {
            final p = app.player;
            final key = liked ? 'liked' : 'playlist:$id';
            final mine = !liked && d.ownerId != null && d.ownerId == app.api.user?.id;
            final total = d.tracks.fold<int>(0, (a, t) => a + t.durationMs);
            return CollectionPage(
              kind: 'Playlist',
              title: liked ? s.liked : d.title,
              cover: d.cover,
              placeholderIcon: Icons.queue_music_rounded,
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
                if (d.description != null && d.description!.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(d.description!, style: Rave.body(size: 13, color: context.rc.muted))),
                Text('${liked ? (app.api.user?.displayName ?? '') : d.owner} · ${s.songs(d.tracks.length)}${d.tracks.isEmpty ? '' : ', ${fmtTotal(total, app.settings.locale == 'id')}'}'),
              ]),
              actions: [
                if (mine)
                  IconButton(
                    tooltip: s.deletePlaylist,
                    onPressed: () => _deletePlaylist(context, d.title, d.cover, d.tracks.length),
                    icon: Icon(Icons.delete_outline_rounded, color: context.rc.text),
                  ),
                const Spacer(),
                IconButton(tooltip: s.shuffle, onPressed: () => toggleShuffleWithToast(context), icon: Icon(Icons.shuffle_rounded, color: p.shuffle ? context.rc.accent : context.rc.text)),
                const SizedBox(width: 8),
                if (d.tracks.isNotEmpty)
                  PlayFab(
                    size: 56,
                    playKey: key,
                    semantic: s.play,
                    onPlay: () => playCollectionNow(context, d.tracks.map(Playable.fromTrack).toList(), key, title: liked ? s.liked : d.title, image: d.cover),
                  ),
              ],
              slivers: [
                if (d.tracks.isEmpty) SliverToBoxAdapter(child: EmptyState(s.emptyPlaylist, body: s.emptyPlaylistBody, action: s.findMusic, onAction: () => selectShellTab(1))) else TrackSliver(tracks: d.tracks, contextKey: key),
              ],
            );
          },
        );
      },
    );
  }

  /// Hapus playlist milik sendiri: konfirmasi RAVE (berbahaya, fokus awal Batal) → DELETE → kembali + stiker.
  Future<void> _deletePlaylist(BuildContext context, String title, String? cover, int count) async {
    final app = App.read(context);
    final s = app.s;
    final ok = await confirmDialog(context, title: s.deletePlaylistTitle, body: s.deletePlaylistBody(title, count), confirmLabel: s.deletePlaylist, danger: true, image: cover, showImage: true);
    if (!ok || !context.mounted) return;
    try {
      await app.api.delete('/v1/library/playlists/$id');
      app.cache.invalidate('/v1/library');
      if (!context.mounted) return;
      showToast(context, s.playlistDeleted(title), kind: ToastKind.ok, image: cover);
      Navigator.of(context).maybePop();
    } catch (e) {
      if (context.mounted) toastError(context, e);
    }
  }
}
