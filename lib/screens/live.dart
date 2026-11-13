import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/live.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/links.dart';
import 'browse.dart';
import 'login.dart';
import 'routes.dart';

// Live Streaming — setara apps/web pages/fan/Live.tsx & LiveWatch.tsx (docs/API.md §10):
// daftar live/akan datang/selesai, pemutar HLS bertoken (diperbarui sebelum kedaluwarsa), heartbeat penonton, chat polling.

String _two(int n) => n.toString().padLeft(2, '0');
String fmtDateTime(String? iso, bool id) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  const idM = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  const enM = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${(id ? idM : enM)[d.month - 1]} ${d.year}, ${_two(d.hour)}:${_two(d.minute)}';
}

/// Pemuat yang dipoll berkala (daftar stream). Galat sesaat tidak menghapus data yang sudah tampil.
class _Polled<T> extends StatefulWidget {
  const _Polled({required this.load, required this.every, required this.builder});
  final Future<T> Function(AppState app) load;
  final Duration every;
  final Widget Function(BuildContext, T? data, Object? error, Future<void> Function() reload) builder;
  @override
  State<_Polled<T>> createState() => _PolledState<T>();
}

class _PolledState<T> extends State<_Polled<T>> {
  T? data;
  Object? error;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(widget.every, (_) {
      // Tab/halaman tak terlihat (TickerMode mati di IndexedStack/route di bawah) → lewati polling.
      if (mounted && TickerMode.valuesOf(context).enabled) _load();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final v = await widget.load(App.read(context));
      if (mounted) setState(() => (data = v, error = null));
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, data, error, _load);
}

Future<List<LiveStream>> _streams(AppState app, String status, int limit) async =>
    liveList(await app.api.request<Json>('/v1/live/streams', query: {'status': status, 'limit': '$limit'}, auth: false));

/// Pill merah "LIVE" (+ jumlah penonton).
class LivePill extends StatelessWidget {
  const LivePill({super.key, this.viewers, this.interrupted = false});
  final int? viewers;
  final bool interrupted;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        color: interrupted ? const Color(0xFFD97706) : const Color(0xFFDC2626),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.circle, size: 7, color: Colors.white),
          const SizedBox(width: 5),
          Text((interrupted ? app.s.liveInterrupted : 'LIVE').toUpperCase(), style: Rave.label(size: 10.5, color: Colors.white)),
        ]),
      ),
      if (viewers != null)
        Container(
          color: const Color(0x99000000),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.visibility_rounded, size: 11, color: Colors.white),
            const SizedBox(width: 4),
            Text(fmtCompact(viewers!, app.settings.locale), style: Rave.label(size: 10.5, color: Colors.white)),
          ]),
        ),
    ]);
  }
}

/// Hitung mundur yang berdetak tiap detik.
class Countdown extends StatefulWidget {
  const Countdown({super.key, required this.until, this.style});
  final String until;
  final TextStyle? style;
  @override
  State<Countdown> createState() => _CountdownState();
}

class _CountdownState extends State<Countdown> {
  Timer? _t;
  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    final at = DateTime.tryParse(widget.until);
    final left = at == null ? Duration.zero : at.difference(DateTime.now());
    return Text(left > Duration.zero ? fmtCountdown(left, s.id) : s.liveStartingSoon, style: widget.style ?? Rave.label(size: 12, color: Rave.mustard));
  }
}

