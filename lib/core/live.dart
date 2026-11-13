import 'dart:math';

import 'models.dart';

/// Model Live Streaming — sama dengan web (apps/web lib/types.ts LiveStream / LiveStreamDetail, docs/API.md §10).
class LiveStream {
  final String id, title, status, access;
  final String? description, coverUrl, scheduledAt, startedAt, endedAt, endedReason;
  final ({String id, String name, String slug, String? imageUrl})? artist;
  final ({String id, String slug, String title, String city, String startsAt})? event;
  final String orgName;
  final int viewers, peakViewers;
  final bool chatEnabled;
  // Hanya di detail:
  final bool canWatch;
  final String? accessReason;

  const LiveStream({
    required this.id,
    required this.title,
    required this.status,
    required this.access,
    required this.orgName,
    this.description,
    this.coverUrl,
    this.scheduledAt,
    this.startedAt,
    this.endedAt,
    this.endedReason,
    this.artist,
    this.event,
    this.viewers = 0,
    this.peakViewers = 0,
    this.chatEnabled = true,
    this.canWatch = true,
    this.accessReason,
  });

  factory LiveStream.fromJson(Json j) {
    final a = j['artist'] as Json?;
    final e = j['event'] as Json?;
    return LiveStream(
      id: j['id'],
      title: j['title'] ?? '',
      status: j['status'] ?? 'SCHEDULED',
      access: j['access'] ?? 'PUBLIC',
      orgName: (j['org'] as Json?)?['name'] ?? '',
      description: j['description'],
      coverUrl: j['cover_url'],
      scheduledAt: j['scheduled_at'],
      startedAt: j['started_at'],
      endedAt: j['ended_at'],
      endedReason: j['ended_reason'],
      artist: a == null ? null : (id: a['id'] as String, name: (a['name'] ?? '') as String, slug: (a['slug'] ?? a['id']) as String, imageUrl: a['image_url'] as String?),
      event: e == null
          ? null
          : (id: e['id'] as String, slug: (e['slug'] ?? e['id']) as String, title: (e['title'] ?? '') as String, city: (e['city'] ?? '') as String, startsAt: (e['starts_at'] ?? '') as String),
      viewers: (j['viewers'] as num?)?.toInt() ?? 0,
      peakViewers: (j['peak_viewers'] as num?)?.toInt() ?? 0,
      chatEnabled: j['chat_enabled'] != false,
      canWatch: j['can_watch'] != false,
      accessReason: j['access_reason'],
    );
  }

  bool get onAir => status == 'LIVE' || status == 'INTERRUPTED';
  bool get interrupted => status == 'INTERRUPTED';
  bool get ended => status == 'ENDED';
  bool get scheduled => status == 'SCHEDULED';
  bool get ticketOnly => access == 'TICKET';
  String? get image => coverUrl ?? artist?.imageUrl;
}

class LiveChatMessage {
  final int id;
  final String userId, name, body;
  const LiveChatMessage(this.id, this.userId, this.name, this.body);
  factory LiveChatMessage.fromJson(Json j) => LiveChatMessage((j['id'] as num).toInt(), j['user_id'] ?? '', j['display_name'] ?? '', j['body'] ?? '');
}

List<LiveStream> liveList(Json j) => [for (final x in (j['data'] as List? ?? const [])) LiveStream.fromJson(x as Json)];

/// UUID penonton anonim per sesi aplikasi (heartbeat jumlah penonton), seperti `rave-live-viewer` di web.
final String liveViewerId = () {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}();

/// "2 hari 03:12:09" / "03:12:09".
String fmtCountdown(Duration d, bool id) {
  if (d.isNegative) d = Duration.zero;
  final days = d.inDays;
  String two(int n) => n.toString().padLeft(2, '0');
  final hms = '${two(d.inHours % 24)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  return days > 0 ? '$days ${id ? 'hari' : (days == 1 ? 'day' : 'days')} $hms' : hms;
}
