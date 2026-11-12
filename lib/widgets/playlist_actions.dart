import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../screens/login.dart';
import '../screens/shell.dart';
import 'common.dart';

/// Tab "Buat": lembar aksi (saat ini: Playlist). Tamu diminta masuk dulu.
Future<void> showCreateSheet(BuildContext context) async {
  final app = App.read(context);
  if (!app.api.authed && !await requireLogin(context)) return;
  if (!context.mounted) return;
  final s = app.s;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
              child: const Icon(Icons.queue_music_rounded, color: Rave.ink),
            ),
            title: Text(s.createPlaylist, style: Rave.body(size: 16, weight: FontWeight.w700)),
            subtitle: Text(s.createPlaylistHint, style: Rave.body(size: 13, color: Rave.muted)),
            onTap: () async {
              Navigator.pop(sheet);
              final id = await createPlaylist(context);
              if (id != null) openInActiveTab('playlist', id);
            },
          ),
        ]),
      ),
    ),
  );
}

/// Dialog nama playlist → POST /v1/library/playlists. Mengembalikan id playlist baru.
Future<String?> createPlaylist(BuildContext context, {String? addTrackId}) async {
  final app = App.read(context);
  final s = app.s;
  final ctl = TextEditingController(text: s.myPlaylist);
  final title = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      backgroundColor: Rave.base,
      shape: const RoundedRectangleBorder(side: BorderSide(color: Rave.line)),
      title: Text(s.namePlaylist.toUpperCase(), style: Rave.poster(28)),
      content: TextField(
        controller: ctl,
        autofocus: true,
        maxLength: 100,
        textCapitalization: TextCapitalization.sentences,
        style: Rave.body(size: 16, weight: FontWeight.w600),
        onSubmitted: (v) => Navigator.pop(d, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(s.cancel, style: Rave.body(color: Rave.muted))),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Rave.mustard, foregroundColor: Rave.ink, shape: const RoundedRectangleBorder()),
          onPressed: () => Navigator.pop(d, ctl.text.trim()),
          child: Text(s.create.toUpperCase(), style: Rave.label(size: 11, color: Rave.ink)),
        ),
      ],
    ),
  );
  ctl.dispose();
  if (title == null || title.isEmpty) return null;
  try {
    final p = await app.api.post('/v1/library/playlists', {'title': title}) as Json;
    final id = p['id'] as String;
    if (addTrackId != null) await app.api.post('/v1/library/playlists/$id/items', {'track_id': addTrackId});
    app.cache.invalidate('/v1/library');
    HapticFeedback.mediumImpact();
    if (context.mounted) toast(context, addTrackId != null ? s.addedTo(title) : s.playlistCreated(title));
    return id;
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
    return null;
  }
}

/// "Tambah ke playlist": pilih salah satu playlist milik pengguna atau buat baru.
Future<void> addToPlaylist(BuildContext context, Track t) async {
  final app = App.read(context);
  if (!app.api.authed && !await requireLogin(context)) return;
  if (!context.mounted) return;
  final s = app.s;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => FractionallySizedBox(
      heightFactor: 0.7,
      child: ApiView<List<PlaylistSummary>>(
        path: '/v1/library/playlists',
        parse: (j) => (j['data'] as List).map((x) => PlaylistSummary.fromJson(x as Json)).where((p) => p.ownerId == app.api.user?.id).toList(),
        builder: (context, list, _) => ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(s.addToPlaylist.toUpperCase(), style: Rave.poster(26))),
          ListTile(
            leading: Container(width: 48, height: 48, color: Rave.raised, child: const Icon(Icons.add_rounded, color: Rave.mustard)),
            title: Text(s.newPlaylist, style: Rave.body(size: 15, weight: FontWeight.w700)),
            onTap: () async {
              Navigator.pop(sheet);
              await createPlaylist(context, addTrackId: t.id);
            },
          ),
          for (final p in list)
            ListTile(
              leading: Cover(p.coverUrl, size: 48),
              title: Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 15, weight: FontWeight.w600)),
              subtitle: Text(s.songs(p.trackCount), style: Rave.body(size: 12.5, color: Rave.muted)),
              onTap: () async {
                Navigator.pop(sheet);
                try {
                  await app.api.post('/v1/library/playlists/${p.id}/items', {'track_id': t.id});
                  app.cache.invalidate('/v1/library');
                  if (context.mounted) toast(context, s.addedTo(p.title));
                } catch (e) {
                  if (context.mounted) toast(context, e.toString());
                }
              },
            ),
        ]),
      ),
    ),
  );
}
