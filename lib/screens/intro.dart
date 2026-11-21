import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../core/settings.dart';
import '../widgets/cassette.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/connection.dart';
import '../widgets/vinyl.dart';
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
      // Splash & onboarding = poster bermerek, selalu gelap (kedua tema).
      'splash' => DarkZone(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: Rave.overlayFor(Brightness.dark),
            child: Splash(onDone: () => _server.then((_) {
                  if (mounted) setState(() => stage = app.settings.onboarded ? 'app' : 'onboarding');
                })),
          ),
        ),
      'onboarding' => DarkZone(
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: Rave.overlayFor(Brightness.dark),
            child: Onboarding(onDone: () {
              app.settings.setOnboarded();
              setState(() => stage = 'app');
            }),
          ),
        ),
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

/// Ritme tata letak onboarding (dp): gutter horizontal mengikuti lebar (layar 320 dp tetap lega), judul poster
/// diskalakan dengan lebar, jarak vertikal dari skala 4/8/12/16.
abstract final class _Ob {
  static double gutter(double w) => w < 360 ? Rave.gutter : Rave.gutter * 1.5;
  static double title(double w) => (w * 0.11).clamp(34.0, 46.0);
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0;
}

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
/// Cadangan offline = genre populer taksonomi bersama (Development/packages/domain/src/genres.ts).
const _fallbackGenres = ['pop', 'indie-pop', 'bedroom-pop', 'city-pop', 'k-pop', 'indie-rock', 'shoegaze', 'lo-fi', 'rock', 'hip-hop', 'r-n-b', 'electronic', 'dangdut', 'dangdut-koplo', 'jazz', 'folk', 'akustik'];

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
      final ok = await openLogin(context);
      if (!ok) return;
    }
    widget.onDone();
  }

  bool get _canNext => switch (step) { 1 => city != null, 2 => genres.isNotEmpty, 3 => artists.length >= 3, _ => true };

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final g = _Ob.gutter(MediaQuery.sizeOf(context).width);
    const tints = [Rave.purple, Rave.teal, Rave.plum, Rave.berry, Rave.purple];
    return Scaffold(
      backgroundColor: Rave.canvas,
      body: Stack(fit: StackFit.expand, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [tints[step], Rave.canvas], stops: const [0, 0.62])),
        ),
        SafeArea(
          child: Column(children: [
            // Kepala: kembali · progres bersegmen · bahasa · lewati (muncul/hilang dengan animasi ukuran, tanpa lompatan).
            Padding(
              padding: EdgeInsets.fromLTRB(4, _Ob.xs, g - 8, 0),
              child: Row(children: [
                SizedBox.square(
                  dimension: Rave.tap,
                  child: step > 0 ? IconButton(tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => _go(step - 1), icon: const Icon(Icons.arrow_back_rounded)) : null,
                ),
                Expanded(
                  child: Semantics(
                    label: '${step + 1} / $steps',
                    child: Row(children: [
                      for (var k = 0; k < steps; k++)
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: k <= step ? Rave.mustard : Rave.paper.withValues(alpha: 0.18),
                          ),
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: _Ob.m),
                _LangToggle(value: app.settings.locale, onChanged: app.settings.setLocale),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  child: step > 0 && step < steps - 1
                      ? TextButton(onPressed: () => _go(steps - 1), child: Text(s.obSkip.toUpperCase(), style: Rave.label(size: 11, color: Rave.paper)))
                      : const SizedBox(width: 8, height: Rave.tap),
                ),
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
                    child: _GenreChips(selected: genres, onTap: (x) => setState(() => genres.contains(x) ? genres.remove(x) : genres.add(x))),
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
            // CTA tersemat di bawah (SafeArea memberi jarak bilah navigasi/gesture).
            Padding(
              padding: EdgeInsets.fromLTRB(g, _Ob.m, g, _Ob.l),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: step == steps - 1
                    ? Column(key: const ValueKey('cta'), mainAxisSize: MainAxisSize.min, children: [
                        PrimaryButton(label: s.signInOrUp, onTap: () => _finish(auth: 'login')),
                        const SizedBox(height: _Ob.m),
                        SizedBox(width: double.infinity, child: _Ghost(label: s.obGuest, onTap: _finish)),
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

/// Pilihan bahasa ID/EN ringkas: segmen terpilih mustard berteks ink.
class _LangToggle extends StatelessWidget {
  const _LangToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(border: Border.all(color: Rave.paper.withValues(alpha: 0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final l in const ['id', 'en'])
            Semantics(
              button: true,
              selected: value == l,
              child: InkWell(
                onTap: () => onChanged(l),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 32),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  color: value == l ? Rave.mustard : Colors.transparent,
                  child: Text(l.toUpperCase(), style: Rave.label(size: 11, color: value == l ? Rave.ink : Rave.paper.withValues(alpha: 0.7))),
                ),
              ),
            ),
        ]),
      );
}

/// Blok teks bawah sebuah slide: menyusut ke isinya, tetapi tidak pernah lebih dari [maxFraction] tinggi slide —
/// teks besar (skala 1,3) di layar pendek menggulir alih-alih overflow; ilustrasi di atasnya yang mengecil.
class _TextBlock extends StatelessWidget {
  const _TextBlock({required this.maxHeight, required this.children});
  final double maxHeight;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
        ),
      );
}

/// Langkah 0: logo · kaset di depan kipas sampul rilis asli · judul · deskripsi · tautan masuk.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.onLogin});
  final VoidCallback onLogin;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final w = MediaQuery.sizeOf(context).width;
    final g = _Ob.gutter(w);
    return LayoutBuilder(builder: (context, c) {
      // Layar pendek (mis. 360×640, atau teks diperbesar): judul & badan lebih ringkas, eyebrow disembunyikan,
      // jarak dirapatkan → kaset & sampul tetap terlihat (mengecil), tidak hilang.
      final compact = c.maxHeight < 520;
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: g),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: _Ob.s),
          Image.asset('assets/brand/rave-logo.webp', height: compact ? 24 : 28, semanticLabel: 'RAVE'),
          Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: compact ? _Ob.s : _Ob.l), child: const WelcomeArt())),
          _TextBlock(maxHeight: c.maxHeight * 0.62, children: [
            if (!compact) ...[
              Eyebrow('DIY · Indie · Live', color: Rave.mustard, size: 11),
              const SizedBox(height: _Ob.s),
            ],
            Text(s.ob1Title.toUpperCase(), style: Rave.poster(compact ? 30 : _Ob.title(w) + 4)),
            SizedBox(height: compact ? _Ob.s : _Ob.m),
            Text(s.ob1Body, style: Rave.body(size: compact ? 14 : 15, color: Rave.paper.withValues(alpha: 0.82), height: 1.42)),
            const SizedBox(height: _Ob.xs),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, Rave.tap), alignment: Alignment.centerLeft),
              onPressed: onLogin,
              child: Text(s.haveAccount, style: Rave.body(weight: FontWeight.w700, color: Rave.mustard)),
            ),
          ]),
        ]),
      );
    });
  }
}

