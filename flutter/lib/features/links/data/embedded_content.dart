class EmbeddedContent {
  const EmbeddedContent(this.uri, this.platform);
  final Uri uri;
  final String platform;

  static EmbeddedContent? fromUrl(String value) {
    final source = Uri.tryParse(value.trim());
    if (source == null ||
        !['http', 'https'].contains(source.scheme) ||
        source.userInfo.isNotEmpty) {
      return null;
    }
    final host = source.host.toLowerCase();
    String? id;
    if (host == 'youtu.be') id = source.pathSegments.firstOrNull;
    if (['youtube.com', 'www.youtube.com', 'm.youtube.com'].contains(host)) {
      if (source.path == '/watch') id = source.queryParameters['v'];
      if (source.pathSegments.length >= 2 &&
          ['shorts', 'live', 'embed'].contains(source.pathSegments.first)) {
        id = source.pathSegments[1];
      }
    }
    if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      return EmbeddedContent(
          Uri.https('www.youtube.com', '/embed/$id', {
            'playsinline': '1',
            'rel': '0',
            'origin': 'https://com.hafeza.links.trial'
          }),
          'YouTube');
    }
    if (['facebook.com', 'www.facebook.com', 'm.facebook.com'].contains(host)) {
      if (source.pathSegments.contains('videos') ||
          source.path == '/watch/' ||
          source.path == '/watch') {
        return EmbeddedContent(
            Uri.https('www.facebook.com', '/plugins/video.php', {
              'href': source
                  .replace(scheme: 'https', host: 'www.facebook.com')
                  .toString(),
              'show_text': 'true',
              'width': '500'
            }),
            'Facebook');
      }
      if (source.pathSegments.contains('posts') ||
          source.path == '/permalink.php' ||
          source.path == '/story.php') {
        return EmbeddedContent(
            Uri.https('www.facebook.com', '/plugins/post.php', {
              'href': source
                  .replace(scheme: 'https', host: 'www.facebook.com')
                  .toString(),
              'show_text': 'true',
              'width': '500'
            }),
            'Facebook');
      }
    }
    return null;
  }
}
