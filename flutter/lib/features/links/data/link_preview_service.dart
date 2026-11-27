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
  static const _pageByteLimit = 262144;
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko)'
      ' Chrome/126.0 Mobile Safari/537.36 Bouga/1.0';
  Future<LinkPreview?> load(String url) =>
      _cache.putIfAbsent(url, () => _load(url));
  Future<LinkPreview?> _load(String url) async {
    final embedded = EmbeddedContent.fromUrl(url);
    if (embedded?.platform == 'YouTube') return _loadYouTube(embedded!);
    return _loadPage(url);
  }

  Future<LinkPreview?> _loadYouTube(EmbeddedContent embedded) async {
    final id = embedded.uri.pathSegments.last;
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

  /// Reads og:title/og:image (or the title tag) from an ordinary web page.
  Future<LinkPreview?> _loadPage(String url) async {
    final page = Uri.tryParse(url.trim());
    if (page == null ||
        !(page.scheme == 'https' || page.scheme == 'http') ||
        page.host.isEmpty ||
        page.userInfo.isNotEmpty) {
      return null;
    }
    final client = _client ?? http.Client();
    try {
      final response = await client.get(page, headers: const {
        'user-agent': _userAgent
      }).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final type = response.headers['content-type'] ?? '';
      if (type.isNotEmpty && !type.toLowerCase().contains('text/html')) {
        return null;
      }
      final bytes = response.bodyBytes.length > _pageByteLimit
          ? response.bodyBytes.sublist(0, _pageByteLimit)
          : response.bodyBytes;
      final htmlText = utf8.decode(bytes, allowMalformed: true);

      String? title;
      Uri? image;
      for (final match in RegExp(r'<meta\s[^>]*>', caseSensitive: false)
          .allMatches(htmlText)) {
        final tag = match.group(0)!;
        final key = (_attribute(tag, 'property') ?? _attribute(tag, 'name'))
            ?.toLowerCase();
        final content = _attribute(tag, 'content');
        if (key == null || content == null || content.trim().isEmpty) {
          continue;
        }
        if (title == null && (key == 'og:title' || key == 'twitter:title')) {
          title = _decodeEntities(content.trim());
        } else if (image == null &&
            (key == 'og:image' ||
                key == 'og:image:url' ||
                key == 'twitter:image')) {
          image = _safeImage(page, content.trim());
        }
        if (title != null && image != null) break;
      }
      if (title == null || title.isEmpty) {
        final tag = RegExp(r'<title[^>]*>(.*?)</title>',
                caseSensitive: false, dotAll: true)
            .firstMatch(htmlText);
        title = tag == null ? null : _decodeEntities(tag.group(1)!.trim());
      }
      if (title == null || title.isEmpty) return null;
      return LinkPreview(
          title: title.length > 300 ? title.substring(0, 300) : title,
          image: image);
    } catch (_) {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  static String? _attribute(String tag, String name) {
    final match = RegExp(
      '$name\\s*=\\s*(?:"([^"]*)"|\'([^\']*)\')',
      caseSensitive: false,
    ).firstMatch(tag);
    if (match == null) return null;
    return match.group(1) ?? match.group(2);
  }

  static Uri? _safeImage(Uri page, String raw) {
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    final resolved = page.resolveUri(parsed);
    if (resolved.scheme != 'https' ||
        resolved.host.isEmpty ||
        resolved.userInfo.isNotEmpty) {
      return null;
    }
    return resolved;
  }

  static String _decodeEntities(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&#x27;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}
