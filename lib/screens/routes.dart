import 'package:flutter/material.dart';

import 'album.dart';
import 'artist.dart';
import 'playlist.dart';
import 'show.dart';
import 'settings.dart';
import '../core/app_state.dart';
import '../player/player.dart';
import '../widgets/common.dart';

/// Buka halaman detail di navigator tab yang aktif (riwayat per tab, seperti aplikasi musik).
void openItem(BuildContext context, String kind, String id) {
  final Widget? page = switch (kind) {
    'release' || 'album' => AlbumScreen(id: id),
    'artist' => ArtistScreen(id: id),
    'playlist' => PlaylistScreen(id: id),
    'liked' => const PlaylistScreen(id: 'liked'),
    'show' => ShowScreen(id: id),
    'settings' => const SettingsScreen(),
    _ => null,
  };
  if (page != null) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return;
  }
  // Episode/lagu: langsung diputar.
  final app = App.read(context);
  playablesOf(app, kind, id).then((items) {
    if (items.isNotEmpty) app.player.playQueue(items);
  }).catchError((Object e) {
    if (context.mounted) toast(context, e.toString());
  });
}

/// Putar koleksi (album/artis/playlist) dari kartu tanpa membukanya.
Future<void> playCollection(BuildContext context, String kind, String id) async {
  final app = App.read(context);
  try {
    final items = await playablesOf(app, kind, id);
    if (items.isNotEmpty) await app.player.playQueue(items);
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
}

typedef Playables = List<Playable>;
