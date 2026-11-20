import 'dart:convert';

import 'package:bouga/features/settings/data/update_service.dart';
import 'package:flutter_test/flutter_test.dart';

const validManifest = {
  'versionCode': 2,
  'versionName': '1.1.0',
  'releaseMessage': 'تحسينات وإصلاحات للأداء.',
  'apkUrl': 'https://example.com/bouga.apk',
  'sha256': 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
};

void main() {
  UpdateService serviceFor(
    Object manifest, {
    int currentVersionCode = 1,
  }) {
    return UpdateService(
      currentVersionCode: currentVersionCode,
      loader: (_) async => jsonEncode(manifest),
    );
  }

  test('reports no update for the installed version', () async {
    final result = await serviceFor(
      {...validManifest, 'versionCode': 1},
    ).checkForUpdate();
    expect(result.status, UpdateStatus.noUpdate);
    expect(result.manifest, isNull);
  });

  test('detects a newer update', () async {
    final result = await serviceFor(validManifest).checkForUpdate();
    expect(result.status, UpdateStatus.updateAvailable);
    expect(result.manifest?.versionName, '1.1.0');
  });

  test('ignores same and older valid version codes', () async {
    for (final code in [2, 1]) {
      final result = await serviceFor(
        {...validManifest, 'versionCode': code},
        currentVersionCode: 2,
      ).checkForUpdate();
      expect(result.status, UpdateStatus.noUpdate);
    }
  });

  test('treats malformed and incomplete manifests as unavailable', () async {
    final malformed = await serviceFor('not an object').checkForUpdate();
    expect(malformed.status, UpdateStatus.temporarilyUnavailable);

    final zeroVersion = await serviceFor(
      {...validManifest, 'versionCode': 0},
    ).checkForUpdate();
    expect(zeroVersion.status, UpdateStatus.temporarilyUnavailable);

    final missingField = Map<String, Object>.from(validManifest)
      ..remove('sha256');
    final missing = await serviceFor(missingField).checkForUpdate();
    expect(missing.status, UpdateStatus.temporarilyUnavailable);

    final wrongType = await serviceFor(
      {...validManifest, 'versionCode': '2'},
    ).checkForUpdate();
    expect(wrongType.status, UpdateStatus.temporarilyUnavailable);
  });

  test('validates optional fields and mandatory flag', () async {
    final optional = await serviceFor(validManifest).checkForUpdate();
    expect(optional.manifest?.mandatory, isFalse);

    final mandatory = await serviceFor({
      ...validManifest,
      'mandatory': true,
      'minSupportedVersion': 2,
    }).checkForUpdate();
    expect(mandatory.status, UpdateStatus.updateAvailable);
    expect(mandatory.manifest?.mandatory, isTrue);
    expect(mandatory.manifest?.minSupportedVersion, 2);

    final invalidMandatory = await serviceFor({
      ...validManifest,
      'mandatory': 'true',
    }).checkForUpdate();
    expect(invalidMandatory.status, UpdateStatus.temporarilyUnavailable);
  });

  test('network errors fail safely', () async {
    final service = UpdateService(
      loader: (_) async => throw Exception('offline'),
    );
    final result = await service.checkForUpdate();
    expect(result.status, UpdateStatus.temporarilyUnavailable);
  });
}
