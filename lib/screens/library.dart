import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'login.dart';
import '../widgets/playlist_actions.dart';
import 'routes.dart';

/// Pustaka: chip filter (Playlist/Artis/Album) + daftar ala aplikasi musik.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String tab = 'playlists';

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
            child: Row(children: [
              Cover(app.api.user?.avatarUrl, size: 34, round: true),
              const SizedBox(width: 12),
              Expanded(child: Text(s.yourLibrary.toUpperCase(), style: Rave.poster(34))),
              IconButton(tooltip: s.createPlaylist, onPressed: () => showCreateSheet(context), icon: const Icon(Icons.add_rounded, size: 28)),
              IconButton(tooltip: s.settings, onPressed: () => openItem(context, 'settings', ''), icon: const Icon(Icons.settings_outlined)),
            ]),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              for (final (k, label) in [('playlists', s.playlists), ('artists', s.artists), ('albums', s.albums)])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label.toUpperCase(), style: Rave.label(size: 10.5, color: tab == k ? Rave.ink : Rave.paper)),
                    selected: tab == k,
                    showCheckmark: false,
                    selectedColor: Rave.paper,
                    backgroundColor: Rave.raised,
                    shape: const RoundedRectangleBorder(),
                    side: BorderSide.none,
                    onSelected: (_) => setState(() => tab = k),
                  ),
                ),
            ]),
          ),
          if (!app.api.authed)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.library_music_rounded, size: 56, color: Rave.mustard),
                    const SizedBox(height: 16),
                    Text(s.guestTitle.toUpperCase(), textAlign: TextAlign.center, style: Rave.poster(32)),
                    const SizedBox(height: 8),
                    Text(s.guestBody, textAlign: TextAlign.center, style: Rave.body(color: Rave.muted)),
                    const SizedBox(height: 22),
                    PrimaryButton(label: s.signInOrUp, onTap: () => openLogin(context)),
                  ]),
                ),
              ),
            )
          else
          Expanded(
            child: ApiView<LibrarySummary>(
              path: '/v1/library/summary',
              parse: LibrarySummary.fromJson,
              builder: (context, lib, _) => switch (tab) {
                'artists' => _Ids(
                    ids: lib.followedArtists,
                    path: '/v1/catalog/artists',
                    row: (j) => _Row(title: j['name'], subtitle: s.kind('artist'), image: j['image_url'], round: true, onTap: () => openItem(context, 'artist', j['slug'] ?? j['id'])),
                  ),
                'albums' => _Ids(
                    ids: lib.savedReleases,
                    path: '/v1/catalog/releases',
                    row: (j) => _Row(title: j['title'], subtitle: (j['artist'] as Json?)?['name'] ?? '', image: j['cover_url'], onTap: () => openItem(context, 'release', j['id'])),
                  ),
                _ => ListView(padding: const EdgeInsets.only(bottom: 16), children: [
                    _Row(
                      title: s.liked,
                      subtitle: s.likedSub(lib.likedCount),
                      art: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.plum, Rave.berry])),
                        child: const Icon(Icons.favorite, color: Rave.mustard),
                      ),
                      onTap: () => openItem(context, 'liked', 'liked'),
                    ),
                    for (final p in lib.playlists) _Row(title: p.title, subtitle: 'Playlist · ${p.ownerName ?? 'RAVE'}', image: p.coverUrl, onTap: () => openItem(context, 'playlist', p.id)),
                  ]),
              },
            ),
          ),
        ]),
      ),
    );
  }
}

/// Daftar artis/album tersimpan: id → ringkasan via endpoint batch (?ids=).
class _Ids extends StatelessWidget {
  const _Ids({required this.ids, required this.path, required this.row});
  final List<String> ids;
  final String path;
  final Widget Function(Json) row;
  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) return ListView(children: [EmptyState(App.of(context).s.empty)]);
    return ApiView<List<Json>>(
      path: path,
      query: {'ids': ids.take(200).join(',')},
      parse: (j) => (j['data'] as List).cast<Json>(),
      builder: (_, list, _) => ListView(padding: const EdgeInsets.only(bottom: 16), children: list.map(row).toList()),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, this.image, this.art, this.round = false, required this.onTap});
  final String title, subtitle;
  final String? image;
  final Widget? art;
  final bool round;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: Row(children: [
            art ?? Cover(image, size: 60, round: round),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: Rave.muted)),
              ]),
            ),
          ]),
        ),
      );
}
