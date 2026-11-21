import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/api.dart';
import 'package:rave_mobile/core/app_state.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/core/settings.dart';
import 'package:rave_mobile/core/theme.dart';
import 'package:rave_mobile/player/player.dart';
import 'package:rave_mobile/screens/profile.dart';
import 'package:rave_mobile/screens/settings.dart';
import 'package:rave_mobile/widgets/motion.dart';
import 'package:rave_mobile/widgets/verified_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Badge Verified, baris status verifikasi di Pengaturan (pengajuan di web) & layar Edit profil — tanpa jaringan.
ThemeData _theme = Rave.dark;

Future<AppState> _state([String locale = 'id']) async {
  SharedPreferences.setMockInitialValues({'locale': locale});
  final settings = await Settings.load();
  final api = Api(settings);
  return AppState(settings, api, Player(api, settings), Likes(api));
}

Future<void> _pump(WidgetTester t, AppState app, Widget child, {double width = 360, double height = 800}) async {
  t.view.physicalSize = Size(width * 3, height * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(App(state: app, child: MaterialApp(theme: _theme, home: Scaffold(body: child))));
  await t.pump(const Duration(milliseconds: 500));
}

Me _me(String status, {bool verified = false, String name = 'Fan Rave Dengan Nama Yang Cukup Panjang'}) => Me(
      id: 'u-$status',
      email: 'fan@rave.test',
      displayName: name,
      city: 'Bandung',
      verified: verified,
      verifiedAt: verified ? '2026-11-10T08:00:00Z' : null,
      verificationStatus: status,
    );

void main() {
  group('model', () {
    test('Me: profil tersimpan versi lama tetap terbaca (kolom baru = bawaan)', () {
      final m = Me.fromJson({'id': 'x', 'email': 'a@b.c', 'display_name': 'A', 'premium': true});
      expect(m.verified, isFalse);
      expect(m.verificationStatus, 'NONE');
      expect(m.socials, isEmpty);
      expect(m.idNumberMasked, isNull);
      expect(m.premium, isTrue);
    });

    test('Me: toJson ↔ fromJson pulang-pergi + withTheme menjaga data verifikasi', () {
      final src = Me.fromJson({
        'id': 'q',
        'email': 'qa@rave.test',
        'display_name': 'QA',
        'phone': '+6281234567890',
        'full_name': 'Quality Assurance',
        'birth_date': '1995-04-12',
        'gender': 'female',
        'bio': 'Pendengar setia.',
        'socials': ['https://instagram.com/qa'],
        'id_number_masked': '************3456',
        'verified': true,
        'verified_at': '2026-11-10T08:00:00Z',
        'verification_status': 'VERIFIED',
      });
      final m = Me.fromJson(src.toJson());
      expect(m.verified, isTrue);
      expect(m.verificationStatus, 'VERIFIED');
      expect(m.idNumberMasked, '************3456');
      expect(m.socials, ['https://instagram.com/qa']);
      expect(m.birthDate, '1995-04-12');
      final t = m.withTheme('light');
      expect(t.theme, 'light');
      expect(t.verified, isTrue);
      expect(t.fullName, 'Quality Assurance');
    });

    test('Me: verification_status tanpa badge (KYC lama) dipertahankan', () {
      final m = Me.fromJson({'id': 'k', 'email': 'k@r.t', 'display_name': 'K', 'verified': false, 'verification_status': 'VERIFIED'});
      expect(m.verified, isFalse);
      expect(m.verificationStatus, 'VERIFIED');
    });

    test('imageTypeOf: hanya JPEG/PNG', () {
      expect(imageTypeOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]), 'image/png');
      expect(imageTypeOf([0xFF, 0xD8, 0xFF, 0xE0]), 'image/jpeg');
      expect(imageTypeOf([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57]), isNull);
    });

    test('geometri badge: bintang 24 titik r 11 di sekitar (12,12)', () {
      final b = VerifiedBadgePainter.burst.getBounds();
      expect(b.top, closeTo(1, 0.01));
      expect(b.bottom, closeTo(23, 0.1));
      expect(b.center.dx, closeTo(12, 0.01));
    });
  });

  for (final mode in ['gelap', 'terang']) {
    group('tema $mode', () {
      setUp(() {
        _theme = mode == 'terang' ? Rave.light : Rave.dark;
        RaveMotion.infinite = false;
        Entrance.reset();
      });
      _suite();
    });
  }
}