/// Kartu stream 16:9 (daftar & rak beranda).
class LiveCard extends StatelessWidget {
  const LiveCard({super.key, required this.s, this.width});
  final LiveStream s;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = app.s;
    final card = InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LiveWatchScreen(id: s.id))),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Opacity(opacity: s.ended ? 0.55 : 1, child: Cover(s.image)),
              Positioned(
                top: 6,
                left: 6,
                child: s.onAir
                    ? LivePill(viewers: s.viewers, interrupted: s.interrupted)
                    : _Tag(s.scheduled ? (s.scheduledAt != null ? fmtDateTime(s.scheduledAt, t.id) : t.liveSoon) : t.liveAired, icon: s.scheduled ? Icons.event_rounded : null),
              ),
              if (s.ticketOnly) Positioned(top: 6, right: 6, child: _Tag(t.liveTicket.toUpperCase(), color: const Color(0xFFC0405A))),
            ]),
          ),
          const SizedBox(height: 8),
          Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Row(children: [
            Flexible(child: Text(s.artist?.name ?? s.orgName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Rave.body(size: 12.5, color: Rave.muted))),
            if (s.scheduled && s.scheduledAt != null) ...[
              Text(' · ', style: Rave.body(size: 12.5, color: Rave.muted)),
              Countdown(until: s.scheduledAt!, style: Rave.body(size: 12, weight: FontWeight.w700, color: Rave.mustard)),
            ],
          ]),
        ]),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {this.icon, this.color = const Color(0xB3000000)});
  final String text;
  final IconData? icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 11, color: Colors.white), const SizedBox(width: 4)],
          Text(text, style: Rave.label(size: 10.5, color: Colors.white)),
        ]),
      );
}

/// Rak "Sedang live" di beranda — muncul hanya bila ada siaran (poll 60 dtk), seperti beranda web.
class LiveNowShelf extends StatefulWidget {
  const LiveNowShelf({super.key});
  @override
  State<LiveNowShelf> createState() => _LiveNowShelfState();
}

class _LiveNowShelfState extends State<LiveNowShelf> {
  bool enabled = false;
  @override
  void initState() {
    super.initState();
    platformFlag(App.read(context), 'modules.live').then((v) => mounted ? setState(() => enabled = v) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final s = App.of(context).s;
    return _Polled<List<LiveStream>>(
      every: const Duration(seconds: 60),
      load: (app) => _streams(app, 'live', 8),
      builder: (context, list, _, _) => list == null || list.isEmpty
          ? const SizedBox.shrink()
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SectionTitle(
                s.liveNow,
                action: TextButton(
                  onPressed: () => openHref(context, '/app/live'),
                  child: Text(s.showAll.toUpperCase(), style: Rave.label(size: 11, color: Rave.muted)),
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                  for (final x in list.take(6)) LiveCard(s: x, width: 260),
                ]),
              ),
            ]),
    );
  }
}

