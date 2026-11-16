import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/brand_marks.dart';
import '../widgets/common.dart';
import '../widgets/connection.dart';
import '../widgets/getting_started.dart';
import '../widgets/home_shelves.dart';
import '../widgets/links.dart';
import '../widgets/media.dart';
import '../widgets/motion.dart';
import 'browse.dart';
import 'live.dart';
import 'login.dart';
import 'routes.dart';
import 'shell.dart';

/// Bagian beranda per chip — sama dengan web `pages/fan/Home.tsx` (SHOWS). `quick` null = semua jenis.
/// Live TIDAK tampil di "Semua" — hanya di chip Live (kartu besar).
typedef _Show = ({List<String>? quick, bool recent, List<String> sections, bool featured, bool live, bool events});
const _shows = <String, _Show>{
  'all': (quick: null, recent: true, sections: ['releases', 'artists', 'shows', 'episodes', 'playlists'], featured: false, live: false, events: true),
  'music': (quick: ['release', 'artist', 'playlist'], recent: true, sections: ['releases', 'artists', 'playlists'], featured: true, live: false, events: false),
  'artists': (quick: ['artist'], recent: false, sections: ['artists'], featured: false, live: false, events: false),
  'podcasts': (quick: ['show', 'episode'], recent: false, sections: ['shows', 'episodes'], featured: false, live: false, events: false),
  'live': (quick: [], recent: false, sections: [], featured: false, live: true, events: false),
  'events': (quick: [], recent: false, sections: [], featured: false, live: false, events: true),
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String tab = 'all';
  bool podcasts = true, liveOn = false, ticketing = true;

  @override
  void initState() {
    super.initState();
    final app = App.read(context);
    // Modul platform (Super Admin) menentukan chip & langkah yang tampil.
    platformFlag(app, 'modules.podcasts').then((v) => mounted ? setState(() => podcasts = v) : null);
    platformFlag(app, 'modules.live', fallback: false).then((v) => mounted ? setState(() => liveOn = v) : null);
    platformFlag(app, 'modules.ticketing').then((v) => mounted ? setState(() => ticketing = v) : null);
  }

  void _cta(String step) {
    final app = App.read(context);
    switch (step) {
      case 'play':
        selectShellTab(1);
      case 'like':
        app.api.authed ? openItem(context, 'liked', 'liked') : openLogin(context);
      case 'playlist':
        selectShellTab(2);
      case 'follow':
        setState(() => tab = 'artists');
      case 'live':
        openHref(context, '/app/live');
      case 'events':
        openUrl('${app.settings.server}/app/events');
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final name = app.api.user?.displayName.split(' ').first;
    final city = app.api.user?.city ?? app.settings.city;
    final chips = [
      (value: 'all', label: s.chip('all'), icon: Icons.auto_awesome_rounded, dot: false),
      (value: 'music', label: s.chip('music'), icon: Icons.album_rounded, dot: false),
      (value: 'artists', label: s.chip('artists'), icon: Icons.mic_external_on_rounded, dot: false),
      if (podcasts) (value: 'podcasts', label: s.chip('podcasts'), icon: Icons.podcasts_rounded, dot: false),
      if (liveOn) (value: 'live', label: s.chip('live'), icon: Icons.sensors_rounded, dot: false),
      if (ticketing) (value: 'events', label: s.chip('events'), icon: Icons.confirmation_number_rounded, dot: false),
    ];
    final t = chips.any((c) => c.value == tab) ? tab : 'all';
    final show = _shows[t]!;
    return Scaffold(
      body: ApiView<HomeData>(
        path: '/v1/catalog/home',
        query: {'city': ?city},
        parse: HomeData.fromJson,
        loading: SafeArea(child: ListView(physics: const NeverScrollableScrollPhysics(), children: const [SizedBox(height: 60), ShelfSkeleton(), ShelfSkeleton()])),
        builder: (context, d, _) {
          final quick = d.quickPicks.where((it) => show.quick == null || show.quick!.contains(it.kind)).toList();
          final sections = d.sections.where((x) => x.items.isNotEmpty && show.sections.contains(x.kind) && (podcasts || !['shows', 'episodes'].contains(x.kind))).toList();
          final covers = [for (final q in d.quickPicks) ?q.imageUrl];
          // Chip tanpa isi (Live/Event punya catatan kosong sendiri).
          final rc = context.rc;
          final nothing = !show.live && !show.events && quick.isEmpty && sections.isEmpty && !(show.recent && app.api.authed) && !show.featured;
          return CustomScrollView(physics: raveVerticalPhysics, slivers: [
            SliverToBoxAdapter(
              child: Container(
                // Gelap: cahaya ungu. Terang ("poster kertas"): cahaya mustard/teal lembut + titik halftone ungu.
                decoration: BoxDecoration(
                  gradient: rc.isLight
                      ? const LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [Color(0x52F4C21F), Color(0x1F1F5C52), Color(0x00F6F1E7)],
                          stops: [0, 0.55, 1],
                        )
                      : const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Rave.purple, Color(0x662A1233), Rave.canvas]),
                ),
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 12, 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Bilah atas: ikon V RAVE (putih, tanpa kotak) sejajar satu ikon Pengaturan. Tamu: ikon membuka lembar
                  // Masuk / Daftar + Server; masuk: membuka layar Pengaturan.
                  SizedBox(
                    height: 44,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      RaveMark(size: 34, color: rc.isLight ? Rave.ink : Colors.white),
                      const Spacer(),
                      IconButton(
                        tooltip: s.settings,
                        onPressed: () => app.api.authed ? openItem(context, 'settings', '') : showGuestMenu(context),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ]),
                  ),
                  // Hero diturunkan di bawah bilah atas (tidak lagi berbagi baris dengan tombol masuk).
                  const SizedBox(height: 22),
                  Eyebrow('RAVE · ${app.api.authed ? s.home : s.guest}', color: rc.accent),
                  const SizedBox(height: 6),
                  Text('${s.greeting(DateTime.now().hour)}${name == null || name.isEmpty ? '' : ', $name'}'.toUpperCase(), style: Rave.poster(40)),
                  if (!app.api.authed) ...[
                    const SizedBox(height: 10),
                    Text(s.guestBanner, style: Rave.body(size: 13, color: rc.text.withValues(alpha: 0.85))),
                  ],
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: Semantics(
                label: s.chipsLabel,
                container: true,
                child: RaveChoiceChips<String>(value: t, options: chips, onChanged: (v) => setState(() => tab = v), padding: const EdgeInsets.fromLTRB(16, 4, 16, 6)),
              ),
            ),
            // Isi per chip; AnimatedSwitcher memberi transisi pudar saat chip berganti.
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous.map((w) => Positioned(top: 0, left: 0, right: 0, child: w)), ?current]),
                child: _Staggered(
                  key: ValueKey(t),
                  tab: t,
                  children: [
                    if (t == 'all') ...[
                      GettingStarted(liveOn: liveOn, eventsOn: ticketing, covers: covers, onCta: _cta),
                      const PicksShelf(),
                    ],
                    if (nothing) FilterEmptyNote(s.filterEmpty),
                    if (show.live && liveOn) LiveNowShelf(cardWidth: (MediaQuery.sizeOf(context).width * 0.84).clamp(260.0, 520.0), emptyText: s.filterEmpty),
                    if (quick.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(16, 22, 8, 0), child: _QuickPicks(items: quick)),
                    if (show.recent) const RecentlyPlayedShelf(),
                    for (final sec in sections)
                      Shelf(
                        key: ValueKey('sec-${sec.id}'),
                        title: sec.title,
                        children: [for (final it in sec.items.take(12)) MediaCard(item: it)],
                      ),
                    if (show.featured) const FeaturedPlaylistsShelf(),
                    if (show.events && ticketing) EventsShelf(city: city, emptyText: t == 'events' ? s.filterEmpty : null),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

/// Kisi 2 kolom tile cepat (seperti "Baru-baru ini" aplikasi musik), bergaya kliping RAVE; tombol putar/jeda kecil.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.items});
  final List<MediaItem> items;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final cols = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;
    final shown = items.take(cols * 3).toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(right: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 56, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: shown.length,
      itemBuilder: (_, i) {
        final it = shown[i];
        final key = '${it.kind}:${it.targetId}';
        final canPlay = playableKinds.contains(it.kind);
        return ListenableBuilder(
          listenable: app.player,
          builder: (context, _) {
            final active = app.player.isActive(key);
            return Pressable(child: Material(
              color: active ? Rave.mustard.withValues(alpha: context.rc.isLight ? 0.3 : 0.16) : context.rc.veil,
              child: InkWell(
                onTap: () => openItem(context, it.kind, it.targetId),
                child: Row(children: [
                  Cover(it.imageUrl, size: 56, placeholderIcon: it.kind == 'playlist' ? Icons.queue_music_rounded : null),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, weight: FontWeight.w700, color: active ? context.rc.accent : context.rc.text)),
                  ),
                  if (canPlay) ...[
                    const SizedBox(width: 4),
                    PlayFab(size: 32, playKey: key, semantic: '${app.s.play} ${it.title}', onPlay: () => playMedia(context, it.kind, it.targetId)),
                    const SizedBox(width: 10),
                  ] else
                    const SizedBox(width: 6),
                ]),
              ),
            ));
          },
        );
      },
    );
  }
}

