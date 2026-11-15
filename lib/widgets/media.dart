import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../player/player.dart';
import '../screens/routes.dart';
import 'common.dart';
import 'feedback.dart';
import 'motion.dart';
import 'playlist_actions.dart';

/// Lebar kartu rak: ≈2,2 kartu terlihat di ponsel (3,3 tablet, 5 layar lebar) — sama dengan rak web.
double shelfCardWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  final n = w >= 900 ? 5.2 : w >= 600 ? 3.3 : 2.2;
  return ((w - 16) / n).clamp(120.0, 220.0);
}

/// Jenis kartu yang bisa diputar langsung dari tombol di kartu (web: rilis, artis, playlist; + episode).
const playableKinds = {'release', 'artist', 'playlist', 'episode'};

/// Kartu media RAVE (web `MediaCard`): gambar persegi bertepi ink, tombol putar kotak yang menjadi Jeda saat item ini
/// yang diputar (ketuk = jeda/lanjut, bukan mengulang). Artis → kartu poster gig ([ArtistCard]).
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.item, this.width, this.play = true});
  final MediaItem item;
  final double? width;
  /// Tampilkan tombol putar untuk jenis yang bisa diputar.
  final bool play;

  String get playKey => '${item.kind}:${item.targetId}';

  @override
  Widget build(BuildContext context) {
    final w = width ?? shelfCardWidth(context);
    if (item.kind == 'artist') return ArtistCard(item: item, width: w, play: play);
    final app = App.of(context);
    final canPlay = play && playableKinds.contains(item.kind);
    return Pressable(child: SizedBox(
      width: w,
      child: ListenableBuilder(
        listenable: app.player,
        builder: (context, _) {
          final active = app.player.isActive(playKey);
          final rc = context.rc;
          return InkWell(
            onTap: () => openItem(context, item.kind, item.targetId),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    border: Border.all(color: Rave.ink, width: 2),
                    boxShadow: [BoxShadow(color: active ? Rave.mustard : rc.shadow, offset: active ? const Offset(5, 5) : const Offset(3, 3))],
                  ),
                  child: Stack(children: [
                    Cover(item.imageUrl, size: w - 18, placeholderIcon: item.kind == 'playlist' ? Icons.queue_music_rounded : null),
                    if (canPlay)
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: PlayFab(size: 40, playKey: playKey, semantic: '${app.s.play} ${item.title}', onPlay: () => playMedia(context, item.kind, item.targetId)),
                      ),
                  ]),
                ),
                const SizedBox(height: 10),
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700, color: active ? rc.accent : rc.text)),
                const SizedBox(height: 2),
                Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, color: rc.muted)),
              ]),
            ),
          );
        },
      ),
    ));
  }
}

/// Kartu artis bergaya poster gig (web `.artist-card`): foto persegi duotone/hitam-putih + raster halftone, nama
/// Staatliches besar di atas gradasi bawah, sudut kanan atas terpotong, bilah mustard di sisi kiri. Berwarna penuh
/// (dan bilah memanjang, bayangan mustard) saat lagu artis ini diputar.
class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.item, required this.width, this.play = true});
  final MediaItem item;
  final double width;
  final bool play;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final key = 'artist:${item.targetId}';
    final img = width - 20;
    return Pressable(child: SizedBox(
      width: width,
      child: ListenableBuilder(
        listenable: app.player,
        builder: (context, _) {
          final p = app.player;
          final active = p.isActive(key);
          final on = p.isPlayingKey(key);
          final rc = context.rc;
          return InkWell(
            onTap: () => openItem(context, 'artist', item.targetId),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: img + 6,
                  height: img + 6,
                  child: Stack(clipBehavior: Clip.none, children: [
                    // bilah sisi mustard
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      left: 0,
                      width: 4,
                      top: active ? 0 : img * 0.18,
                      bottom: active ? 6 : img * 0.18 + 6,
                      child: const ColoredBox(color: Rave.mustard),
                    ),
                    // bayangan sablon berbentuk sama (sudut terpotong)
                    Positioned(
                      left: 6 + (active ? 6 : 5),
                      top: active ? 6 : 5,
                      width: img,
                      height: img,
                      child: ClipPath(clipper: const NotchClipper(), child: ColoredBox(color: active ? Rave.mustard : rc.shadow)),
                    ),
                    Positioned(
                      left: 6,
                      top: 0,
                      width: img,
                      height: img,
                      // Poster di atas foto: selalu "pulau gelap" (teks terang) di kedua tema.
                      child: DarkZone(
                        child: ClipPath(
                        clipper: const NotchClipper(),
                        child: Stack(fit: StackFit.expand, children: [
                          const ColoredBox(color: Rave.purple),
                          if (item.imageUrl != null)
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 450),
                              child: active
                                  ? Cover(item.imageUrl, key: const ValueKey('c'), size: img)
                                  : Opacity(
                                      key: const ValueKey('g'),
                                      opacity: 0.85,
                                      child: ColorFiltered(colorFilter: _gigPoster, child: Cover(item.imageUrl, size: img)),
                                    ),
                            )
                          else
                            Center(child: Text(item.title.isEmpty ? '?' : item.title.substring(0, 1).toUpperCase(), style: Rave.poster(img * 0.5, color: Rave.mustard.withValues(alpha: 0.9)))),
                          if (!active) const CustomPaint(painter: HalftonePainter()),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE6180A1E)], stops: [0.38, 1]),
                            ),
                          ),
                          CustomPaint(painter: NotchBorderPainter(color: Rave.ink, width: 2)),
                          Positioned(
                            left: 10,
                            right: play ? 54 : 10,
                            bottom: 10,
                            child: Text(
                              item.title.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Rave.poster(width < 150 ? 21 : 25, color: active ? Rave.mustard : Rave.paper).copyWith(
                                height: 0.92,
                                shadows: const [Shadow(color: Rave.ink, offset: Offset(2, 2))],
                              ),
                            ),
                          ),
                          if (active)
                            Positioned(
                              left: 10,
                              top: 9,
                              child: Row(children: [
                                EqBars(playing: on, height: 10),
                                const SizedBox(width: 6),
                                Text((on ? app.s.nowOnAir : app.s.paused).toUpperCase(), style: Rave.label(size: 9.5, color: Rave.mustard)),
                              ]),
                            ),
                          if (play)
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: PlayFab(size: 40, playKey: key, semantic: '${app.s.play} ${item.title}', onPlay: () => playMedia(context, 'artist', item.targetId)),
                            ),
                        ]),
                      ),
                      ),
                    ),
                  ]),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(item.subtitle.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.label(size: 10, color: rc.muted)),
                  ),
                ],
              ]),
            ),
          );
        },
      ),
    ));
  }

  /// Hitam-putih kontras (web: grayscale(1) contrast(1.15) brightness(.95)).
  static const _gigPoster = ColorFilter.matrix([
    0.38, 0.75, 0.14, 0, -18, //
    0.38, 0.75, 0.14, 0, -18,
    0.38, 0.75, 0.14, 0, -18,
    0, 0, 0, 1, 0,
  ]);
}

