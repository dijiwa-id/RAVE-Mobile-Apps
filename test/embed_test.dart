import 'package:flutter_test/flutter_test.dart';
import 'package:rave_mobile/core/models.dart';
import 'package:rave_mobile/widgets/embed_player.dart';

void main() {
  test('episode embed dari API → EpisodeEmbed; unggahan → null', () {
    final e = Episode.fromJson({
      'id': 'e1',
      'show_id': 's1',
      'title': 'Ep 1',
      'source': 'embed',
      'embed': {'provider': 'spotify', 'src': 'https://open.spotify.com/embed/episode/4rOoJ6Egrf8K2IrywzwOMk', 'kind': 'audio', 'height': 152},
    });
    expect(e.isEmbed, isTrue);
    expect(e.embed!.height, 152);
    expect(Episode.fromJson({'id': 'e2', 'title': 'x', 'source': 'upload'}).isEmbed, isFalse);
    // Server lama (tanpa field source) = unggahan.
    expect(Episode.fromJson({'id': 'e3', 'title': 'x'}).isEmbed, isFalse);
  });

  test('embed non-https ditolak di klien', () {
    expect(EpisodeEmbed.fromJson({'provider': 'x', 'src': 'javascript:alert(1)'}), isNull);
    expect(EpisodeEmbed.fromJson({'provider': 'x', 'src': 'http://open.spotify.com/embed/episode/a'}), isNull);
  });

  test('tautan "Buka di …" ke halaman platform asal', () {
    EpisodeEmbed em(String p, String src) => EpisodeEmbed(provider: p, src: src, kind: 'audio', height: 166);
    expect(embedPageUrl(em('youtube', 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ')), 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(embedPageUrl(em('spotify', 'https://open.spotify.com/embed/episode/abc')), 'https://open.spotify.com/episode/abc');
    expect(embedPageUrl(em('apple', 'https://embed.podcasts.apple.com/id/podcast/x/id123?i=1')), 'https://podcasts.apple.com/id/podcast/x/id123?i=1');
    expect(embedPageUrl(em('soundcloud', 'https://w.soundcloud.com/player/?url=https%3A%2F%2Fsoundcloud.com%2Fa%2Fb&visual=false')), 'https://soundcloud.com/a/b');
  });
}
