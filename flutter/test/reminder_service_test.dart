import 'package:bouga/features/settings/data/reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReminderService.channel, null);
  });
  test('initialization and settings use local channel and explicit days',
      () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReminderService.channel, (call) async {
      calls.add(call);
      return {'enabled': true, 'days': 3, 'permission': true};
    });
    final service = ReminderService();
    expect((await service.initialize()).enabled, isTrue);
    expect((await service.save(enabled: false, days: 7)).days, 3);
    expect(calls[0].method, 'initialize');
    expect(calls[1].arguments, {'enabled': false, 'days': 7});
    expect(() => service.save(enabled: true, days: 0), throwsArgumentError);
  });
  test('denied notifications are visibly disabled', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReminderService.channel,
            (_) async => {'enabled': false, 'days': 3, 'permission': false});
    final state = await ReminderService().save(enabled: true, days: 3);
    expect(state.enabled, isFalse);
    expect(state.permission, isFalse);
  });
  test('unsupported targets do not call native scheduling', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect((await ReminderService().initialize()).enabled, isFalse);
  });
}
