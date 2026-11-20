import 'package:bouga/features/links/data/external_link_opener.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExternalLinkOpener', () {
    test('opens only valid http and https URLs after invocation', () async {
      final launched = <Uri>[];
      final opener = ExternalLinkOpener(launcher: (uri) async {
        launched.add(uri);
        return true;
      });

      expect(await opener.open('https://example.com/path'), LinkOpenResult.opened);
      expect(await opener.open('http://example.com'), LinkOpenResult.opened);
      expect(launched, [
        Uri.parse('https://example.com/path'),
        Uri.parse('http://example.com'),
      ]);
    });

    test('rejects unsafe schemes, missing hosts and malformed URLs', () async {
      var calls = 0;
      final opener = ExternalLinkOpener(launcher: (_) async {
        calls++;
        return true;
      });

      for (final value in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'content://provider/item',
        'https:///missing-host',
        '/relative/path',
        'not a url',
      ]) {
        expect(await opener.open(value), LinkOpenResult.invalidUrl, reason: value);
      }
      expect(calls, 0);
    });

    test('reports a false launcher result', () async {
      final opener = ExternalLinkOpener(launcher: (_) async => false);
      expect(
        await opener.open('https://example.com'),
        LinkOpenResult.launchFailed,
      );
    });

    test('converts launcher exceptions to a failure result', () async {
      final opener = ExternalLinkOpener(
        launcher: (_) async => throw Exception('platform failure'),
      );
      expect(
        await opener.open('https://example.com'),
        LinkOpenResult.launchFailed,
      );
    });
  });
}
