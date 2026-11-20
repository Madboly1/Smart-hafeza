import 'package:bouga/features/links/data/link_platform.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('popular platforms group host aliases and mobile subdomains', () {
    for (final url in [
      'https://youtu.be/abc',
      'https://m.youtube.com/watch?v=a',
      'HTTPS://WWW.YOUTUBE.COM/shorts/a'
    ]) {
      expect(linkPlatform(url), 'YouTube');
    }
    expect(linkPlatform('https://vm.tiktok.com/abc'), 'TikTok');
    expect(linkPlatform('https://www.instagram.com/reel/a'), 'Instagram');
    expect(linkPlatform('https://fb.watch/abc'), 'Facebook');
    expect(linkPlatform('https://m.facebook.com/story'), 'Facebook');
    expect(linkPlatform('https://twitter.com/a'), 'X / Twitter');
    expect(linkPlatform('https://x.com/a'), 'X / Twitter');
    expect(linkPlatform('https://t.me/channel'), 'Telegram');
    expect(linkPlatform('https://wa.me/123'), 'WhatsApp');
    expect(linkPlatform('https://pin.it/a'), 'Pinterest');
    expect(linkPlatform('https://linkedin.com/in/a'), 'LinkedIn');
    expect(linkPlatform('https://redd.it/abc'), 'Reddit');
    expect(linkPlatform('https://snapchat.com/add/a'), 'Snapchat');
  });
  test('unknown sites and malformed URLs stay under Other without spoofing',
      () {
    for (final url in [
      'https://example.com/youtube.com',
      'https://youtube.com.evil.example',
      'https://notyoutube.com',
      'https://evil.example/?url=https://youtube.com',
      '',
      'not a url',
      'mailto:a@youtube.com'
    ]) {
      expect(linkPlatform(url), 'أخرى');
    }
  });
  test('platforms come only from real links and filtering preserves order/data',
      () {
    final rows = <Map<String, Object?>>[
      {'id': '1', 'url': 'https://youtu.be/a', 'note': 'keep'},
      {'id': '2', 'url': 'https://example.com'},
      {'id': '3', 'url': 'https://youtube.com/watch?v=b'},
      {'id': '4', 'url': 'https://another.example'},
    ];
    expect(savedPlatforms([]), isEmpty);
    expect(savedPlatforms(rows), ['YouTube', 'أخرى']);
    expect(filterPlatform(rows, 'YouTube').map((r) => r['id']), ['1', '3']);
    expect(filterPlatform(rows, 'أخرى').map((r) => r['id']), ['2', '4']);
    expect(filterPlatform(rows, null), same(rows));
    expect(rows.first['note'], 'keep');
  });
}
