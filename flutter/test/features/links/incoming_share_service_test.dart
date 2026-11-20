import 'package:bouga/features/links/data/incoming_share_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bouga/incoming_share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('extracts URL-only and Arabic social share text safely', () {
    expect(IncomingShareService.firstWebUrl('https://example.com/a'),
        'https://example.com/a');
    expect(
        IncomingShareService.firstWebUrl(
            'شوف الفيديو ده\nhttps://example.com/watch?v=1&x=2'),
        'https://example.com/watch?v=1&x=2');
    expect(IncomingShareService.firstWebUrl('(https://example.com/a_(b)).'),
        'https://example.com/a_(b)');
    expect(
        IncomingShareService.firstWebUrl(
            'https://first.example https://second.example'),
        'https://first.example');
  });

  test('rejects missing, local and unsafe URLs', () {
    for (final text in [
      'نص بس',
      'javascript:alert(1)',
      'file:///test',
      'content://provider/1',
      'https:///bad',
      'https://user:password@example.com'
    ]) {
      expect(IncomingShareService.firstWebUrl(text), isNull, reason: text);
    }
  });

  test('drains cold and warm shares exactly once and detaches on dispose',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final pending = <String>['https://cold.example'];
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'takePending');
      final result = List<String>.of(pending);
      pending.clear();
      return result;
    });
    final received = <String>[];
    final service = IncomingShareService(channel: channel);
    await service.start(received.add);
    expect(received, ['https://cold.example']);
    Future<void> notify() async {
      await messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec()
              .encodeMethodCall(const MethodCall('available')),
          (_) {});
    }

    pending.add('https://warm.example');
    await notify();
    await notify();
    expect(received, ['https://cold.example', 'https://warm.example']);
    service.dispose();
    pending.add('https://after.example');
    await notify();
    expect(received.length, 2);
  });

  test('missing platform adapter does not break library startup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    messenger.setMockMethodCallHandler(
        channel, (_) async => throw MissingPluginException());
    final service = IncomingShareService(channel: channel);
    await service.start((_) => fail('unexpected share'));
    service.dispose();
  });
}
