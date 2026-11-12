// Versioning RAVE Mobile — SemVer + nomor build (versionCode Android) dari SATU sumber: pubspec.yaml.
//
//   dart run tool/bump_version.dart patch|minor|major|build
//
// - patch/minor/major: naikkan SemVer & build (+1); `build`: hanya nomor build (rilis ulang tanpa perubahan fitur).
// - Menulis lib/core/version.dart (ditampilkan di Pengaturan) dan menambah bagian baru di CHANGELOG.md.
// Setelahnya: isi CHANGELOG, commit "release: vX.Y.Z", tag `mobile-vX.Y.Z`.
import 'dart:io';

void main(List<String> args) {
  final kind = args.isEmpty ? '' : args.first;
  if (!['patch', 'minor', 'major', 'build'].contains(kind)) {
    stderr.writeln('pakai: dart run tool/bump_version.dart patch|minor|major|build');
    exit(64);
  }
  final pub = File('pubspec.yaml');
  final src = pub.readAsStringSync();
  final m = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true).firstMatch(src);
  if (m == null) {
    stderr.writeln('pubspec.yaml: baris "version: X.Y.Z+N" tidak ditemukan');
    exit(65);
  }
  var (ma, mi, pa, b) = (int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!));
  switch (kind) {
    case 'major':
      (ma, mi, pa) = (ma + 1, 0, 0);
    case 'minor':
      (mi, pa) = (mi + 1, 0);
    case 'patch':
      pa++;
  }
  b++;
  final v = '$ma.$mi.$pa';
  pub.writeAsStringSync(src.replaceRange(m.start, m.end, 'version: $v+$b'));
  writeVersionFile(v, b);
  final log = File('CHANGELOG.md');
  if (kind != 'build' && log.existsSync()) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final c = log.readAsStringSync();
    final at = c.indexOf('\n## ');
    final entry = '\n## [$v] - $today\n\n### Ditambahkan\n- \n';
    log.writeAsStringSync(at < 0 ? '$c$entry' : '${c.substring(0, at)}$entry${c.substring(at)}');
  }
  stdout.writeln('RAVE Mobile → $v (build $b). Lengkapi CHANGELOG.md, lalu commit & tag mobile-v$v.');
}

void writeVersionFile(String v, int b) => File('lib/core/version.dart').writeAsStringSync('''// DIBUAT OTOMATIS oleh tool/bump_version.dart — jangan ubah manual. Sumber: pubspec.yaml.
const appVersion = '$v';
const appBuild = $b;
const appVersionLabel = '$v ($b)';
''');
