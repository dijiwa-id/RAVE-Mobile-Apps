import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/settings.dart';
import '../widgets/common.dart';
import '../widgets/connection.dart';
import 'login.dart';
import 'shell.dart';

/// Gerbang pembuka: splash animasi → onboarding (sekali, saat pertama dibuka) → aplikasi (sebagai tamu atau akun).
class IntroGate extends StatefulWidget {
  const IntroGate({super.key});
  @override
  State<IntroGate> createState() => _IntroGateState();
}

class _IntroGateState extends State<IntroGate> {
  String stage = 'splash';
  late final Future<void> _server;

  @override
  void initState() {
    super.initState();
    // Berjalan selama animasi splash: pilih server yang terjangkau sebelum onboarding/beranda memuat data.
    final app = App.read(context);
    _server = app.settings.resolveServer((u) => probeServer(app, u)).timeout(const Duration(seconds: 8), onTimeout: () {}).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final child = switch (stage) {
      'splash' => Splash(onDone: () => _server.then((_) {
            if (mounted) setState(() => stage = app.settings.onboarded ? 'app' : 'onboarding');
          })),
      'onboarding' => Onboarding(onDone: () {
          app.settings.setOnboarded();
          setState(() => stage = 'app');
        }),
      _ => const Shell(),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      transitionBuilder: (c, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(a), child: c)),
      child: KeyedSubtree(key: ValueKey(stage), child: child),
    );
  }
}

// ======================================================================= SPLASH

/// Splash: piringan berputar masuk, huruf R-A-V-E jatuh seperti potongan kertas ransom-note, stiker menempel.
class Splash extends StatefulWidget {
  const Splash({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300));

  @override
  void initState() {
    super.initState();
    c.forward().whenComplete(widget.onDone);
    HapticFeedback.lightImpact();
  }

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  Animation<double> _iv(double a, double b, [Curve curve = Curves.easeOutBack]) => CurvedAnimation(parent: c, curve: Interval(a, b, curve: curve));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final disc = min(size.width, size.height) * 0.92;
    const letters = ['R', 'A', 'V', 'E'];
    const paper = [Rave.mustard, Rave.paper, Rave.purple, Rave.ink];
    const ink = [Rave.ink, Rave.ink, Rave.paper, Rave.mustard];
    const tilt = [-0.10, 0.07, -0.05, 0.11];
    return Scaffold(
      backgroundColor: Rave.canvas,
      body: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final discIn = _iv(0.0, 0.45, Curves.easeOutCubic).value;
          return Stack(fit: StackFit.expand, children: [
            // Latar: gradien ungu yang "menyala" dari tengah.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 0.9 + 0.3 * discIn,
                  colors: [Color.lerp(Rave.canvas, Rave.purple, discIn)!, Rave.plum.withValues(alpha: discIn), Rave.canvas],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            // Piringan hitam berputar masuk dari bawah.
            Positioned(
              left: (size.width - disc) / 2,
              top: size.height * 0.5 - disc / 2 + (1 - discIn) * size.height * 0.6,
              child: Transform.rotate(
                angle: c.value * pi * 3,
                child: Opacity(opacity: discIn.clamp(0, 1), child: Vinyl(size: disc, label: Rave.mustard)),
              ),
            ),
            // Huruf ransom-note jatuh bergantian.
            Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                for (var i = 0; i < 4; i++)
                  Builder(builder: (_) {
                    final t = _iv(0.32 + i * 0.08, 0.62 + i * 0.08).value;
                    return Opacity(
                      opacity: t.clamp(0, 1),
                      child: Transform.translate(
                        offset: Offset(0, (1 - t) * -120),
                        child: Transform.rotate(
                          angle: tilt[i] * (2 - t),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                            decoration: BoxDecoration(
                              color: paper[i],
                              border: i == 3 ? Border.all(color: Rave.paper, width: 3) : null,
                              boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(4, 4))],
                            ),
                            child: Text(letters[i], style: Rave.poster(min(size.width * 0.2, 96), color: ink[i])),
                          ),
                        ),
                      ),
                    );
                  }),
              ]),
            ),
            // Stiker menempel di bawah wordmark.
            Align(
              alignment: const Alignment(0.35, 0.28),
              child: Transform.scale(
                scale: _iv(0.72, 0.9).value.clamp(0, 2),
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Rave.paper, border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                    child: Text('DIY · INDIE · LIVE', style: Rave.label(size: 11, color: Rave.ink)),
                  ),
                ),
              ),
            ),
            // Nomor katalog ala label rekaman.
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: Opacity(
                opacity: _iv(0.6, 0.9, Curves.easeOut).value.clamp(0, 1),
                child: Text('RV-MOBILE · ${DateTime.now().year} · DIJIWA.ID', textAlign: TextAlign.center, style: Rave.label(size: 10, color: Rave.paper.withValues(alpha: 0.55))),
              ),
            ),
            const IgnorePointer(child: Grain()),
          ]);
        },
      ),
    );
  }
}