void _suite() {
  testWidgets('VerifiedBadge 12–64 px + cap VERIFIED + nama panjang', (t) async {
    final app = await _state();
    await _pump(
      t,
      app,
      const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, children: [VerifiedBadge(size: 12), VerifiedBadge(size: 16), VerifiedBadge(size: 28), VerifiedBadge(size: 44, dim: true), VerifiedBadge(size: 64)]),
          SizedBox(height: 16),
          VerifiedStamp(),
          SizedBox(height: 16),
          SizedBox(width: 160, child: NameWithBadge('Nama yang sangat panjang sekali untuk kolom ini', verified: true)),
        ]),
      ),
    );
    expect(find.byType(VerifiedBadge), findsNWidgets(7));
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.bySemanticsLabel('Akun terverifikasi'), findsWidgets);
    expect(t.takeException(), isNull);
  });

  for (final w in [360.0, 412.0]) {
    testWidgets('Pengaturan: terverifikasi — badge di kartu profil & baris verifikasi (${w.round()} dp)', (t) async {
      final app = await _state();
      app.api.user = _me('VERIFIED', verified: true, name: 'QA Rave');
      await _pump(t, app, const SettingsScreen(), width: w, height: 1400);
      expect(find.text('QA Rave'), findsOneWidget);
      expect(find.text('Edit profil'), findsOneWidget);
      expect(find.text('Verifikasi akun'), findsOneWidget);
      expect(find.text('Terverifikasi sejak 10 Nov 2026'), findsOneWidget);
      // Avatar, samping nama (kartu profil) & ikon baris verifikasi (tidak pudar).
      final badges = t.widgetList<VerifiedBadge>(find.byType(VerifiedBadge)).toList();
      expect(badges, hasLength(3));
      expect(badges.every((b) => !b.dim), isTrue);
      expect(find.descendant(of: find.byKey(const ValueKey('verify-row')), matching: find.byIcon(Icons.open_in_new_rounded)), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Pengaturan: belum terverifikasi — teks KYC, ikon pudar, tanpa badge nama (${w.round()} dp)', (t) async {
      final app = await _state();
      app.api.user = _me('NONE');
      await _pump(t, app, const SettingsScreen(), width: w, height: 1400);
      expect(find.textContaining('memverifikasi identitasmu (KYC)'), findsOneWidget);
      final badges = t.widgetList<VerifiedBadge>(find.byType(VerifiedBadge)).toList();
      expect(badges, hasLength(1));
      expect(badges.single.dim, isTrue);
      expect(t.takeException(), isNull);
    });

    testWidgets('Pengaturan: KYC lama (VERIFIED tanpa badge), PENDING, REJECTED (${w.round()} dp)', (t) async {
      final app = await _state();
      app.api.user = _me('VERIFIED');
      await _pump(t, app, const SettingsScreen(), width: w, height: 1400);
      expect(find.text('Identitas terverifikasi — lengkapi data diri di web untuk menampilkan badge'), findsOneWidget);
      app.api.user = _me('PENDING');
      await _pump(t, app, const SettingsScreen(key: ValueKey('p')), width: w, height: 1400);
      expect(find.text('Pengajuan sedang ditinjau'), findsOneWidget);
      app.api.user = _me('REJECTED');
      await _pump(t, app, const SettingsScreen(key: ValueKey('r')), width: w, height: 1400);
      expect(find.text('Pengajuan belum disetujui'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Settings (EN): verification row (${w.round()} dp)', (t) async {
      final app = await _state('en');
      app.api.user = _me('VERIFIED', verified: true);
      await _pump(t, app, const SettingsScreen(), width: w, height: 1400);
      expect(find.text('Account verification'), findsOneWidget);
      expect(find.text('Verified since 10 Nov 2026'), findsOneWidget);
      expect(find.text('Account & security'.toUpperCase()), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('Edit profil: foto + badge, nama, kota, simpan (${w.round()} dp)', (t) async {
      final app = await _state();
      app.api.user = _me('VERIFIED', verified: true);
      await _pump(t, app, const SettingsScreen(), width: w);
      await t.tap(find.text('Edit profil'));
      await t.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('EDIT PROFIL'), findsOneWidget);
      expect(find.text('UNGGAH FOTO'), findsOneWidget);
      expect(find.text('HAPUS'), findsNothing);
      expect(find.text('F'), findsOneWidget); // inisial tanpa foto
      expect(find.descendant(of: find.byType(ProfileAvatar), matching: find.byType(VerifiedBadge)), findsOneWidget);
      expect(t.widget<TextField>(find.byKey(const ValueKey('display-name'))).controller!.text, startsWith('Fan Rave'));
      final scroll = find.descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable)).first;
      await t.scrollUntilVisible(find.text('Jakarta'), 200, scrollable: scroll);
      await t.tap(find.text('Jakarta'));
      await t.pump();
      await t.scrollUntilVisible(find.byKey(const ValueKey('save-profile')), 200, scrollable: scroll);
      expect(find.text('SIMPAN'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }
}
