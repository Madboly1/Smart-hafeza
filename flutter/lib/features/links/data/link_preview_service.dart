import 'dart:convert';
import 'package:http/http.dart' as http;
import 'embedded_content.dart';

class LinkPreview {
  const LinkPreview({required this.title, this.image});
  final String title;
  final Uri? image;
}

class LinkPreviewService {
  LinkPreviewService({http.Client? client}) : _client = client;
  final http.Client? _client;
  final Map<String, Future<LinkPreview?>> _cache = {};
  Future<LinkPreview?> load(String url) =>
      _cache.putIfAbsent(url, () => _load(url));
  Future<LinkPreview?> _load(String url) async {
    final embedded = EmbeddedContent.fromUrl(url);
    if (embedded?.platform != 'YouTube') return null;
    final id = embedded!.uri.pathSegments.last;
    final endpoint = Uri.https('www.youtube.com', '/oembed', {
      'url': Uri.https('www.youtube.com', '/watch', {'v': id}).toString(),
      'format': 'json',
    });
    final client = _client ?? http.Client();
    try {
      final response =
          await client.get(endpoint).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.length > 65536) {
        return null;
      }
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is! Map<String, dynamic> || value['title'] is! String) {
        return null;
      }
      final title = (value['title'] as String).trim();
      if (title.isEmpty) return null;
      final image = Uri.tryParse(value['thumbnail_url']?.toString() ?? '');
      final safeImage = image != null &&
              image.scheme == 'https' &&
              image.userInfo.isEmpty &&
              (image.host == 'i.ytimg.com' || image.host.endsWith('.ytimg.com'))
          ? image
          : null;
      return LinkPreview(
          title: title.length > 300 ? title.substring(0, 300) : title,
          image: safeImage);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }
}