// =================================================================== ONBOARDING

/// Onboarding personalisasi (sama dengan web /onboarding & endpoint /v1/me/onboarding):
/// Selamat datang → kota → genre → min. 3 artis → siap (Daftar / Masuk / Jelajahi dulu).
/// Pilihan tamu disimpan di perangkat dan dikirim saat ia mendaftar/masuk.
class Onboarding extends StatefulWidget {
  const Onboarding({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<Onboarding> createState() => _OnboardingState();
}

const _cities = ['Jakarta', 'Bandung', 'Yogyakarta', 'Surabaya', 'Malang', 'Bali', 'Medan', 'Semarang', 'Makassar', 'Solo', 'Palembang', 'Lainnya'];
const _fallbackGenres = ['indie-pop', 'folk', 'akustik', 'rock', 'post-punk', 'indie-rock', 'r-n-b', 'soul', 'shoegaze', 'dream-pop', 'hip-hop', 'pop', 'electronic', 'jazz', 'dangdut'];

class _OnboardingState extends State<Onboarding> {
  final _pc = PageController();
  int step = 0;
  String? city;
  final genres = <String>{};
  final artists = <String>{};
  static const steps = 5;

  @override
  void initState() {
    super.initState();
    final st = App.read(context).settings;
    city = st.city;
    genres.addAll(st.genres);
    artists.addAll(st.artistIds);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int i) {
    HapticFeedback.selectionClick();
    setState(() => step = i);
    _pc.animateToPage(i, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Future<void> _save() => App.read(context).settings.setPersonalization(city, genres.toList(), artists.toList());

  Future<void> _finish({String? auth}) async {
    await _save();
    if (!mounted) return;
    if (auth != null) {
      final ok = await openLogin(context, signup: auth == 'signup');
      if (!ok) return;
    }
    widget.onDone();
  }

  bool get _canNext => switch (step) { 1 => city != null, 2 => genres.isNotEmpty, 3 => artists.length >= 3, _ => true };

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    const tints = [Rave.purple, Rave.teal, Rave.plum, Rave.berry, Rave.purple];
    return Scaffold(
      backgroundColor: Rave.canvas,
      body: Stack(fit: StackFit.expand, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tints[step], Rave.canvas], stops: const [0, 0.7])),
        ),
        SafeArea(
          child: Column(children: [
            // Kepala: kembali · progres bersegmen · bahasa · lewati
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
              child: Row(children: [
                SizedBox(
                  width: 44,
                  child: step > 0 ? IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => _go(step - 1), icon: const Icon(Icons.arrow_back_rounded)) : null,
                ),
                Expanded(
                  child: Row(children: [
                    for (var k = 0; k < steps; k++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          color: k <= step ? Rave.mustard : Rave.paper.withValues(alpha: 0.2),
                        ),
                      ),
                  ]),
                ),
                for (final l in ['id', 'en'])
                  GestureDetector(
                    onTap: () => app.settings.setLocale(l),
                    child: Padding(padding: const EdgeInsets.all(8), child: Text(l.toUpperCase(), style: Rave.label(size: 11, color: app.settings.locale == l ? Rave.mustard : Rave.paper.withValues(alpha: 0.5)))),
                  ),
                if (step > 0 && step < steps - 1)
                  TextButton(onPressed: () => _go(steps - 1), child: Text(s.obSkip.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper))),
              ]),
            ),
            Expanded(
              child: PageView(
                controller: _pc,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _Welcome(onLogin: () => _finish(auth: 'login')),
                  _Question(
                    eyebrow: '01 / 03',
                    title: s.obCityTitle,
                    hint: s.obCityHint,
                    child: _Chips(options: _cities, selected: {?city}, onTap: (c) => setState(() => city = c)),
                  ),
                  _Question(
                    eyebrow: '02 / 03',
                    title: s.obGenreTitle,
                    hint: s.obPicked(genres.length),
                    child: _GenreChips(selected: genres, onTap: (g) => setState(() => genres.contains(g) ? genres.remove(g) : genres.add(g))),
                  ),
                  _Question(
                    eyebrow: '03 / 03',
                    title: s.obArtistTitle,
                    hint: s.obArtistsPicked(artists.length),
                    child: _ArtistPicker(selected: artists, genres: genres, onTap: (id) => setState(() => artists.contains(id) ? artists.remove(id) : artists.add(id))),
                  ),
                  _Ready(city: city, genres: genres.length, artists: artists.length),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: step == steps - 1
                    ? Column(key: const ValueKey('cta'), children: [
                        PrimaryButton(label: s.signup, onTap: () => _finish(auth: 'signup')),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: _Ghost(label: s.signIn, onTap: () => _finish(auth: 'login'))),
                          const SizedBox(width: 10),
                          Expanded(child: _Ghost(label: s.obGuest, onTap: _finish)),
                        ]),
                      ])
                    : SizedBox(
                        key: ValueKey('next$step'),
                        width: double.infinity,
                        child: PrimaryButton(label: step == 0 ? s.obStart : s.obNext, onTap: _canNext ? () => _go(step + 1) : null),
                      ),
              ),
            ),
          ]),
        ),
        const IgnorePointer(child: Grain()),
      ]),
    );
  }
}

