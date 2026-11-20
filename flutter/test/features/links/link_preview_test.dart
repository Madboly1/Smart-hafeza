import 'dart:convert';
import 'package:bouga/features/links/data/link_preview_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
      'public YouTube preview canonicalizes URL and caches, does not fetch arbitrary URLs',
      () async {
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
    expect(await service.load('https://example.com/private'), isNull);
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
}
