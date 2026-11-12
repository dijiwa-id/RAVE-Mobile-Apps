import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../screens/routes.dart';
import 'common.dart';
import 'playlist_actions.dart';

/// Kartu media horizontal (album, artis, playlist, podcast) untuk rak beranda.
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.item, this.width = 148});
  final MediaItem item;
  final double width;

  @override
  Widget build(BuildContext context) {
    final round = item.kind == 'artist';
    return SizedBox(
      width: width,
      child: InkWell(
        onTap: () => openItem(context, item.kind, item.targetId),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(crossAxisAlignment: round ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
            Cover(item.imageUrl, size: width - 12, round: round),
            const SizedBox(height: 8),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: round ? TextAlign.center : TextAlign.start, style: Rave.body(size: 12.5, color: Rave.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Rak horizontal bergulir.
class Shelf extends StatelessWidget {
  const Shelf({super.key, required this.title, required this.children, this.height = 214});
  final String title;
  final List<Widget> children;
  final double height;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title),
        SizedBox(
          height: height,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: children),
        ),
      ]);
}

/// Baris lagu: ketuk untuk memutar dari daftar, indikator yang sedang diputar, menu aksi.
class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.tracks, required this.index, this.showCover = true, this.number});
  final List<Track> tracks;
  final int index;
  final bool showCover;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = tracks[index];
    return ListenableBuilder(
      listenable: Listenable.merge([app.player, app.likes]),
      builder: (context, _) {
        final p = app.player;
        final isCur = p.current?.id == t.id;
        final liked = app.likes.has(t.id);
        return InkWell(
          onTap: () => isCur ? p.toggle() : p.playQueue(tracks.map(Playable.fromTrack).toList(), index),
          onLongPress: () => showTrackMenu(context, t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(children: [
              if (number != null)
                SizedBox(
                  width: 28,
                  child: isCur ? Equalizer(playing: p.playing) : Text('$number', style: Rave.body(color: Rave.muted)),
                ),
              if (showCover) ...[Cover(t.coverUrl, size: 48), const SizedBox(width: 12)],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 15, weight: FontWeight.w600, color: isCur ? Rave.mustard : Rave.paper)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (t.explicit) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        color: Rave.muted,
                        child: Text('E', style: Rave.label(size: 8.5, color: Rave.ink)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (liked) ...[const Icon(Icons.favorite, size: 13, color: Rave.mustard), const SizedBox(width: 5)],
                    Flexible(child: Text(t.artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: Rave.muted))),
                  ]),
                ]),
              ),
              IconButton(
                tooltip: app.s.like,
                onPressed: () => showTrackMenu(context, t),
                icon: const Icon(Icons.more_vert_rounded, color: Rave.muted),
              ),
            ]),
          ),
        );
      },
    );
  }
}

/// Lembar aksi lagu: suka, tambah antrean, ke artis, ke album.
void showTrackMenu(BuildContext context, Track t) {
  final app = App.read(context);
  final s = app.s;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final liked = app.likes.has(t.id);
      Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
            leading: Icon(icon, color: Rave.paper),
            title: Text(label, style: Rave.body(size: 15, weight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(sheet);
              onTap();
            },
          );
      return SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Cover(t.coverUrl, size: 48),
            title: Text(t.title, style: Rave.body(size: 16, weight: FontWeight.w700)),
            subtitle: Text(t.artist.name, style: Rave.body(color: Rave.muted)),
          ),
          const Divider(height: 1),
          if (app.api.authed)
            item(liked ? Icons.favorite : Icons.favorite_border, liked ? s.unlike : s.like, () async {
              try {
                await app.likes.toggle(t.id, app.cache);
              } catch (e) {
                if (context.mounted) toast(context, e.toString());
              }
            }),
          item(Icons.playlist_add_rounded, s.addToPlaylist, () => addToPlaylist(context, t)),
          item(Icons.queue_music_rounded, s.addQueue, () {
            app.player.addToQueue(Playable.fromTrack(t));
            toast(context, s.addedQueue(t.title));
          }),
          item(Icons.person_rounded, s.goArtist, () => openItem(context, 'artist', t.artist.slug)),
          if (t.releaseId.isNotEmpty) item(Icons.album_rounded, s.goAlbum, () => openItem(context, 'release', t.releaseId)),
          const SizedBox(height: 8),
        ]),
      );
    },
  );
}

/// Daftar lagu sebagai sliver (dipakai album/playlist/artis).
class TrackSliver extends StatelessWidget {
  const TrackSliver({super.key, required this.tracks, this.numbered = false, this.showCover = true});
  final List<Track> tracks;
  final bool numbered, showCover;
  @override
  Widget build(BuildContext context) {
    App.read(context).likes.check(tracks.map((t) => t.id));
    return SliverList.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) => TrackTile(tracks: tracks, index: i, showCover: showCover, number: numbered ? (tracks[i].trackNumber > 0 ? tracks[i].trackNumber : i + 1) : null),
    );
  }
}