/// Langkah 0: poster sambutan dengan sampul yang berjatuhan masuk.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Image.asset('assets/brand/rave-logo.webp', height: 30),
        const Expanded(child: Center(child: _ArtCovers())),
        Text(s.ob1Title.toUpperCase(), style: Rave.poster(MediaQuery.sizeOf(context).width > 400 ? 50 : 42)),
        const SizedBox(height: 10),
        Text(s.ob1Body, style: Rave.body(size: 15.5, color: Rave.paper.withValues(alpha: 0.85), height: 1.45)),
        TextButton(
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
          onPressed: onLogin,
          child: Text(s.haveAccount, style: Rave.body(weight: FontWeight.w700, color: Rave.mustard)),
        ),
      ]),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.eyebrow, required this.title, required this.hint, required this.child});
  final String eyebrow, title, hint;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Eyebrow(eyebrow, color: Rave.mustard),
          const SizedBox(height: 8),
          Text(title.toUpperCase(), style: Rave.poster(38)),
          const SizedBox(height: 6),
          AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(hint, key: ValueKey(hint), style: Rave.body(size: 14, color: Rave.muted))),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: 12), child: child)),
        ]),
      );
}

/// Chip pilihan bergaya stiker: memantul & miring saat dipilih.
class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.selected, required this.onTap, this.labels});
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onTap;
  final Map<String, String>? labels;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 10, runSpacing: 10, children: [
        for (var i = 0; i < options.length; i++)
          Builder(builder: (_) {
            final o = options[i];
            final on = selected.contains(o);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(o);
              },
              child: AnimatedScale(
                scale: on ? 1.06 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedRotation(
                  turns: on ? (i.isEven ? -0.008 : 0.008) : 0,
                  duration: const Duration(milliseconds: 180),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: on ? Rave.mustard : Colors.white.withValues(alpha: 0.08),
                      border: Border.all(color: on ? Rave.ink : Rave.paper.withValues(alpha: 0.25), width: on ? 2 : 1),
                      boxShadow: on ? Rave.hardShadow : null,
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (on) ...[const Icon(Icons.check_rounded, size: 16, color: Rave.ink), const SizedBox(width: 4)],
                      Text((labels?[o] ?? o).toUpperCase(), style: Rave.label(size: 11.5, color: on ? Rave.ink : Rave.paper)),
                    ]),
                  ),
                ),
              ),
            );
          }),
      ]);
}

