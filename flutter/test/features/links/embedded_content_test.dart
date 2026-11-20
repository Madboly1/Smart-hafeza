import 'package:bouga/features/links/data/embedded_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes supported YouTube video URL forms', () {
    for (final url in [
      'https://youtu.be/abcdefghijk',
      'https://www.youtube.com/watch?v=abcdefghijk',
      'https://youtube.com/shorts/abcdefghijk',
      'https://m.youtube.com/live/abcdefghijk'
    ]) {
      expect(EmbeddedContent.fromUrl(url)?.uri.path, '/embed/abcdefghijk');
    }
  });
  test('only canonical Facebook video and post URLs use official plugins', () {
    expect(
        EmbeddedContent.fromUrl('https://facebook.com/example/videos/123')
            ?.uri
            .path,
        '/plugins/video.php');
    expect(
        EmbeddedContent.fromUrl('https://www.facebook.com/example/posts/123')
            ?.uri
            .path,
        '/plugins/post.php');
    expect(EmbeddedContent.fromUrl('https://facebook.com/share/abc'), isNull);
  });
  test('rejects malicious lookalike hosts, userinfo and invalid IDs', () {
    for (final url in [
      'https://youtube.com.evil.test/watch?v=abcdefghijk',
      'javascript:alert(1)',
      'https://user@youtube.com/watch?v=abcdefghijk',
      'https://youtu.be/invalid',
      'https://facebook.com.evil.test/example/posts/1'
    ]) {
      expect(EmbeddedContent.fromUrl(url), isNull, reason: url);
    }
  });
}
