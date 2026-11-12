import 'package:url_launcher/url_launcher.dart';

/// Buka tautan http(s) di browser eksternal (bukan di dalam aplikasi).
Future<void> openUrl(String url) async {
  final u = Uri.tryParse(url);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return;
  await launchUrl(u, mode: LaunchMode.externalApplication);
}