/// Lembar Pengaturan tamu (ikon roda gigi Beranda): Masuk & Daftar, lalu alamat Server.
Future<void> showGuestMenu(BuildContext context) {
  final s = App.read(context).s;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(sheet).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s.settings.toUpperCase(), style: Rave.poster(28)),
          const SizedBox(height: 6),
          Text(s.guestBody, style: Rave.body(size: 13, color: sheet.rc.muted)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: OutlineButton(label: s.logIn, onTap: () { Navigator.pop(sheet); openLogin(context); })),
            const SizedBox(width: 10),
            Expanded(child: PrimaryButton(label: s.signUp, onTap: () { Navigator.pop(sheet); openLogin(context, signUp: true); })),
          ]),
          const SizedBox(height: 22),
          Divider(height: 1, color: sheet.rc.muted.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(s.server.toUpperCase(), style: Rave.label(size: 12, color: sheet.rc.text)),
          const SizedBox(height: 4),
          Text(s.serverHint, style: Rave.body(size: 12, color: sheet.rc.muted)),
          const SizedBox(height: 10),
          ServerEditor(onSaved: () => Navigator.pop(sheet)),
        ]),
      ),
    ),
  );
}

/// Bagian beranda masuk bertahap (pudar + geser), sekali per chip — tidak diulang saat dibangun ulang.
class _Staggered extends StatelessWidget {
  const _Staggered({super.key, required this.tab, required this.children});
  final String tab;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (var i = 0; i < children.length; i++) Entrance(index: i, id: 'home:$tab:$i', child: children[i])],
      );
}