/// Pilih hingga [max] sampul rilis asli dari data beranda (`/v1/catalog/home`): seksi berjenis `releases` (Rilis Baru)
/// lebih dulu, lalu quick picks berjenis rilis. URL kosong & duplikat dibuang.
List<String> welcomeCovers(HomeData d, {int max = 3}) {
  final out = <String>[];
  void add(MediaItem m) {
    final u = m.imageUrl;
    if (out.length < max && m.kind == 'release' && u != null && u.isNotEmpty && !out.contains(u)) out.add(u);
  }

  for (final sec in d.sections) {
    if (sec.kind == 'releases') sec.items.forEach(add);
  }
  d.quickPicks.forEach(add);
  return out;
}

/// Ilustrasi slide 1: tiga sampul rilis asli terkipas di belakang kaset RAVE. Ukuran slot tetap (dihitung dari ruang
/// yang tersedia) → tidak ada lompatan tata letak: sampul cadangan bergaya tampil dulu, sampul asli memudar masuk
/// di atasnya; offline/tanpa sampul → tetap sampul cadangan. Kunci cache sama dengan beranda tamu (prefetch gratis).
class WelcomeArt extends StatefulWidget {
  const WelcomeArt({super.key});

  /// Tinggi / lebar komposisi.
  static const ratio = 0.86;