/// /app/live — sedang live (hero = paling ramai), akan datang, dan siaran sebelumnya.
class LiveScreen extends StatelessWidget {
  const LiveScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Rave.canvas,
        title: Row(children: [const Icon(Icons.sensors_rounded, color: Color(0xFFEF4444)), const SizedBox(width: 8), Text('LIVE', style: Rave.poster(28))]),
      ),
      body: FutureBuilder<bool>(
        future: platformFlag(app, 'modules.live'),
        builder: (context, on) {
          if (on.data == false) return ListView(children: [EmptyState(s.liveUnavailable)]);
          return _Polled<List<LiveStream>>(
            every: const Duration(seconds: 20),
            load: (app) => _streams(app, 'live', 24),
            builder: (context, live, err, reload) {
              if (live == null && err != null) return ErrorState(message: err is OfflineError ? s.offline : err.toString(), retry: reload);
              if (live == null) return const Center(child: CircularProgressIndicator(color: Rave.mustard, strokeWidth: 2.5));
              final top = live.isEmpty ? null : live.first;
              return RefreshIndicator(
                color: Rave.mustard,
                backgroundColor: Rave.raised,
                onRefresh: reload,
                child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                  if (top != null) _Hero(s: top) else _NobodyLive(),
                  if (live.length > 1) _Grid(title: s.liveNow, items: live.skip(1).toList()),
                  _Section(status: 'upcoming', title: s.liveUpcoming, limit: 12, every: const Duration(seconds: 60), empty: s.liveNoScheduled),
                  _Section(status: 'ended', title: s.livePast, limit: 8, every: const Duration(seconds: 120)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

class _NobodyLive extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = App.of(context).s;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(24),
      color: const Color(0x0DFFFFFF),
      child: Column(children: [
        const Icon(Icons.sensors_off_rounded, size: 36, color: Rave.subtle),
        const SizedBox(height: 10),
        Text(s.liveNobody, style: Rave.body(weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(s.liveNobodyBody, textAlign: TextAlign.center, style: Rave.body(size: 13, color: Rave.muted)),
      ]),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.s});
  final LiveStream s;
  @override
  Widget build(BuildContext context) {
    final t = App.of(context).s;
    void open() => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LiveWatchScreen(id: s.id)));
    return InkWell(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Cover(s.image),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA000000)]))),
              Positioned(top: 8, left: 8, child: LivePill(viewers: s.viewers, interrupted: s.interrupted)),
              const Center(child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Color(0xE6FFFFFF))),
            ]),
          ),
          const SizedBox(height: 12),
          Eyebrow(t.liveNowEyebrow, color: const Color(0xFFF87171)),
          const SizedBox(height: 4),
          Text(s.title, style: Rave.body(size: 21, weight: FontWeight.w800, height: 1.15)),
          if (s.artist != null) ...[
            const SizedBox(height: 4),
            GestureDetector(onTap: () => openItem(context, 'artist', s.artist!.slug), child: Text(s.artist!.name, style: Rave.body(weight: FontWeight.w700, color: Rave.muted))),
          ],
          if (s.description != null) ...[
            const SizedBox(height: 6),
            Text(s.description!, maxLines: 3, overflow: TextOverflow.ellipsis, style: Rave.body(size: 13, color: Rave.muted)),
          ],
        ]),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.title, required this.items, this.empty});
  final String title;
  final List<LiveStream> items;
  final String? empty;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title),
        if (items.isEmpty && empty != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(empty!, style: Rave.body(size: 13, color: Rave.muted)))
        else
          LayoutBuilder(builder: (context, c) {
            final cols = c.maxWidth >= 600 ? 2 : 1;
            final w = (c.maxWidth - 20) / cols;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Wrap(children: [for (final x in items) LiveCard(s: x, width: w)]),
            );
          }),
      ]);
}

class _Section extends StatelessWidget {
  const _Section({required this.status, required this.title, required this.limit, required this.every, this.empty});
  final String status, title;
  final int limit;
  final Duration every;
  final String? empty;
  @override
  Widget build(BuildContext context) => _Polled<List<LiveStream>>(
        every: every,
        load: (app) => _streams(app, status, limit),
        builder: (context, list, _, _) {
          if (list == null || (list.isEmpty && empty == null)) return const SizedBox.shrink();
          return _Grid(title: title, items: list, empty: empty);
        },
      );
}

/// /app/live/:id — pemutar + info + chat. Detail dipoll 10 dtk; begitu LIVE, pemutar muncul otomatis.
class LiveWatchScreen extends StatelessWidget {
  const LiveWatchScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = app.s;
    return Scaffold(
      appBar: AppBar(backgroundColor: Rave.canvas, title: Text('LIVE', style: Rave.poster(26))),
      body: _Polled<LiveStream>(
        every: const Duration(seconds: 10),
        load: (app) async => LiveStream.fromJson(await app.api.get('/v1/live/streams/$id')),
        builder: (context, s, err, reload) {
          // Galat polling sesaat tidak boleh membongkar pemutar yang sedang berjalan.
          if (s == null && err != null) {
            final notFound = err is ApiError && err.status == 404;
            return ErrorState(message: notFound ? t.liveNotFound : (err is OfflineError ? t.offline : err.toString()), retry: reload);
          }
          if (s == null) return const Center(child: CircularProgressIndicator(color: Rave.mustard, strokeWidth: 2.5));
          final showChat = s.chatEnabled && s.canWatch;
          return LayoutBuilder(builder: (context, c) {
            final info = _Info(s: s);
            final stage = _Stage(s: s);
            if (c.maxWidth >= 840) {
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: ListView(padding: const EdgeInsets.all(16), children: [stage, info])),
                if (showChat) SizedBox(width: 340, child: _Chat(streamId: s.id, ended: s.ended)),
              ]);
            }
            return Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(0, 0, 0, 0), child: stage),
              Expanded(
                child: showChat
                    ? DefaultTabController(
                        length: 2,
                        child: Column(children: [
                          TabBar(
                            indicatorColor: Rave.mustard,
                            labelStyle: Rave.label(size: 12, color: Rave.paper),
                            unselectedLabelStyle: Rave.label(size: 12, color: Rave.subtle),
                            tabs: [Tab(text: t.liveChat.toUpperCase()), const Tab(text: 'INFO')],
                          ),
                          Expanded(child: TabBarView(children: [_Chat(streamId: s.id, ended: s.ended), ListView(children: [info])])),
                        ]),
                      )
                    : ListView(children: [info]),
              ),
            ]);
          });
        },
      ),
    );
  }
}

