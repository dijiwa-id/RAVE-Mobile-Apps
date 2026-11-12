import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/collection.dart';
import '../widgets/common.dart';
import '../widgets/media.dart';
import 'routes.dart';

class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ApiView<Release>(
      path: '/v1/catalog/releases/$id',
      parse: Release.fromJson,
      loading: const Scaffold(body: Center(child: CircularProgressIndicator(color: Rave.mustard))),
      builder: (context, r, _) => ListenableBuilder(
        listenable: app.player,
        builder: (context, _) {
          final p = app.player;
          final inThis = r.tracks.any((t) => t.id == p.current?.id);
          final total = r.tracks.fold<int>(0, (a, t) => a + t.durationMs);
          return CollectionPage(
            kind: s.kind(r.type),
            title: r.title,
            cover: r.coverUrl,
            meta: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
              GestureDetector(onTap: () => openItem(context, 'artist', r.artist.slug), child: Text(r.artist.name, style: Rave.body(size: 13, weight: FontWeight.w700))),
              const Text('·'),
              Text(r.year),
              const Text('·'),
              Text('${s.songs(r.tracks.length)}, ${fmtTotal(total, app.settings.locale == 'id')}'),
            ]),
            actions: [
              if (app.api.authed) _SaveButton(releaseId: r.id),
              const Spacer(),
              IconButton(
                tooltip: s.shuffle,
                onPressed: p.toggleShuffle,
                icon: Icon(Icons.shuffle_rounded, color: p.shuffle ? Rave.mustard : Rave.paper),
              ),
              const SizedBox(width: 8),
              PlayButton(
                playing: inThis && p.playing,
                semantic: s.play,
                onTap: () => inThis ? p.toggle() : p.playQueue(r.tracks.map(Playable.fromTrack).toList()),
              ),
            ],
            slivers: [
              TrackSliver(tracks: r.tracks, numbered: true, showCover: false),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Eyebrow('${r.releaseDate}${r.label != null ? ' · ℗ ${r.label}' : ''}', color: Rave.subtle),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SaveButton extends StatefulWidget {
  const _SaveButton({required this.releaseId});
  final String releaseId;
  @override
  State<_SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<_SaveButton> {
  bool? saved;
  @override
  void initState() {
    super.initState();
    final app = App.read(context);
    app.cache.load('/v1/library/summary', () async => LibrarySummary.fromJson(await app.api.get('/v1/library/summary'))).then((v) {
      if (mounted) setState(() => saved = (v as LibrarySummary).savedReleases.contains(widget.releaseId));
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    if (saved == null) return const SizedBox(width: 48);
    return IconButton(
      tooltip: saved! ? app.s.saved : app.s.save,
      onPressed: () async {
        final was = saved!;
        setState(() => saved = !was);
        try {
          await app.api.request<dynamic>('/v1/library/releases/${widget.releaseId}', method: was ? 'DELETE' : 'PUT');
          app.cache.invalidate('/v1/library');
        } catch (e) {
          if (!context.mounted) return;
          setState(() => saved = was);
          toast(context, e.toString());
        }
      },
      icon: Icon(saved! ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: 30, color: saved! ? Rave.mustard : Rave.paper),
    );
  }
}
