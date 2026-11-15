import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/feedback.dart';
import 'login.dart';
import '../widgets/playlist_actions.dart';
import 'routes.dart';
import 'shell.dart';

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
              if (app.api.authed) IconButton(tooltip: s.settings, onPressed: () => openItem(context, 'settings', ''), icon: const Icon(Icons.settings_outlined)),
            ]),
          ),
          RaveChoiceChips<String>(
            value: tab,
            onChanged: (k) => setState(() => tab = k),
            options: [
              (value: 'playlists', label: s.playlists, icon: Icons.queue_music_rounded, dot: false),
              (value: 'artists', label: s.artists, icon: Icons.mic_external_on_rounded, dot: false),
              (value: 'albums', label: s.albums, icon: Icons.album_rounded, dot: false),
            ],
          ),
          if (!app.api.authed)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Icon(Icons.library_music_rounded, size: 56, color: context.rc.accent),
                    const SizedBox(height: 16),
                    Text(s.guestTitle.toUpperCase(), textAlign: TextAlign.center, style: Rave.poster(32)),
                    const SizedBox(height: 8),
                    Text(s.guestBody, textAlign: TextAlign.center, style: Rave.body(color: context.rc.muted)),
                    const SizedBox(height: 22),
                    PrimaryButton(label: s.signInOrUp, onTap: () => openLogin(context)),
                  ]),
                ),
              ),
            )
          else
          Expanded(
            // Data pustaka berubah (playlist dibuat/dihapus, simpan, ikuti) → muat ulang.
            child: ValueListenableBuilder<int>(
              valueListenable: app.cache.libraryRevision,
              builder: (context, rev, _) => ApiView<LibrarySummary>(
              revision: rev,
              path: '/v1/library/summary',
              parse: LibrarySummary.fromJson,
              builder: (context, lib, _) => switch (tab) {
                'artists' => _Ids(
                    empty: (s.emptyArtists, s.emptyArtistsBody),
                    ids: lib.followedArtists,
                    path: '/v1/catalog/artists',
                    row: (j) => _Row(
                      title: j['name'],
                      subtitle: s.kind('artist'),
                      image: j['image_url'],
                      playKind: 'artist',
                      playId: j['slug'] ?? j['id'],
                      onTap: () => openItem(context, 'artist', j['slug'] ?? j['id']),
                    ),
                  ),
                'albums' => _Ids(
                    empty: (s.emptyAlbums, s.emptyAlbumsBody),
                    ids: lib.savedReleases,
                    path: '/v1/catalog/releases',
                    row: (j) => _Row(
                      title: j['title'],
                      subtitle: (j['artist'] as Json?)?['name'] ?? '',
                      image: j['cover_url'],
                      playKind: 'release',
                      playId: j['id'],
                      onTap: () => openItem(context, 'release', j['id']),
                    ),
                  ),
                // builder: baris dibangun malas (pustaka bisa berisi ratusan playlist).
                _ => ListView.builder(
                    physics: raveVerticalPhysics,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: lib.playlists.length + 1,
                    itemBuilder: (context, i) {
                      if (i > 0) {
                        final p = lib.playlists[i - 1];
                        return _Row(
                          title: p.title,
                          subtitle: 'Playlist · ${p.ownerName ?? 'RAVE'}',
                          image: p.coverUrl,
                          placeholderIcon: Icons.queue_music_rounded,
                          playKind: p.trackCount > 0 ? 'playlist' : null,
                          playId: p.id,
                          onTap: () => openItem(context, 'playlist', p.id),
                        );
                      }
                      return _Row(
                      title: s.liked,
                      subtitle: s.likedSub(lib.likedCount),
                      art: (size) => Container(
                        width: size,
                        height: size,
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.plum, Rave.berry])),
                        child: Icon(Icons.favorite, color: Rave.mustard, size: size * 0.4),
                      ),
                      playKey: 'liked',
                      onPlay: () => _playLiked(context),
                      onTap: () => openItem(context, 'liked', 'liked'),
                    );
                    },
                  ),
              },
            ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Daftar artis/album tersimpan: id → ringkasan via endpoint batch (?ids=).
class _Ids extends StatelessWidget {
  const _Ids({required this.ids, required this.path, required this.row, required this.empty});
  final List<String> ids;
  final (String, String) empty;
  final String path;
  final Widget Function(Json) row;
  @override
  Widget build(BuildContext context) {
    if (ids.isEmpty) {
      return ListView(physics: raveVerticalPhysics, children: [
        EmptyState(empty.$1, body: empty.$2, action: App.of(context).s.findMusic, onAction: () => selectShellTab(1)),
      ]);
    }
    return ApiView<List<Json>>(
      path: path,
      query: {'ids': ids.take(200).join(',')},
      parse: (j) => (j['data'] as List).cast<Json>(),
      builder: (_, list, _) => ListView.builder(physics: raveVerticalPhysics, padding: const EdgeInsets.only(bottom: 16), itemCount: list.length, itemBuilder: (_, i) => row(list[i])),
    );
  }
}

/// Putar "Lagu yang Disukai" dari baris pustaka (konteks `liked`).
Future<void> _playLiked(BuildContext context) async {
  final app = App.read(context);
  try {
    final j = await app.api.get('/v1/library/likes');
    final items = [for (final x in (j['data'] as List? ?? const [])) Playable.fromTrack(Track.fromJson(x as Json))];
    if (items.isEmpty) return;
    await app.player.playQueue(items, 0, 'liked');
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

/// Baris pustaka: sampul persegi (tanpa sampul → kotak berikon, ukuran tetap), judul, subjudul, tombol putar/jeda.
/// Pref "Tata letak pustaka ringkas" → baris lebih rapat dengan sampul kecil.
class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, this.image, this.art, this.placeholderIcon, this.playKind, this.playId, this.playKey, this.onPlay, required this.onTap});
  final String title, subtitle;
  final String? image;
  final Widget Function(double size)? art;
  final IconData? placeholderIcon;
  final String? playKind, playId, playKey;
  final VoidCallback? onPlay;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final compact = app.settings.compactLibrary;
    final size = compact ? 40.0 : 60.0;
    final key = playKey ?? (playKind == null ? null : '$playKind:$playId');
    return ListenableBuilder(
      listenable: app.player,
      builder: (context, _) {
        final active = key != null && app.player.isActive(key);
        return InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: compact ? 4 : 7),
            child: Row(children: [
              art?.call(size) ?? Cover(image, size: size, placeholderIcon: placeholderIcon ?? Icons.music_note_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: compact ? 14 : 15, weight: FontWeight.w700, color: active ? context.rc.accent : context.rc.text)),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: compact ? 12 : 13, color: context.rc.muted)),
                ]),
              ),
              if (key != null) ...[
                const SizedBox(width: 8),
                PlayFab(size: 32, playKey: key, semantic: '${app.s.play} $title', onPlay: onPlay ?? () => playMedia(context, playKind!, playId!)),
              ],
            ]),
          ),
        );
      },
    );
  }
}