/// Panggung: pemutar atau kartu pengganti (login / tiket / belum mulai / selesai) — sama dengan Gate di web.
class _Stage extends StatelessWidget {
  const _Stage({required this.s});
  final LiveStream s;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = app.s;
    Widget gate(List<Widget> children) => AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(fit: StackFit.expand, children: [
            Opacity(opacity: 0.3, child: Cover(s.image)),
            const ColoredBox(color: Color(0x88000000)),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final w in children) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: w),
                ]),
              ),
            ),
          ]),
        );
    final center = TextAlign.center;
    if (s.ended) {
      return gate([
        Eyebrow(t.liveEnded, color: Rave.muted),
        Text(s.title, textAlign: center, style: Rave.body(size: 18, weight: FontWeight.w800)),
        Text('${s.endedAt != null ? '${fmtDateTime(s.endedAt, t.id)} · ' : ''}${t.livePeak(fmtCompact(s.peakViewers, app.settings.locale))}', textAlign: center, style: Rave.body(size: 12.5, color: Rave.muted)),
        OutlineButton(label: t.liveSeeOther, onTap: () => Navigator.of(context).pop()),
      ]);
    }
    if (!s.canWatch && s.accessReason == 'login_required') {
      return gate([
        const Icon(Icons.lock_rounded, size: 30),
        Text(t.liveSignInToWatch, style: Rave.body(size: 17, weight: FontWeight.w800)),
        Text(t.liveRequiresAccount, textAlign: center, style: Rave.body(size: 12.5, color: Rave.muted)),
        SizedBox(width: 220, child: PrimaryButton(label: t.signIn, onTap: () => openLogin(context))),
      ]);
    }
    if (!s.canWatch && s.accessReason == 'ticket_required') {
      return gate([
        const Icon(Icons.confirmation_number_rounded, size: 30),
        Text(t.liveTicketHolders, style: Rave.body(size: 17, weight: FontWeight.w800)),
        Text(s.event != null ? t.livePartOfEvent(s.event!.title) : t.liveRequiresTicket, textAlign: center, style: Rave.body(size: 12.5, color: Rave.muted)),
        if (s.event != null) SizedBox(width: 220, child: PrimaryButton(label: t.liveBuyTicket, onTap: () => openUrl('${app.settings.server}/app/events/${Uri.encodeComponent(s.event!.slug)}'))),
      ]);
    }
    if (s.scheduled) {
      return gate([
        const Icon(Icons.event_rounded, size: 30),
        Text(t.liveNotStarted, style: Rave.body(size: 17, weight: FontWeight.w800)),
        if (s.scheduledAt != null) ...[
          Text(t.liveScheduled(fmtDateTime(s.scheduledAt, t.id)), style: Rave.body(size: 12.5, color: Rave.muted)),
          Countdown(until: s.scheduledAt!, style: Rave.poster(30)),
        ] else
          Text(t.liveStartingSoon, style: Rave.body(size: 12.5, color: Rave.muted)),
        Text(t.liveAutoPlay, textAlign: center, style: Rave.body(size: 11.5, color: Rave.subtle)),
      ]);
    }
    return LivePlayer(key: ValueKey(s.id), streamId: s.id, cover: s.image, live: s.onAir);
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.s});
  final LiveStream s;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = app.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (s.onAir) LivePill(viewers: s.viewers, interrupted: s.interrupted),
          s.ticketOnly ? _Tag(t.liveTicketHolders.toUpperCase(), icon: Icons.confirmation_number_rounded, color: const Color(0x55C0405A)) : _Tag(t.liveFree.toUpperCase(), icon: Icons.public_rounded, color: const Color(0x22FFFFFF)),
          if (s.onAir && s.startedAt != null) Text(t.liveStarted(fmtDateTime(s.startedAt, t.id)), style: Rave.body(size: 12, color: Rave.muted)),
        ]),
        const SizedBox(height: 10),
        Text(s.title, style: Rave.body(size: 21, weight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 4),
        Wrap(children: [
          if (s.artist != null)
            GestureDetector(onTap: () => openItem(context, 'artist', s.artist!.slug), child: Text(s.artist!.name, style: Rave.body(size: 13.5, weight: FontWeight.w700))),
          if (s.artist != null) Text(' · ', style: Rave.body(size: 13.5, color: Rave.muted)),
          Text(s.orgName, style: Rave.body(size: 13.5, color: Rave.muted)),
        ]),
        if (s.event != null) ...[
          const SizedBox(height: 10),
          InkWell(
            onTap: () => openUrl('${app.settings.server}/app/events/${Uri.encodeComponent(s.event!.slug)}'),
            child: Container(
              color: const Color(0x0DFFFFFF),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.sensors_rounded, size: 16, color: Color(0xFFE879A6)),
                const SizedBox(width: 8),
                Flexible(child: Text('${s.event!.title} · ${s.event!.city}', style: Rave.body(size: 13, weight: FontWeight.w600))),
              ]),
            ),
          ),
        ],
        if (s.description != null) ...[
          const SizedBox(height: 12),
          Text(s.description!, style: Rave.body(size: 13.5, color: Rave.muted, height: 1.45)),
        ],
      ]),
    );
  }
}

