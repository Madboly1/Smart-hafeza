import 'dart:convert';

import 'package:bouga/features/account/data/app_backup_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

const _legacyExport = '''
{
  "schemaVersion": 1,
  "source": "bouga-flutter",
  "exportedAt": "2026-11-21T00:00:00.000Z",
  "data": {
    "links": [
      {"id": "1", "url": "https://example.com/مقال", "k": "مقال", "c": "شغل", "title": "عنوان عربي", "img": "", "p": 40, "note": "ملاحظة", "seen": 1700000000000, "bougaOpenState": "opened", "bougaOpenedAt": 1700000001000}
    ],
    "cats": ["شغل", "أخرى"]
  }
}
''';

void main() {
  group('AppBackupEnvelope', () {
    test('v2 round trip preserves library and settings', () {
      final settings = <String, Object?>{
        'reminders': <String, Object?>{'enabled': true, 'days': 7},
        'tourSeen': true,
      };
      final envelope = AppBackupEnvelope.build(
        legacyExportJson: _legacyExport,
        settings: settings,
        account: 'user@example.com',
        exportedAt: DateTime.utc(2026, 11, 21, 1, 30),
      );
      final backup = AppBackupEnvelope.parse(envelope);
      expect(backup.version, 2);
      expect(backup.linkCount, 1);
      expect(backup.categoryCount, 2);
      expect(backup.account, 'user@example.com');
      expect(backup.exportedAt, '2026-11-21T01:30:00.000Z');
      expect(backup.settings?['tourSeen'], true);
      expect((backup.settings?['reminders'] as Map)['days'], 7);
      final links = backup.library['links'] as List;
      expect((links.first as Map)['note'], 'ملاحظة');
      expect((links.first as Map)['title'], 'عنوان عربي');
    });

    test('v2 checksum detects tampering', () {
      final envelope = AppBackupEnvelope.build(
        legacyExportJson: _legacyExport,
        settings: const {'tourSeen': true},
      );
      final decoded = jsonDecode(envelope) as Map<String, dynamic>;
      (decoded['library'] as Map)['cats'] = ['مخترق'];
      expect(
        () => AppBackupEnvelope.parse(jsonEncode(decoded)),
        throwsA(isA<FormatException>()),
      );
    });

    test('v1 legacy export still parses without settings', () {
      final backup = AppBackupEnvelope.parse(_legacyExport);
      expect(backup.version, 1);
      expect(backup.linkCount, 1);
      expect(backup.settings, isNull);
    });

    test('library import payload is importer-compatible', () {
      final backup = AppBackupEnvelope.parse(_legacyExport);
      final payload = jsonDecode(AppBackupEnvelope.libraryImportPayload(backup))
          as Map<String, dynamic>;
      expect(payload['data'], isA<Map>());
      expect((payload['data'] as Map)['links'], hasLength(1));
    });

    test('rejects malformed files', () {
      expect(
        () => AppBackupEnvelope.parse('{"schemaVersion":2}'),
        throwsA(isA<FormatException>()),
      );
      expect(() => AppBackupEnvelope.parse('42'), throwsA(anything));
    });

    test('checksum is key-order independent', () {
      final a = AppBackupEnvelope.checksumOf(
        {'b': 1, 'a': 2},
        const {'x': true},
      );
      final b = AppBackupEnvelope.checksumOf(
        {'a': 2, 'b': 1},
        const {'x': true},
      );
      expect(a, b);
    });
  });
}