/// Muat data onboarding SEKALI (bukan di setiap build): status memuat → data / galat yang jelas.
/// Dimuat ulang otomatis bila server diganti; galat menawarkan "Coba lagi" & server lain dari preset.
class _Remote extends StatefulWidget {
  const _Remote({required this.path, required this.builder, this.query, this.offlineFallback = false});
  final String path;
  final Map<String, String>? query;
  /// `data` null hanya bila [offlineFallback] dan pemuatan gagal (pemanggil memakai daftar cadangan).
  final Widget Function(BuildContext, Json? data) builder;
  final bool offlineFallback;
  @override
  State<_Remote> createState() => _RemoteState();
}

class _RemoteState extends State<_Remote> {
  Json? data;
  bool failed = false;
  late final AppState app;
  late String server;
  String get key => widget.query == null ? widget.path : '${widget.path}?${Uri(queryParameters: widget.query).query}';

  @override
  void initState() {
    super.initState();
    app = App.read(context);
    server = app.settings.server;
    app.settings.addListener(_onSettings);
    _load();
  }

  @override
  void dispose() {
    app.settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (app.settings.server == server) return;
    server = app.settings.server;
    app.cache.invalidate(widget.path);
    _load();
  }

  Future<void> _load() async {
    setState(() => failed = false);
    try {
      final v = await app.cache.load(key, () async => await app.api.request<Json>(widget.path, query: widget.query, auth: false, timeout: const Duration(seconds: 8)));
      if (mounted) setState(() => data = v as Json);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data != null) return widget.builder(context, data);
    if (failed) {
      if (widget.offlineFallback) return widget.builder(context, null);
      return _Offline(retry: _load);
    }
    return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: Rave.mustard)));
  }
}

/// Server tak terjangkau di onboarding: coba lagi, pindah ke server preset lain, atau lewati (tombol LEWATI di atas).
class _Offline extends StatefulWidget {
  const _Offline({required this.retry});
  final Future<void> Function() retry;
  @override
  State<_Offline> createState() => _OfflineState();
}

class _OfflineState extends State<_Offline> {
  bool busy = false;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final others = serverPresets.where((p) => p.$2 != app.settings.server).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_off_rounded, color: Rave.berry),
          const SizedBox(width: 10),
          Expanded(child: Text(s.serverDown, style: Rave.body(weight: FontWeight.w700))),
        ]),
        const SizedBox(height: 6),
        Text(app.settings.server, style: const TextStyle(fontFamily: Rave.mono, fontSize: 12, color: Rave.muted)),
        const SizedBox(height: 4),
        Text(s.onboardingOfflineHint, style: Rave.body(size: 13, color: Rave.muted)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlineButton(
            label: busy ? '…' : s.retry,
            onTap: busy
                ? null
                : () async {
                    setState(() => busy = true);
                    await widget.retry();
                    if (mounted) setState(() => busy = false);
                  },
          ),
          for (final p in others)
            OutlineButton(
              label: s.useServer(p.$1),
              onTap: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final v = await probeServer(app, p.$2);
                      if (!mounted) return;
                      setState(() => busy = false);
                      if (v == null) return toast(this.context, s.serverUnreachable(p.$1));
                      await switchServer(app, p.$2); // memicu muat ulang lewat listener pengaturan
                    },
            ),
        ]),
      ]),
    );
  }
}

/// Genre dari katalog (/v1/catalog/genres), cadangan daftar tetap bila offline.
class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.selected, required this.onTap});
  final Set<String> selected;
  final void Function(String) onTap;
  @override
  Widget build(BuildContext context) => _Remote(
        path: '/v1/catalog/genres',
        offlineFallback: true,
        builder: (_, j) {
          final list = (j?['data'] as List?)?.cast<Json>();
          final ids = list != null && list.isNotEmpty ? list.map((g) => g['id'] as String).toList() : _fallbackGenres;
          final labels = {for (final g in list ?? const <Json>[]) g['id'] as String: (g['name'] ?? g['id']) as String};
          return _Chips(options: ids, selected: selected, onTap: onTap, labels: labels);
        },
      );
}

