import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/home_shelves.dart';
import '../widgets/media.dart';
import 'live.dart';
import 'login.dart';
import 'routes.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final name = app.api.user?.displayName.split(' ').first;
    return Scaffold(
      body: ApiView<HomeData>(
        path: '/v1/catalog/home',
        query: {'city': ?(app.api.user?.city ?? app.settings.city)},
        parse: HomeData.fromJson,
        builder: (context, d, _) => CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Rave.purple, Color(0x662A1233), Rave.canvas]),
              ),
              padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 14, 8, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Eyebrow('RAVE · ${app.api.authed ? s.home : s.guest}', color: Rave.mustard)),
                  if (!app.api.authed) ...[
                    _SignupChip(onTap: () => openLogin(context), label: s.signInOrUp),
                    const SizedBox(width: 4),
                  ],
                  IconButton(tooltip: s.settings, onPressed: () => openItem(context, 'settings', ''), icon: const Icon(Icons.settings_outlined)),
                ]),
                Text('${s.greeting(DateTime.now().hour)}${name == null || name.isEmpty ? '' : ', $name'}'.toUpperCase(), style: Rave.poster(40)),
                if (!app.api.authed) ...[
                  const SizedBox(height: 10),
                  Text(s.guestBanner, style: Rave.body(size: 13, color: Rave.paper.withValues(alpha: 0.85))),
                ],
                const SizedBox(height: 16),
                _QuickPicks(items: d.quickPicks),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: LiveNowShelf()),
          const SliverToBoxAdapter(child: RecentlyPlayedShelf()),
          for (final sec in d.sections.where((x) => x.items.isNotEmpty))
            SliverToBoxAdapter(
              child: Shelf(
                title: sec.title,
                height: sec.kind == 'artists' ? 196 : 214,
                children: [for (final it in sec.items.take(12)) MediaCard(item: it)],
              ),
            ),
          const SliverToBoxAdapter(child: FeaturedPlaylistsShelf()),
          SliverToBoxAdapter(child: EventsShelf(city: app.api.user?.city ?? app.settings.city)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }
}

/// Kisi 2 kolom tile cepat (seperti "Baru-baru ini" aplikasi musik), bergaya kliping RAVE.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.items});
  final List<MediaItem> items;
  @override
  Widget build(BuildContext context) {
    final cols = MediaQuery.sizeOf(context).width > 600 ? 3 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(right: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: 56, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: items.take(cols * 3).length,
      itemBuilder: (_, i) {
        final it = items[i];
        return Material(
          color: Colors.white.withValues(alpha: 0.10),
          child: InkWell(
            onTap: () => openItem(context, it.kind, it.targetId),
            child: Row(children: [
              Cover(it.imageUrl, size: 56, round: it.kind == 'artist'),
              const SizedBox(width: 8),
              Expanded(child: Text(it.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, weight: FontWeight.w700))),
              const SizedBox(width: 6),
            ]),
          ),
        );
      },
    );
  }
}

/// Tombol "Daftar gratis" kecil: mustard, teks ink, bayangan sablon.
class _SignupChip extends StatelessWidget {
  const _SignupChip({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
          child: Text(label.toUpperCase(), style: Rave.label(size: 10, color: Rave.ink)),
        ),
      );
}
