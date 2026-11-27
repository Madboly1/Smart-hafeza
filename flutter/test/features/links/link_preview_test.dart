import 'dart:convert';
import 'package:bouga/features/links/data/link_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('public YouTube preview canonicalizes URL and caches', () async {
    var calls = 0;
    final service = LinkPreviewService(client: MockClient((request) async {
      calls++;
      expect(request.url.host, 'www.youtube.com');
      expect(request.url.path, '/oembed');
      expect(request.url.queryParameters['url'],
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
      return http.Response(
          jsonEncode({
            'title': 'Public title',
            'thumbnail_url': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg'
          }),
          200);
    }));
    expect((await service.load('https://youtu.be/dQw4w9WgXcQ'))?.title,
        'Public title');
    await service.load('https://youtu.be/dQw4w9WgXcQ');
    expect(calls, 1);
  });
  test('missing private blocked content falls back without throwing', () async {
    final service = LinkPreviewService(
        client: MockClient((_) async => http.Response('not available', 404)));
    expect(await service.load('https://youtu.be/dQw4w9WgXcQ'), isNull);
  });
  test('unsafe thumbnail is rejected while title stays usable', () async {
    final service = LinkPreviewService(
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'title': 'title',
              'thumbnail_url': 'https://other.example/tracker'
            }),
            200)));
    expect((await service.load('https://youtu.be/dQw4w9WgXcQ'))?.image, isNull);
  });

  test('ordinary pages use og:title and og:image and cache the result',
      () async {
    var calls = 0;
    final service = LinkPreviewService(client: MockClient((request) async {
      calls++;
      expect(request.url.host, 'example.com');
      return http.Response(
          '<html><head>'
          '<meta property="og:title" content="مقال مهم &amp; جديد">'
          '<meta content="/cover.png" property="og:image">'
          '<title>ignored</title>'
          '</head><body></body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'});
    }));
    final preview = await service.load('https://example.com/post/1');
    expect(preview?.title, 'مقال مهم & جديد');
    expect(preview?.image.toString(), 'https://example.com/cover.png');
    await service.load('https://example.com/post/1');
    expect(calls, 1);
  });

  test('page without og tags falls back to the title tag', () async {
    final service = LinkPreviewService(
        client: MockClient((_) async => http.Response(
            '<html><head><title>  عنوان الصفحة  </title></head></html>', 200,
            headers: {'content-type': 'text/html; charset=utf-8'})));
    final preview = await service.load('https://example.com/article');
    expect(preview?.title, 'عنوان الصفحة');
    expect(preview?.image, isNull);
  });

  test('non-html and unsafe image responses return no preview data', () async {
    final pdf = LinkPreviewService(
        client: MockClient((_) async => http.Response.bytes(
            [37, 80, 68, 70], 200,
            headers: {'content-type': 'application/pdf'})));
    expect(await pdf.load('https://example.com/file.pdf'), isNull);

    final tracker = LinkPreviewService(
        client: MockClient((_) async => http.Response(
            '<head>'
            '<meta property="og:title" content="t">'
            '<meta property="og:image" content="http://insecure.example/a.png">'
            '</head>',
            200,
            headers: {'content-type': 'text/html; charset=utf-8'})));
    final preview = await tracker.load('https://example.com/x');
    expect(preview?.title, 't');
    expect(preview?.image, isNull);
  });
}