  /// Kunci [DataCache] = kunci `ApiView` beranda tanpa kota.
  static const cacheKey = '/v1/catalog/home?';

  @override
  State<WelcomeArt> createState() => _WelcomeArtState();
}

class _WelcomeArtState extends State<WelcomeArt> {
  List<String> covers = const [];

  @override
  void initState() {
    super.initState();
    final app = App.read(context);
    final cached = app.cache.peek(WelcomeArt.cacheKey);
    if (cached is HomeData) covers = welcomeCovers(cached);
    if (!app.cache.isFresh(WelcomeArt.cacheKey)) _load(app);
  }

  Future<void> _load(AppState app) async {
    try {
      final v = await app.cache.load(
        WelcomeArt.cacheKey,
        () async => HomeData.fromJson(await app.api.request<Json>('/v1/catalog/home', auth: false, timeout: const Duration(seconds: 8))),
      );
      if (!mounted || v is! HomeData) return;
      final next = welcomeCovers(v);
      if (next.isNotEmpty) setState(() => covers = next);
    } catch (_) {
      // Offline / server lama: sampul cadangan tetap tampil.
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = min(c.maxWidth, min(c.maxHeight / WelcomeArt.ratio, 380.0));
      if (!w.isFinite || w < 96) return const SizedBox.shrink(); // layar sangat pendek: teks didahulukan
      final h = w * WelcomeArt.ratio;
      final cover = w * 0.44;
      final tape = w * 0.80;
      Widget slot(int k, double left, double top, double angle) => Positioned(
            left: left,
            top: top,
            child: Transform.rotate(angle: angle, child: _CoverSlot(size: cover, index: k, url: k < covers.length ? covers[k] : null)),
          );
      return Center(
        child: RepaintBoundary(
          child: MediaQuery.withNoTextScaling(
            child: SizedBox(
              key: const ValueKey('welcome-art'),
              width: w,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                slot(1, w * 0.04, h * 0.08, -0.13),
                slot(2, w - cover - w * 0.04, h * 0.10, 0.11),
                slot(0, (w - cover) / 2, 0, -0.02),
                Positioned(left: (w - tape) / 2, bottom: w * 0.02, child: Transform.rotate(angle: -0.035, child: Cassette(width: tape))),
              ]),
            ),
          ),
        ),
      );
    });
  }
}

/// Satu slot sampul berukuran tetap: sampul cadangan bergaya RAVE di bawah, sampul asli (bila ada) memudar di atasnya.
class _CoverSlot extends StatelessWidget {
  const _CoverSlot({required this.size, required this.index, this.url});
  final double size;
  final int index;
  final String? url;

  static const _colors = [Rave.mustard, Rave.purpleSoft, Rave.teal];
  static const _titles = ['SENJA', 'NIRMALA', 'DARA'];

  @override
  Widget build(BuildContext context) {
    final src = App.of(context).api.media(url);
    final fg = index == 0 ? Rave.ink : Rave.paper;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _colors[index], border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(5, 5))]),
      child: Stack(fit: StackFit.expand, children: [
        Positioned(left: size * 0.08, top: size * 0.08, right: size * 0.08, child: Text(_titles[index], maxLines: 1, overflow: TextOverflow.clip, style: Rave.poster(size * 0.16, color: fg))),
        Positioned(right: size * 0.07, bottom: size * 0.07, child: Text('RV-0${index + 1}', style: Rave.label(size: max(7, size * 0.065), color: fg))),
        if (src != null)
          CachedNetworkImage(
            key: ValueKey(src),
            imageUrl: src,
            fit: BoxFit.cover,
            memCacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
            fadeInDuration: const Duration(milliseconds: 380),
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
      ]),
    );
  }
}