/// Persegi dengan sudut kanan atas terpotong (siluet kartu artis).
class NotchClipper extends CustomClipper<Path> {
  const NotchClipper({this.notch = 22});
  final double notch;
  static Path pathFor(Size s, double n) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width - n, 0)
    ..lineTo(s.width, n)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();
  @override
  Path getClip(Size size) => pathFor(size, notch);
  @override
  bool shouldReclip(NotchClipper old) => old.notch != notch;
}

class NotchBorderPainter extends CustomPainter {
  const NotchBorderPainter({required this.color, this.width = 2, this.notch = 22});
  final Color color;
  final double width, notch;
  @override
  void paint(Canvas canvas, Size size) {
    final inset = width / 2;
    final path = NotchClipper.pathFor(Size(size.width - width, size.height - width), notch - inset).shift(Offset(inset, inset));
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color);
  }

  @override
  bool shouldRepaint(NotchBorderPainter old) => old.color != color || old.width != width;
}

/// Raster titik halftone (web: radial-gradient 1px setiap 5px).
class HalftonePainter extends CustomPainter {
  const HalftonePainter({this.color = const Color(0x590E0C0F), this.step = 5, this.radius = 1.1});
  final Color color;
  final double step, radius;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(HalftonePainter old) => old.color != color || old.step != step;
}

/// Rak horizontal bergulir (≈2,2 kartu terlihat di ponsel). Tinggi otomatis dari lebar kartu.
class Shelf extends StatelessWidget {
  const Shelf({super.key, required this.title, required this.children, this.height, this.action});
  final String title;
  final List<Widget> children;
  final double? height;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title, action: action),
        SizedBox(
          height: height ?? shelfCardWidth(context) + 72,
          // Tepi memudar + snap per kartu (deselerasi halus).
          child: RaveHorizontalList(snapExtent: shelfCardWidth(context), children: children),
        ),
      ]);
}

/// Suka/batal suka lagu dengan stiker konfirmasi + Urungkan (web `LikeButton`).
Future<void> toggleLike(BuildContext context, String trackId, {String? image, bool undoable = true}) async {
  final app = App.read(context);
  final s = app.s;
  final was = app.likes.has(trackId);
  try {
    await app.likes.toggle(trackId, app.cache);
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    final undo = undoable
        ? ToastAction(s.undo, () {
            if (context.mounted) {
              toggleLike(context, trackId, image: image, undoable: false);
            } else {
              app.likes.toggle(trackId, app.cache).catchError((_) {});
            }
          })
        : null;
    showToast(context, was ? s.unlikedToast : s.likedToast, kind: was ? ToastKind.info : ToastKind.ok, image: image, action: undo);
  } catch (e) {
    if (context.mounted) toastError(context, e);
  }
}

