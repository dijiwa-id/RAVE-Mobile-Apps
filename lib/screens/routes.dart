import 'dart:async';

import 'package:flutter/material.dart';

import 'album.dart';
import 'browse.dart';
import 'live.dart';
import 'artist.dart';
import 'playlist.dart';
import 'show.dart';
import 'settings.dart';
import '../core/app_state.dart';
import '../player/player.dart';
import '../widgets/feedback.dart';

/// Buka halaman detail di navigator tab yang aktif (riwayat per tab, seperti aplikasi musik).
void openItem(BuildContext context, String kind, String id) {
  final Widget? page = switch (kind) {
    'release' || 'album' => AlbumScreen(id: id),
    'artist' => ArtistScreen(id: id),
    'playlist' => PlaylistScreen(id: id),
    'liked' => const PlaylistScreen(id: 'liked'),
    'show' => ShowScreen(id: id),
    'settings' => const SettingsScreen(),
    'genre' => GenreScreen(id: id),
    'live' => LiveWatchScreen(id: id),
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
    if (context.mounted) toastError(context, e);
  });
}

/// Putar item media dari kartu tanpa membukanya (web `usePlayMedia`): rilis → semua lagu, artis → lagu populer,
/// playlist → isinya, episode → episode itu. Antrean diberi konteks `<kind>:<id>`; bila antrean sudah berasal dari
/// item yang sama, ketukan menjeda/melanjutkan (tidak mengulang). Mulai koleksi → stiker "Pita berputar".
Future<void> playMedia(BuildContext context, String kind, String id) async {
  final app = App.read(context);
  final p = app.player;
  final key = '$kind:$id';
  if (p.isActive(key)) return p.toggle();
  try {
    final m = await mediaOf(app, kind, id);
    if (m.items.isEmpty) return;
    unawaited(p.playQueue(m.items, 0, kind == 'episode' ? null : key));
    if (context.mounted && kind != 'episode') showToast(context, m.title, title: app.s.nowSpinning, image: m.image, kind: ToastKind.ok, duration: const Duration(milliseconds: 2600));
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

typedef Playables = List<Playable>;
