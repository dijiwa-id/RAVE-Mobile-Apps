import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/feedback.dart';
import '../widgets/motion.dart';
import '../widgets/verified_badge.dart';
import 'settings.dart';

/// Kota pilihan (sama dengan web & onboarding).
const profileCities = ['Jakarta', 'Bandung', 'Yogyakarta', 'Surabaya', 'Malang', 'Bali', 'Medan', 'Semarang', 'Makassar', 'Solo', 'Palembang', 'Lainnya'];

/// Buka layar Edit profil (layar penuh seperti sub-layar lain).
void openProfile(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));

/// `2026-11-16T…` → "16 Nov 2026".
String fmtDay(String? iso, bool id) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '—';
  const idM = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
  const enM = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${(id ? idM : enM)[d.month - 1]} ${d.year}';
}

/// Tipe gambar dari byte awal (server hanya menerima JPEG/PNG). Null = format lain (HEIC/WebP/…).
String? imageTypeOf(List<int> b) {
  if (b.length > 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length > 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  return null;
}

/// Edit profil sederhana: foto profil (pilih/unggah/hapus), nama tampilan, kota. Data diri lengkap & verifikasi akun
/// (badge Verified / KYC) dikelola di aplikasi web RAVE — lihat baris Verifikasi akun di Pengaturan.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _displayName = TextEditingController();
  String? _city;
  bool _saving = false, _uploading = false;

  @override
  void initState() {
    super.initState();
    final u = App.read(context).api.user;
    _displayName.text = u?.displayName ?? '';
    _city = u?.city;
  }

  @override
  void dispose() {
    _displayName.dispose();
    super.dispose();
  }

  Future<bool> _run(Future<void> Function() f, void Function(bool) flag) async {
    setState(() => flag(true));
    try {
      await f();
      return true;
    } catch (e) {
      if (mounted) toastError(context, e);
      return false;
    } finally {
      if (mounted) setState(() => flag(false));
    }
  }

  Future<void> _patch(Json body) async {
    final api = App.read(context).api;
    await api.setUser(Me.fromJson(await api.request<Json>('/v1/me', method: 'PATCH', body: body)));
  }

  Future<void> _save() async {
    final s = App.read(context).s;
    final name = _displayName.text.trim();
    final ok = await _run(() => _patch({if (name.isNotEmpty) 'display_name': name, 'city': _city}), (b) => _saving = b);
    if (ok && mounted) showToast(context, s.profileSaved, kind: ToastKind.ok);
  }

  Future<void> _pickAvatar() async {
    final app = App.read(context);
    final s = app.s;
    XFile? f;
    try {
      // Android: Photo Picker sistem (tanpa izin penyimpanan). Diperkecil agar unggahan ringan; ≥ 300 px tetap terjaga.
      f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, maxHeight: 1200, imageQuality: 88, requestFullMetadata: false);
    } catch (_) {
      if (mounted) showToast(context, s.pickFailed, kind: ToastKind.error);
      return;
    }
    if (f == null || !mounted) return;
    final file = f;
    final warnings = <String>[];
    final ok = await _run(() async {
      final bytes = await file.readAsBytes();
      final type = imageTypeOf(bytes);
      if (type == null) throw ApiError(415, s.avatarHint);
      final up = await app.api.uploadImage(bytes, filename: 'avatar.${type == 'image/png' ? 'png' : 'jpg'}', contentType: type);
      warnings.addAll(up.warnings);
      await _patch({'avatar_url': up.url});
    }, (b) => _uploading = b);
    if (!ok || !mounted) return;
    for (final w in warnings) {
      showToast(context, w);
    }
    showToast(context, s.avatarUpdated, kind: ToastKind.ok);
  }

  Future<void> _removeAvatar() => _run(() => _patch({'avatar_url': null}), (b) => _uploading = b);

  @override
  Widget build(BuildContext context) {
    final app = App.of(context);
    final s = app.s;
    return ListenableBuilder(
      listenable: app.api,
      builder: (context, _) {
        final u = app.api.user;
        final cities = [...profileCities, if (_city != null && _city!.isNotEmpty && !profileCities.contains(_city)) _city!];
        return Scaffold(
          appBar: AppBar(title: Text(s.editProfile.toUpperCase(), style: Rave.poster(26))),
          body: ListView(physics: raveVerticalPhysics, padding: const EdgeInsets.fromLTRB(16, 4, 16, 40), children: [
            SettingsSection(title: s.profileSection, icon: Icons.person_rounded, rows: [
              SettingsRow(
                label: s.avatarLabel,
                desc: s.avatarHint,
                leading: ProfileAvatar(user: u, size: 80),
                below: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlineButton(label: _uploading ? s.uploading : s.uploadPhoto, onTap: _uploading ? null : _pickAvatar),
                  if (u?.avatarUrl != null) OutlineButton(label: s.removeLabel, onTap: _uploading ? null : _removeAvatar),
                ]),
              ),
              SettingsRow(
                label: s.displayNameLabel,
                below: TextField(
                  key: const ValueKey('display-name'),
                  controller: _displayName,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  style: Rave.body(size: 15),
                  decoration: const InputDecoration(isDense: true, counterText: ''),
                ),
              ),
              SettingsRow(
                label: s.cityLabel,
                below: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in cities) RaveChip(label: c, selected: _city == c, onTap: () => setState(() => _city = c)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            PrimaryButton(key: const ValueKey('save-profile'), label: s.saveData, busy: _saving, onTap: _save),
          ]),
        );
      },
    );
  }
}

/// Foto profil bulat bertepi ink + bayangan sablon; tanpa foto → inisial mustard di ungu. Badge Verified di sudut
/// kanan bawah hanya bila akun terverifikasi (`verified`).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.user, this.size = 80});
  final Me? user;
  final double size;
  @override
  Widget build(BuildContext context) {
    final u = user;
    final name = u?.displayName.trim() ?? '';
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();
    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Rave.purple, border: Border.all(color: Rave.ink, width: 2), boxShadow: context.rc.hard()),
          child: ClipOval(
            child: u?.avatarUrl == null ? Center(child: Text(initial, style: Rave.poster(size * 0.42, color: Rave.mustard))) : Cover(u!.avatarUrl, size: size, round: true),
          ),
        ),
        if (u?.verified ?? false) Positioned(right: 0, bottom: 0, child: VerifiedBadge(size: size * 0.32)),
      ]),
    );
  }
}