/// Slide pertanyaan: eyebrow · judul · petunjuk, lalu isi. Ruang cukup → kepala tersemat & isi bergulir; layar
/// pendek / teks besar → semuanya bergulir bersama (tak pernah overflow).
class _Question extends StatelessWidget {
  const _Question({required this.eyebrow, required this.title, required this.hint, required this.child});
  final String eyebrow, title, hint;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final g = _Ob.gutter(w);
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Eyebrow(eyebrow, color: Rave.mustard, size: 11),
      const SizedBox(height: _Ob.s),
      Text(title.toUpperCase(), style: Rave.poster(_Ob.title(w))),
      const SizedBox(height: _Ob.s),
      AnimatedSwitcher(duration: const Duration(milliseconds: 200), child: Text(hint, key: ValueKey(hint), style: Rave.body(size: 14, color: Rave.muted))),
      const SizedBox(height: _Ob.l + _Ob.xs),
    ]);
    return LayoutBuilder(builder: (context, c) {
      if (c.maxHeight < 420) {
        return SingleChildScrollView(padding: EdgeInsets.fromLTRB(g, _Ob.l, g, _Ob.l), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [header, child]));
      }
      return Padding(
        padding: EdgeInsets.fromLTRB(g, _Ob.l, g, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          header,
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.only(bottom: _Ob.l), child: child)),
        ]),
      );
    });
  }
}

/// Chip pilihan bergaya stiker: memantul & miring saat dipilih.
class _Chips extends StatelessWidget {
  const _Chips({required this.options, required this.selected, required this.onTap, this.labels});
  final List<String> options;
  final Set<String> selected;
  final void Function(String) onTap;
  final Map<String, String>? labels;
  @override
  Widget build(BuildContext context) => Wrap(spacing: _Ob.s, runSpacing: _Ob.s + 2, children: [
        for (var i = 0; i < options.length; i++)
          Builder(builder: (_) {
            final o = options[i];
            final on = selected.contains(o);
            return Semantics(
              button: true,
              selected: on,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(o);
                },
                child: AnimatedScale(
                  scale: on ? 1.05 : 1,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutBack,
                  child: AnimatedRotation(
                    turns: on ? (i.isEven ? -0.008 : 0.008) : 0,
                    duration: const Duration(milliseconds: 180),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      constraints: const BoxConstraints(minHeight: 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: on ? Rave.mustard : Colors.white.withValues(alpha: 0.07),
                        border: Border.all(color: on ? Rave.ink : Rave.paper.withValues(alpha: 0.22), width: on ? 2 : 1),
                        boxShadow: on ? Rave.hardShadow : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (on) ...[const Icon(Icons.check_rounded, size: 16, color: Rave.ink), const SizedBox(width: _Ob.xs)],
                        Flexible(child: Text((labels?[o] ?? o).toUpperCase(), style: Rave.label(size: 11.5, color: on ? Rave.ink : Rave.paper))),
                      ]),
                    ),
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
                      if (v == null) return toast(this.context, s.serverUnreachable(p.$1), kind: ToastKind.error);
                      await switchServer(app, p.$2); // memicu muat ulang lewat listener pengaturan
                    },
            ),
        ]),
      ]),
    );
  }
}

/// Genre dari katalog (/v1/catalog/genres), cadangan daftar tetap bila offline. Genre `popular` (taksonomi bersama
/// @rave/domain) + yang sudah dipilih tampil lebih dulu; sisanya di balik "Lihat semua" — sama dengan web.
class _GenreChips extends StatefulWidget {
  const _GenreChips({required this.selected, required this.onTap});
  final Set<String> selected;
  final void Function(String) onTap;
  @override
  State<_GenreChips> createState() => _GenreChipsState();
}