/// Pemutar HLS (ExoPlayer lewat video_player). Token di URL diperbarui 5 menit sebelum kedaluwarsa dengan memasang
/// ulang sumber; 409 = belum live → tunggu & coba lagi; galat jaringan → backoff. Musik RAVE dijeda saat siaran diputar.
class LivePlayer extends StatefulWidget {
  const LivePlayer({super.key, required this.streamId, this.cover, this.live = true});
  final String streamId;
  final String? cover;
  final bool live;
  @override
  State<LivePlayer> createState() => _LivePlayerState();
}

enum _Phase { loading, playing, waiting, reconnecting, failed }

class _LivePlayerState extends State<LivePlayer> with WidgetsBindingObserver {
  VideoPlayerController? _c;
  _Phase phase = _Phase.loading;
  String? failure;
  bool muted = false, controls = true;
  Timer? _refresh, _retry, _beat, _hide;
  int _backoff = 2;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
    _beat = Timer.periodic(const Duration(seconds: 15), (_) => _heartbeat());
    _autoHide();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    for (final t in [_refresh, _retry, _beat, _hide]) {
      t?.cancel();
    }
    _c?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    // Siaran video tidak diputar di latar belakang; kembali → lanjut di posisi langsung (sumber dipasang ulang).
    if (st == AppLifecycleState.paused) _c?.pause();
    if (st == AppLifecycleState.resumed && _c != null && phase == _Phase.playing) _start();
  }

  void _autoHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () => mounted ? setState(() => controls = false) : null);
  }

  Future<void> _heartbeat() async {
    if (phase != _Phase.playing) return;
    try {
      await App.read(context).api.post('/v1/live/streams/${widget.streamId}/heartbeat', {'viewer_id': liveViewerId});
    } catch (_) {}
  }

  void _retryIn(Duration d, _Phase p) {
    if (_disposed) return;
    setState(() => phase = p);
    _retry?.cancel();
    _retry = Timer(d, _start);
  }

  Future<void> _start() async {
    _retry?.cancel();
    final app = App.read(context);
    final t = app.s;
    Json pb;
    try {
      pb = await app.api.post('/v1/live/streams/${widget.streamId}/playback') as Json;
    } on ApiError catch (e) {
      if (_disposed) return;
      if (e.status == 409) return _retryIn(const Duration(seconds: 5), _Phase.waiting);
      if (e.status == 401 || e.status == 403 || e.status == 404) {
        return setState(() => (phase = _Phase.failed, failure = e.status == 404 ? t.liveNotFound : e.message));
      }
      return _backoffRetry();
    } catch (_) {
      return _backoffRetry();
    }
    if (_disposed) return;
    final url = app.api.media(pb['hls_url'] as String?);
    if (url == null) return _backoffRetry();
    final old = _c;
    final c = VideoPlayerController.networkUrl(Uri.parse(url), formatHint: VideoFormat.hls, videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      return _backoffRetry();
    }
    if (_disposed) {
      await c.dispose();
      return;
    }
    c.addListener(() => _onValue(c));
    await c.setVolume(muted ? 0 : 1);
    if (app.player.playing) await app.player.toggle();
    await c.play();
    setState(() {
      _c = c;
      phase = _Phase.playing;
      _backoff = 2;
    });
    await old?.dispose();
    _scheduleRefresh(pb['expires_at'] as String?);
    _heartbeat();
  }

  void _onValue(VideoPlayerController c) {
    if (_disposed || c != _c) return;
    if (c.value.hasError && phase == _Phase.playing) _backoffRetry();
  }

  void _backoffRetry() {
    final d = Duration(seconds: _backoff);
    _backoff = (_backoff * 2).clamp(2, 10);
    _retryIn(d, _c == null ? _Phase.loading : _Phase.reconnecting);
  }

  void _scheduleRefresh(String? expiresAt) {
    _refresh?.cancel();
    final at = expiresAt == null ? null : DateTime.tryParse(expiresAt);
    var ms = at == null ? 25 * 60000 : at.difference(DateTime.now()).inMilliseconds - 5 * 60000;
    if (ms < 30000) ms = 30000;
    _refresh = Timer(Duration(milliseconds: ms), _start);
  }

  @override
  Widget build(BuildContext context) {
    final t = App.of(context).s;
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    final ratio = ready && c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    String? overlay = switch (phase) {
      _Phase.waiting => t.liveWaiting,
      _Phase.reconnecting => t.liveReconnecting,
      _Phase.failed => failure,
      _ => null,
    };
    return GestureDetector(
      onTap: () {
        setState(() => controls = !controls);
        if (controls) _autoHide();
      },
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(fit: StackFit.expand, children: [
            if (ready) Center(child: AspectRatio(aspectRatio: ratio, child: VideoPlayer(c))) else Opacity(opacity: 0.35, child: Cover(widget.cover)),
            if (!ready && phase == _Phase.loading) const Center(child: CircularProgressIndicator(color: Rave.mustard, strokeWidth: 2.5)),
            if (overlay != null)
              Center(
                child: Container(
                  color: const Color(0xAA000000),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Text(overlay, textAlign: TextAlign.center, style: Rave.body(weight: FontWeight.w700)),
                ),
              ),
            if (ready && c.value.isBuffering && overlay == null) const Center(child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2)),
            AnimatedOpacity(
              opacity: controls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xAA000000)])),
                  padding: const EdgeInsets.fromLTRB(10, 16, 4, 4),
                  child: Row(children: [
                    if (widget.live) const LivePill(),
                    const Spacer(),
                    IconButton(
                      tooltip: muted ? 'Unmute' : 'Mute',
                      icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white),
                      onPressed: () {
                        setState(() => muted = !muted);
                        _c?.setVolume(muted ? 0 : 1);
                        _autoHide();
                      },
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Chat polling (`GET .../chat?after=` tiap 2 dtk; jeda saat aplikasi di latar). Tamu bisa membaca, kirim perlu masuk.
class _Chat extends StatefulWidget {
  const _Chat({required this.streamId, required this.ended});
  final String streamId;
  final bool ended;
  @override
  State<_Chat> createState() => _ChatState();
}

class _ChatState extends State<_Chat> {
  final _msgs = <LiveChatMessage>[];
  final _ctl = TextEditingController();
  final _scroll = ScrollController();
  int? _last;
  bool enabled = true, sending = false;
  int slow = 0;
  DateTime? _sentAt;
  Timer? _t;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _poll();
    _t = Timer.periodic(const Duration(seconds: 2), (_) {
      if (TickerMode.valuesOf(context).enabled) _poll();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _ctl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _poll() async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final j = await App.read(context).api.get('/v1/live/streams/${widget.streamId}/chat', query: {'limit': '100', 'after': ?_last?.toString()});
      final list = [for (final x in (j['data'] as List? ?? const [])) LiveChatMessage.fromJson(x as Json)];
      if (!mounted) return;
      final atBottom = !_scroll.hasClients || _scroll.position.pixels >= _scroll.position.maxScrollExtent - 40;
      setState(() {
        for (final m in list) {
          if (!_msgs.any((x) => x.id == m.id)) _msgs.add(m);
        }
        if (_msgs.length > 300) _msgs.removeRange(0, _msgs.length - 300);
        _last = (j['last_id'] as num?)?.toInt() ?? _last;
        enabled = j['chat_enabled'] != false;
        slow = (j['slowmode_s'] as num?)?.toInt() ?? 0;
      });
      if (list.isNotEmpty && atBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } catch (_) {
      // Polling berikutnya mencoba lagi.
    } finally {
      _busy = false;
    }
  }

  Future<void> _send() async {
    final app = App.read(context);
    final body = _ctl.text.trim();
    if (body.isEmpty || sending) return;
    if (slow > 0 && _sentAt != null) {
      final wait = slow - DateTime.now().difference(_sentAt!).inSeconds;
      if (wait > 0) return toast(context, app.s.liveSlowmode(wait));
    }
    setState(() => sending = true);
    try {
      final m = LiveChatMessage.fromJson(await app.api.post('/v1/live/streams/${widget.streamId}/chat', {'body': body}) as Json);
      _sentAt = DateTime.now();
      _ctl.clear();
      if (mounted) setState(() => _msgs.any((x) => x.id == m.id) ? null : _msgs.add(m));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    } catch (e) {
      if (mounted) toast(context, e.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final t = app.s;
    final me = app.api.user?.id;
    return ColoredBox(
      color: Rave.base,
      child: Column(children: [
        Expanded(
          child: _msgs.isEmpty
              ? Center(child: Text(t.liveChatEmpty, style: Rave.body(size: 13, color: Rave.subtle)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  itemCount: _msgs.length,
                  itemBuilder: (_, i) {
                    final m = _msgs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: '${m.name}  ', style: Rave.body(size: 13, weight: FontWeight.w800, color: m.userId == me ? Rave.mustard : const Color(0xFFC4A3D4))),
                        TextSpan(text: m.body, style: Rave.body(size: 13.5)),
                      ])),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
            child: widget.ended || !enabled
                ? SizedBox(height: 40, child: Center(child: Text(widget.ended ? t.liveEnded : t.liveChat, style: Rave.body(size: 13, color: Rave.subtle))))
                : !app.api.authed
                    ? SizedBox(width: double.infinity, child: OutlineButton(label: t.liveChatSignIn, onTap: () => openLogin(context)))
                    : Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _ctl,
                            maxLength: 200,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            style: Rave.body(size: 14),
                            decoration: InputDecoration(hintText: t.liveChatHint, counterText: '', isDense: true, fillColor: Rave.raised, filled: true, border: InputBorder.none),
                          ),
                        ),
                        IconButton(
                          tooltip: t.liveChatHint,
                          onPressed: sending ? null : _send,
                          icon: const Icon(Icons.send_rounded, color: Rave.mustard),
                        ),
                      ]),
          ),
        ),
      ]),
    );
  }
}