/// Kisi artis bulat; artis bergenre pilihan diurutkan lebih dulu. Tanda centang mustard saat dipilih.
class _ArtistPicker extends StatelessWidget {
  const _ArtistPicker({required this.selected, required this.genres, required this.onTap});
  final Set<String> selected, genres;
  final void Function(String) onTap;
  @override
  Widget build(BuildContext context) {
    return _Remote(
      path: '/v1/catalog/artists',
      query: const {'limit': '50'},
      builder: (_, j) {
        final data = ((j?['data'] as List?) ?? const []).map((a) => ArtistSummary.fromJson(a as Json)).toList();
        data.sort((a, b) => (b.genres.any(genres.contains) ? 1 : 0) - (a.genres.any(genres.contains) ? 1 : 0));
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 120, mainAxisExtent: 142, crossAxisSpacing: 10, mainAxisSpacing: 6),
          itemCount: data.length,
          itemBuilder: (_, i) {
            final a = data[i];
            final on = selected.contains(a.id);
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(a.id);
              },
              child: Column(children: [
                AnimatedScale(
                  scale: on ? 0.92 : 1,
                  duration: const Duration(milliseconds: 160),
                  child: Stack(clipBehavior: Clip.none, children: [
                    Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: on ? Rave.mustard : Colors.transparent, width: 3)),
                      child: Cover(a.imageUrl, size: 92, round: true),
                    ),
                    if (on)
                      Positioned(
                        right: -2,
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: Rave.mustard, shape: BoxShape.circle, border: Border.all(color: Rave.ink, width: 2)),
                          child: const Icon(Icons.check_rounded, size: 16, color: Rave.ink),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(a.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, weight: FontWeight.w700, color: on ? Rave.mustard : Rave.paper)),
              ]),
            );
          },
        );
      },
    );
  }
}

/// Langkah terakhir: ringkasan pilihan + fitur unggulan (lirik, latar belakang, dukung artis).
class _Ready extends StatelessWidget {
  const _Ready({required this.city, required this.genres, required this.artists});
  final String? city;
  final int genres, artists;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    Widget feat(IconData i, String t, String b) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
              child: Icon(i, color: Rave.ink, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: Rave.body(size: 15, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(b, style: Rave.body(size: 13, color: Rave.muted, height: 1.35)),
              ]),
            ),
          ]),
        );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(child: SizedBox(height: 210, child: _ArtLive())),
        const SizedBox(height: 10),
        Text(s.obReadyTitle.toUpperCase(), style: Rave.poster(42)),
        const SizedBox(height: 6),
        if (artists >= 3) Text(s.obReadySummary(city ?? '-', genres, artists), style: Rave.body(size: 14, color: Rave.mustard)),
        const SizedBox(height: 18),
        feat(Icons.lyrics_outlined, s.ob2Title, s.ob2Body),
        feat(Icons.favorite_rounded, s.ob3Title, s.ob3Body),
      ]),
    );
  }
}

class _Ghost extends StatelessWidget {
  const _Ghost({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(border: Border.all(color: Rave.paper.withValues(alpha: 0.7), width: 1.5)),
          child: Text(label.toUpperCase(), style: Rave.label(size: 11.5, color: Rave.paper)),
        ),
      );
}

// ================================================================ ILUSTRASI

/// Piringan hitam (alur, label tengah, kilap) — digambar, tanpa aset.
class Vinyl extends StatelessWidget {
  const Vinyl({super.key, required this.size, this.label = Rave.mustard});
  final double size;
  final Color label;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _VinylPainter(label));
}

class _VinylPainter extends CustomPainter {
  _VinylPainter(this.label);
  final Color label;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF121113));
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.05);
    for (var k = r * 0.38; k < r * 0.97; k += r * 0.025) {
      canvas.drawCircle(c, k, groove);
    }
    // Kilap diagonal.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = SweepGradient(
          colors: [Colors.transparent, Colors.white.withValues(alpha: 0.10), Colors.transparent, Colors.transparent, Colors.white.withValues(alpha: 0.07), Colors.transparent],
          stops: const [0, 0.08, 0.18, 0.5, 0.58, 0.68],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r * 0.34, Paint()..color = label);
    final tp = TextPainter(text: TextSpan(text: 'RAVE', style: Rave.poster(r * 0.16, color: Rave.ink)), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, r * 0.2));
    canvas.drawCircle(c, r * 0.035, Paint()..color = Rave.canvas);
  }

  @override
  bool shouldRepaint(_VinylPainter old) => old.label != label;
}