class _GenreChipsState extends State<_GenreChips> {
  bool all = false;
  @override
  Widget build(BuildContext context) => _Remote(
        path: '/v1/catalog/genres',
        offlineFallback: true,
        builder: (_, j) {
          final list = (j?['data'] as List?)?.cast<Json>();
          final ids = list != null && list.isNotEmpty ? list.map((g) => g['id'] as String).toList() : _fallbackGenres;
          final labels = {for (final g in list ?? const <Json>[]) g['id'] as String: (g['name'] ?? g['id']) as String};
          final popular = {for (final g in list ?? const <Json>[]) if (g['popular'] == true) g['id'] as String};
          // Server lama tanpa penanda `popular` → tampilkan semua seperti sebelumnya.
          final canCollapse = popular.isNotEmpty && popular.length < ids.length;
          final shown = all || !canCollapse ? ids : ids.where((id) => popular.contains(id) || widget.selected.contains(id)).toList();
          final s = App.of(context).s;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Chips(options: shown, selected: widget.selected, onTap: widget.onTap, labels: labels),
            if (canCollapse)
              TextButton(
                onPressed: () => setState(() => all = !all),
                child: Text(all ? s.obGenresPopularOnly : s.obGenresShowAll(ids.length),
                    style: Rave.body(size: 13, weight: FontWeight.w700, color: Rave.paper).copyWith(decoration: TextDecoration.underline)),
              ),
          ]);
        },
      );
}

/// Kisi artis; artis bergenre pilihan diurutkan lebih dulu. Jumlah kolom & ukuran foto mengikuti lebar, tinggi sel
/// mengikuti skala teks (nama 2 baris) → tak pernah overflow. Tanda centang mustard saat dipilih.
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
        return LayoutBuilder(builder: (context, c) {
          const gap = _Ob.m;
          final cols = (c.maxWidth / 112).floor().clamp(3, 5);
          final cell = (c.maxWidth - gap * (cols - 1)) / cols;
          final photo = min(cell - 6, 96.0);
          final nameH = MediaQuery.textScalerOf(context).scale(12.5) * 1.25 * 2 + 2;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, mainAxisExtent: photo + _Ob.s + nameH + _Ob.xs, crossAxisSpacing: gap, mainAxisSpacing: _Ob.s),
            itemCount: data.length,
            itemBuilder: (_, i) {
              final a = data[i];
              final on = selected.contains(a.id);
              return Semantics(
                button: true,
                selected: on,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
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
                          decoration: BoxDecoration(border: Border.all(color: on ? Rave.mustard : Rave.ink, width: 3), boxShadow: Rave.hardShadow),
                          child: Cover(a.imageUrl, size: photo - 6),
                        ),
                        if (on)
                          Positioned(
                            right: -2,
                            bottom: 2,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2)),
                              child: const Icon(Icons.check_rounded, size: 16, color: Rave.ink),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: _Ob.s),
                    Text(a.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: Rave.body(size: 12.5, weight: FontWeight.w700, color: on ? Rave.mustard : Rave.paper, height: 1.25)),
                  ]),
                ),
              );
            },
          );
        });
      },
    );
  }
}

/// Langkah terakhir: tiket gig (mengecil di layar pendek) · ringkasan pilihan · dua fitur unggulan.
class _Ready extends StatelessWidget {
  const _Ready({required this.city, required this.genres, required this.artists});
  final String? city;
  final int genres, artists;
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final w = MediaQuery.sizeOf(context).width;
    final g = _Ob.gutter(w);
    Widget feat(IconData i, String t, String b) => Padding(
          padding: const EdgeInsets.only(top: _Ob.l),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.ink, width: 2), boxShadow: Rave.hardShadow),
              child: Icon(i, color: Rave.ink, size: 20),
            ),
            const SizedBox(width: _Ob.l),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: Rave.body(size: 15, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(b, style: Rave.body(size: 13, color: Rave.muted, height: 1.4)),
              ]),
            ),
          ]),
        );
    final text = [
      Text(s.obReadyTitle.toUpperCase(), style: Rave.poster(_Ob.title(w))),
      if (artists >= 3) ...[
        const SizedBox(height: _Ob.s),
        Text(s.obReadySummary(city ?? '-', genres, artists), style: Rave.body(size: 14, color: Rave.mustard, height: 1.35)),
      ],
      const SizedBox(height: _Ob.xs),
      feat(Icons.lyrics_outlined, s.ob2Title, s.ob2Body),
      feat(Icons.favorite_rounded, s.ob3Title, s.ob3Body),
      const SizedBox(height: _Ob.l),
    ];
    return LayoutBuilder(builder: (context, c) {
      // Ruang pendek untuk teks sebesar ini → satu gulungan (tiket kecil di atas, teks di bawah) alih-alih ruang
      // kosong di atas teks yang terpotong.
      if (c.maxHeight < 420 * MediaQuery.textScalerOf(context).scale(1)) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(g, _Ob.m, g, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 140, child: _ArtLive()),
            const SizedBox(height: _Ob.m),
            ...text,
          ]),
        );
      }
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: g),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Padding(padding: EdgeInsets.symmetric(vertical: _Ob.l), child: _ArtLive())),
          _TextBlock(maxHeight: c.maxHeight * 0.7, children: text),
        ]),
      );
    });
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

