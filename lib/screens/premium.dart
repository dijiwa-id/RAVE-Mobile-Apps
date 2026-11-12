import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'login.dart';

/// Premium: paket & harga dari konfigurasi platform (`subscription.*`, sama dengan halaman web /premium),
/// perbandingan Gratis vs Premium, dan daftar tunggu (Premium dibuka bertahap setelah closed beta).
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    final premium = app.api.user?.premium ?? false;
    return Scaffold(
      body: ApiView<Json>(
        path: '/v1/platform/config',
        parse: (j) => (j['settings'] as Json?) ?? const {},
        builder: (context, cfg, _) {
          int price(String k, int d) => (cfg['subscription.price_${k}_idr'] as num?)?.toInt() ?? d;
          final trial = (cfg['subscription.trial_days'] as num?)?.toInt() ?? 0;
          final plans = [
            (name: s.planIndividual, who: s.planIndividualWho, price: price('individual', 49900), items: [s.allBenefits, s.hqLossless, s.offlineSoon], popular: true),
            (name: s.planStudent, who: s.planStudentWho, price: price('student', 24900), items: [s.allBenefits, s.studentVerify], popular: false),
            (name: s.planDuo, who: s.planDuoWho, price: price('duo', 64900), items: [s.allBenefits, s.twoAccounts], popular: false),
          ];
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 18, 20, 26),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Rave.purple, Rave.plum, Rave.canvas], stops: [0, 0.55, 1])),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Transform.rotate(
                    angle: -0.05,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(color: Rave.mustard, border: Border.all(color: Rave.paper, width: 2), boxShadow: Rave.hardShadow),
                      child: Text('RAVE PREMIUM', style: Rave.label(size: 11, color: Rave.ink)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(s.premiumHero1.toUpperCase(), style: Rave.poster(40)),
                  Text(s.premiumHero2.toUpperCase(), style: Rave.poster(40, color: Rave.mustard)),
                  const SizedBox(height: 12),
                  Text(s.premiumLead(_idr(plans.first.price)), style: Rave.body(size: 15, color: Rave.paper.withValues(alpha: 0.85), height: 1.45)),
                  const SizedBox(height: 18),
                  if (premium)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: Rave.mustard.withValues(alpha: 0.15), border: Border.all(color: Rave.mustard)),
                      child: Row(children: [
                        const Icon(Icons.verified_rounded, color: Rave.mustard),
                        const SizedBox(width: 10),
                        Expanded(child: Text(s.alreadyPremium, style: Rave.body(weight: FontWeight.w700))),
                      ]),
                    )
                  else
                    _NotifyButton(label: s.remindMe),
                  const SizedBox(height: 10),
                  Text(s.premiumNote(trial), style: Rave.label(size: 9.5, color: Rave.paper.withValues(alpha: 0.6))),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: SectionTitle(s.plansTitle)),
            SliverList.builder(
              itemCount: plans.length,
              itemBuilder: (_, i) {
                final pl = plans[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Rave.raised,
                      border: Border.all(color: pl.popular ? Rave.mustard : Rave.line, width: pl.popular ? 2 : 1),
                      boxShadow: pl.popular ? Rave.hardShadow : null,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(pl.name.toUpperCase(), style: Rave.poster(28))),
                        if (pl.popular)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            color: Rave.mustard,
                            child: Text(s.mostPopular.toUpperCase(), style: Rave.label(size: 9, color: Rave.ink)),
                          ),
                      ]),
                      Text(pl.who, style: Rave.body(size: 13, color: Rave.muted)),
                      const SizedBox(height: 10),
                      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('Rp ${_idr(pl.price)}', style: Rave.poster(34, color: Rave.mustard)),
                        Padding(padding: const EdgeInsets.only(bottom: 4, left: 4), child: Text(s.perMonth, style: Rave.body(size: 13, color: Rave.muted))),
                      ]),
                      const SizedBox(height: 10),
                      for (final it in pl.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            const Icon(Icons.check_rounded, size: 18, color: Rave.mustard),
                            const SizedBox(width: 8),
                            Expanded(child: Text(it, style: Rave.body(size: 14))),
                          ]),
                        ),
                    ]),
                  ),
                );
              },
            ),
            SliverToBoxAdapter(child: SectionTitle(s.freeVsPremium)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(), 1: FixedColumnWidth(64), 2: FixedColumnWidth(72)},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(children: [
                      const SizedBox(),
                      Center(child: Eyebrow(s.free.split(' ').first, size: 9.5)),
                      Center(child: Eyebrow('Premium', color: Rave.mustard, size: 9.5)),
                    ]),
                    for (final (f, free) in [
                      (s.cmpOnDemand, true),
                      (s.cmpNormal, true),
                      (s.cmpHq, false),
                      (s.cmpLyrics, true),
                      (s.cmpLive, true),
                      (s.cmpPodcast, false),
                      (s.cmpNoAds, false),
                    ])
                      TableRow(
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Rave.line))),
                        children: [
                          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(f, style: Rave.body(size: 14))),
                          Center(child: Icon(free ? Icons.check_rounded : Icons.remove_rounded, color: free ? Rave.paper : Rave.subtle, size: 20)),
                          const Center(child: Icon(Icons.check_rounded, color: Rave.mustard, size: 22)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
                child: Text(s.offlineSoonNote, style: Rave.body(size: 13, color: Rave.muted)),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

String _idr(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// "Ingatkan saya saat dibuka": daftar tunggu (POST /v1/waitlist, sama dengan web). Tamu diminta daftar dulu.
class _NotifyButton extends StatefulWidget {
  const _NotifyButton({required this.label});
  final String label;
  @override
  State<_NotifyButton> createState() => _NotifyButtonState();
}

class _NotifyButtonState extends State<_NotifyButton> {
  bool busy = false, done = false;
  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    if (done) {
      return Row(children: [
        const Icon(Icons.notifications_active_rounded, color: Rave.mustard),
        const SizedBox(width: 8),
        Expanded(child: Text(s.remindSaved, style: Rave.body(weight: FontWeight.w700))),
      ]);
    }
    return PrimaryButton(
      label: widget.label,
      busy: busy,
      onTap: () async {
        if (!app.api.authed && !await requireLogin(context)) return;
        final u = app.api.user;
        if (u == null) return;
        setState(() => busy = true);
        try {
          await app.api.post('/v1/waitlist', {'email': u.email, 'name': u.displayName, 'segment': 'fan', 'consent_marketing': false});
          if (mounted) setState(() => done = true);
        } catch (e) {
          if (context.mounted) toast(context, e.toString());
        } finally {
          if (mounted) setState(() => busy = false);
        }
      },
    );
  }
}