/// Baris lagu: ketuk untuk memutar dari daftar (ketuk lagi = jeda/lanjut), bilah EQ saat diputar, menu aksi.
/// [contextKey]: asal antrean (mis. `release:<id>`) agar tombol putar header ikut menjadi Jeda.
class TrackTile extends StatelessWidget {
  const TrackTile({super.key, required this.tracks, required this.index, this.showCover = true, this.number, this.contextKey});
  final List<Track> tracks;
  final int index;
  final bool showCover;
  final int? number;
  final String? contextKey;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = tracks[index];
    return ListenableBuilder(
      listenable: Listenable.merge([app.player, app.likes]),
      builder: (context, _) {
        final p = app.player;
        final isCur = p.current?.id == t.id;
        final on = isCur && (p.playing || p.buffering) && p.error == null;
        final liked = app.likes.has(t.id);
        final rc = context.rc;
        return InkWell(
          onTap: () => isCur ? p.toggle() : p.playQueue(tracks.map(Playable.fromTrack).toList(), index, contextKey),
          onLongPress: () => showTrackMenu(context, t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(children: [
              if (number != null)
                SizedBox(
                  width: 28,
                  child: isCur ? Align(alignment: Alignment.centerLeft, child: EqBars(playing: on)) : Text('$number', style: Rave.body(color: rc.muted)),
                ),
              if (showCover) ...[
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Stack(fit: StackFit.expand, children: [
                    Cover(t.coverUrl, size: 48),
                    if (isCur && number == null) ColoredBox(color: const Color(0x99000000), child: Center(child: EqBars(playing: on, color: Rave.mustard))),
                  ]),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 15, weight: FontWeight.w600, color: isCur ? rc.accent : rc.text)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (t.explicit) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        color: rc.muted,
                        child: Text('E', style: Rave.label(size: 8.5, color: rc.isLight ? rc.canvas : Rave.ink)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (liked) ...[Icon(Icons.favorite, size: 13, color: rc.accent), const SizedBox(width: 5)],
                    Flexible(child: Text(t.artist.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: rc.muted))),
                  ]),
                ]),
              ),
              IconButton(
                tooltip: app.s.like,
                onPressed: () => showTrackMenu(context, t),
                icon: Icon(Icons.more_vert_rounded, color: rc.muted),
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
            leading: Icon(icon, color: context.rc.text),
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
            subtitle: Text(t.artist.name, style: Rave.body(color: context.rc.muted)),
          ),
          const Divider(height: 1),
          if (app.api.authed) item(liked ? Icons.favorite : Icons.favorite_border, liked ? s.unlike : s.like, () => toggleLike(context, t.id, image: t.coverUrl)),
          item(Icons.playlist_add_rounded, s.addToPlaylist, () => addToPlaylist(context, t)),
          item(Icons.queue_music_rounded, s.addQueue, () {
            app.player.addToQueue(Playable.fromTrack(t));
            showToast(context, s.addedQueue(t.title), kind: ToastKind.ok, image: t.coverUrl);
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
  const TrackSliver({super.key, required this.tracks, this.numbered = false, this.showCover = true, this.contextKey});
  final List<Track> tracks;
  final bool numbered, showCover;
  final String? contextKey;
  @override
  Widget build(BuildContext context) {
    App.read(context).likes.check(tracks.map((t) => t.id));
    return SliverList.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final tile = TrackTile(
          tracks: tracks,
          index: i,
          showCover: showCover,
          contextKey: contextKey,
          number: numbered ? (tracks[i].trackNumber > 0 ? tracks[i].trackNumber : i + 1) : null,
        );
        // Baris awal masuk bertahap sekali; sisanya langsung (tak ada animasi ulang saat menggulir).
        return i < 12 ? Entrance(index: i, id: 'trk:${contextKey ?? tracks.first.id}:$i:${tracks[i].id}', child: tile) : tile;
      },
    );
  }
}

/// Acak/ulangi dengan stiker konfirmasi singkat (web: toast saat acak/ulangi berubah).
void toggleShuffleWithToast(BuildContext context) {
  final app = App.read(context);
  app.player.toggleShuffle();
  showToast(context, app.player.shuffle ? app.s.shuffleOn : app.s.shuffleOff, duration: const Duration(milliseconds: 2200));
}

void cycleRepeatWithToast(BuildContext context) {
  final app = App.read(context);
  final s = app.s;
  app.player.cycleRepeat();
  final r = app.player.repeat;
  showToast(context, r == LoopMode.all ? s.repeatAllToast : r == LoopMode.one ? s.repeatOneToast : s.repeatOffToast, duration: const Duration(milliseconds: 2200));
}

/// Putar koleksi dari tombol header (album/playlist/artis/podcast) + stiker "Pita berputar" (web usePlayMedia).
Future<void> playCollectionNow(BuildContext context, List<Playable> items, String key, {required String title, String? image}) async {
  if (items.isEmpty) return;
  final app = App.read(context);
  final f = app.player.playQueue(items, 0, key);
  showToast(context, title, title: app.s.nowSpinning, image: image, kind: ToastKind.ok, duration: const Duration(milliseconds: 2600));
  await f;
}