/// Piringan hitam vintage (tekstur hyperrealistic bersama, label kertas tua dengan warna [label]).
class Vinyl extends StatelessWidget {
  const Vinyl({super.key, required this.size, this.label = Rave.mustard});
  final double size;
  final Color label;
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: Stack(alignment: Alignment.center, children: [
          const Positioned.fill(child: VintageDisc()),
          Container(
            width: size * 0.34,
            height: size * 0.34,
            decoration: BoxDecoration(shape: BoxShape.circle, color: label, boxShadow: const [BoxShadow(color: Color(0xFF0B0908), spreadRadius: 1)]),
            child: ClipOval(
              child: Stack(alignment: Alignment.center, children: [
                const Positioned.fill(child: AgedLabelOverlay()),
                Transform.translate(
                  offset: Offset(0, -size * 0.05),
                  child: Text('RAVE', style: Rave.poster(size * 0.08, color: Rave.ink.withValues(alpha: 0.85))),
                ),
                SpindleHole(size: size * 0.035),
              ]),
            ),
          ),
        ]),
      );
}

/// Langkah terakhir: tiket gig + stiker LIVE (dukung artis: live, tiket, ikuti). Komposisi tetap 300 × 220 yang
/// diperkecil (tak pernah diperbesar) agar muat di ruang yang tersedia; disembunyikan bila ruang terlalu pendek.
class _ArtLive extends StatelessWidget {
  const _ArtLive();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (c.maxHeight < 90 || c.maxWidth < 120) return const SizedBox.shrink();
        return Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: MediaQuery.withNoTextScaling(
              child: SizedBox(
                width: 300,
                height: 220,
                child: Stack(alignment: Alignment.center, children: [
                  Transform.rotate(
                    angle: 0.05,
                    child: Container(
                      width: 264,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Rave.paper, border: Border.all(color: Rave.ink, width: 2), boxShadow: const [BoxShadow(color: Rave.shadow, offset: Offset(6, 6))]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text('ADMIT ONE · RV-TIX', maxLines: 1, overflow: TextOverflow.clip, style: Rave.label(size: 9.5, color: Rave.berry)),
                        const SizedBox(height: 6),
                        // Nama lebih panjang dari lebar tiket di font 34 → mengecil rapi, tidak terpotong.
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text('BRAP COMPILATION', maxLines: 1, style: Rave.poster(34, color: Rave.ink)),
                        ),
                        Text('LIVE DI BANDUNG', maxLines: 1, overflow: TextOverflow.clip, style: Rave.poster(20, color: Rave.purple)),
                        const SizedBox(height: 10),
                        Container(height: 1.5, color: Rave.ink),
                        const SizedBox(height: 8),
                        Row(children: [
                          Text('SAB · 20:00 WIB', style: Rave.label(size: 10, color: Rave.ink)),
                          const Spacer(),
                          const Icon(Icons.qr_code_2_rounded, color: Rave.ink, size: 32),
                        ]),
                      ]),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    left: 6,
                    child: Transform.rotate(
                      angle: -0.16,
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
                ]),
              ),
            ),
          ),
        );
      });
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
