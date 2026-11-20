import 'dart:io';
import 'package:bouga/features/settings/data/android_update_service.dart';
import 'package:bouga/features/settings/data/update_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bouga/updates');
  late Directory temp;
  late int installs;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('bouga-update-test');
    installs = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'install') {
        installs++;
        expect(
            await File((call.arguments as Map)['path'] as String).readAsBytes(),
            [1, 2, 3]);
        return true;
      }
      return {'versionCode': 5003, 'abi': 'unsupported'};
    });
  });
  tearDown(() async {
    await temp.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  UpdateManifest manifest({String? hash, String? url}) => UpdateManifest(
      versionCode: 5004,
      versionName: '1.0.4',
      releaseMessage: 'تحديث',
      apkUrl: Uri.parse(url ??
          'https://github.com/Madboly1/Smart-hafeza/releases/download/bouga-isolated-4/app-arm64-v8a-release.apk'),
      sha256: hash ?? sha256.convert([1, 2, 3]).toString());
  AndroidUpdateService service(http.Client client) => AndroidUpdateService(
      client: client, temporaryDirectory: () async => temp);
  test('verified download opens Android installer once', () async {
    final progress = <double?>[];
    await service(MockClient((_) async => http.Response.bytes([1, 2, 3], 200)))
        .downloadAndInstall(manifest(), progress.add);
    expect(installs, 1);
    expect(progress.last, 1);
  });
  test('hash mismatch never opens installer and removes partial bytes',
      () async {
    await expectLater(
        service(MockClient((_) async => http.Response.bytes([9], 200)))
            .downloadAndInstall(manifest(), (_) {}),
        throwsFormatException);
    expect(installs, 0);
    expect(
        await File('${temp.path}/bouga_updates/update.part').exists(), false);
  });
  test('untrusted download URL is rejected before request', () async {
    var calls = 0;
    await expectLater(
        service(MockClient((_) async {
          calls++;
          return http.Response('', 200);
        })).downloadAndInstall(
            manifest(url: 'https://evil.example/app.apk'), (_) {}),
        throwsFormatException);
    expect(calls, 0);
    expect(installs, 0);
  });
  test('HTTP failure is safe and retry can succeed', () async {
    await expectLater(
        service(MockClient((_) async => http.Response('', 503)))
            .downloadAndInstall(manifest(), (_) {}),
        throwsA(isA<HttpException>()));
    expect(installs, 0);
    await service(MockClient((_) async => http.Response.bytes([1, 2, 3], 200)))
        .downloadAndInstall(manifest(), (_) {});
    expect(installs, 1);
  });
  test('unsupported installed ABI fails without interrupting app', () async {
    expect((await AndroidUpdateService().check()).status,
        UpdateStatus.temporarilyUnavailable);
  });
}
