import 'dart:math';

/// Efek audio pemutar — padanan web `lib/audioFx.ts` + `stores/prefs.ts`, tetapi memakai efek bawaan Android
/// (just_audio `AndroidEqualizer` / `AndroidLoudnessEnhancer`). Fungsi di sini murni (mudah diuji).

/// Pita acuan preset (Hz) — sama dengan web: 60 · 150 · 400 · 1K · 2.4K · 15K.
const eqRefBands = <double>[60, 150, 400, 1000, 2400, 15000];

/// Preset equalizer pada pita acuan (dB) — sama dengan web `EQ_PRESETS`.
const eqPresets = <String, List<double>>{
  'flat': [0, 0, 0, 0, 0, 0],
  'bass': [6, 4, 1, 0, 0, 0],
  'vocal': [-2, -1, 2, 4, 3, 1],
  'acoustic': [3, 2, 1, 1, 2, 2],
  'electronic': [5, 3, 0, -1, 2, 4],
  'treble': [0, 0, 0, 1, 4, 6],
};

/// Petakan kurva preset (pada [eqRefBands]) ke pita perangkat: interpolasi linear pada skala log-frekuensi,
/// di luar rentang acuan memakai nilai tepi; hasil dibatasi ke rentang gain perangkat.
List<double> mapCurve(List<double> curve, List<double> centersHz, double minDb, double maxDb) {
  double at(double hz) {
    final x = log(max(hz, 1));
    final xs = eqRefBands.map(log).toList();
    if (x <= xs.first) return curve.first;
    if (x >= xs.last) return curve.last;
    for (var i = 0; i < xs.length - 1; i++) {
      if (x <= xs[i + 1]) {
        final t = (x - xs[i]) / (xs[i + 1] - xs[i]);
        return curve[i] + (curve[i + 1] - curve[i]) * t;
      }
    }
    return curve.last;
  }

  return [for (final hz in centersHz) (((at(hz) * 2).round() / 2).clamp(minDb, maxDb)).toDouble()];
}

/// Koreksi loudness dari server, dibatasi −12…+6 dB (sama dengan web). Tidak ada data → 0.
double normalizeGain(double? db) => db == null || !db.isFinite ? 0 : db.clamp(-12.0, 6.0).toDouble();

/// Volume pemutar untuk gain negatif (dB → linear); gain positif tidak menaikkan volume (≤ 1.0).
double volumeForGain(double db) => db >= 0 ? 1.0 : pow(10, db / 20).toDouble();

/// Galat pemutar yang berasal dari pembuatan efek audio Android (Equalizer/LoudnessEnhancer) —
/// dipakai untuk memutuskan memasang ulang pemutar tanpa efek (pemutaran tidak boleh rusak karena EQ).
bool looksLikeFxError(Object e) {
  final t = e.toString().toLowerCase();
  return t.contains('effect') || t.contains('equalizer') || t.contains('loudness') || t.contains('audiofx');
}

/// Label frekuensi ringkas: 60 → "60", 1000 → "1K", 2400 → "2.4K", 15000 → "15K".
String fmtHz(double hz) {
  if (hz < 1000) return '${hz.round()}';
  final k = hz / 1000;
  return '${k >= 10 || k == k.roundToDouble() ? k.round() : k.toStringAsFixed(1)}K';
}