/// Halaman 1: tumpukan sampul berwarna RAVE yang miring seperti kliping di dinding.
class _ArtCovers extends StatelessWidget {
  const _ArtCovers();
  @override
  Widget build(BuildContext context) {
    const cols = [Rave.mustard, Rave.purpleSoft, Rave.teal, Rave.berry];
    const rot = [-0.16, 0.10, -0.05, 0.14];
    const off = [Offset(-62, -66), Offset(66, -44), Offset(-54, 62), Offset(58, 76)];
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(alignment: Alignment.center, children: [
        const Positioned(right: -40, child: Vinyl(size: 230, label: Rave.purple)),
        for (var k = 0; k < 4; k++)
          Transform.translate(
            offset: off[k],
            child: Transform.rotate(
              angle: rot[k],
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(color: cols[k], border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(5, 5))]),
                child: Stack(children: [
                  Positioned(left: 10, top: 10, child: Text(['SENJA', 'NIRMALA', 'DARA', 'KOTA MATI'][k], style: Rave.poster(20, color: k == 0 ? Rave.ink : Rave.paper))),
                  Positioned(right: 8, bottom: 8, child: Text('RV-0${k + 1}', style: Rave.label(size: 8.5, color: k == 0 ? Rave.ink : Rave.paper))),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Halaman 3: tiket gig + stiker LIVE (dukung artis: live, tiket, ikuti).
class _ArtLive extends StatelessWidget {
  const _ArtLive();
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        height: 280,
        child: Stack(alignment: Alignment.center, children: [
          Transform.rotate(
            angle: 0.06,
            child: Container(
              width: 270,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Rave.paper, border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(6, 6))]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('ADMIT ONE · RV-TIX', style: Rave.label(size: 9.5, color: Rave.berry)),
                const SizedBox(height: 6),
                Text('SENJA KOLEKTIF', style: Rave.poster(36, color: Rave.ink)),
                Text('LIVE DI BANDUNG', style: Rave.poster(22, color: Rave.purple)),
                const SizedBox(height: 10),
                Container(height: 1.5, color: Rave.ink),
                const SizedBox(height: 8),
                Row(children: [
                  Text('SAB · 20:00 WIB', style: Rave.label(size: 10, color: Rave.ink)),
                  const Spacer(),
                  const Icon(Icons.qr_code_2_rounded, color: Rave.ink, size: 34),
                ]),
              ]),
            ),
          ),
          Positioned(
            top: 6,
            left: 8,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFD7263D), border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Rave.paper, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('LIVE', style: Rave.label(size: 12, color: Rave.paper)),
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 6,
            child: Transform.rotate(
              angle: 0.12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
                child: Text('+ ${App.of(context).s.follow.toUpperCase()}', style: Rave.label(size: 11, color: Rave.ink)),
              ),
            ),
          ),
        ]),
      );
}

/// Tekstur grain fotokopi (bintik acak, digambar sekali lalu di-cache sebagai lapisan).
class Grain extends StatelessWidget {
  const Grain({super.key});
  @override
  Widget build(BuildContext context) => const RepaintBoundary(child: CustomPaint(painter: _GrainPainter(), size: Size.infinite));
}

class _GrainPainter extends CustomPainter {
  const _GrainPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(7);
    final light = Paint()..color = Colors.white.withValues(alpha: 0.05);
    final dark = Paint()..color = Colors.black.withValues(alpha: 0.10);
    final n = (size.width * size.height / 90).clamp(0, 9000).toInt();
    final pts1 = <Offset>[], pts2 = <Offset>[];
    for (var k = 0; k < n; k++) {
      (k.isEven ? pts1 : pts2).add(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height));
    }
    canvas.drawPoints(PointMode.points, pts1, light..strokeWidth = 1.2);
    canvas.drawPoints(PointMode.points, pts2, dark..strokeWidth = 1.4);
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}
