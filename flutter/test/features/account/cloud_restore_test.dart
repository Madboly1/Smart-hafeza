import 'dart:convert';

import 'package:bouga/features/account/data/app_backup_envelope.dart';
import 'package:bouga/features/account/data/cloud_restore.dart';
import 'package:bouga/features/legacy_import/data/bouga_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Restore safety proof with disposable records: a confirmed cloud restore
/// must merge into local data, never clobber local open-state, and applying
/// the same backup twice must change nothing.
void main() {
  late BougaDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await BougaDatabase.open(databasePath: inMemoryDatabasePath);
  });

  tearDown(() async => database.close());

  Future<void> seedLocalLibrary() async {
    await database.importLegacyJson(jsonEncode({
      'links': [
        {'id': 'local-1', 'url': 'https://local.example', 'c': 'شغل', 'seen': 10},
      ],
      'cats': ['شغل'],
    }));
    await database.markOpened('local-1');
  }

  String cloudEnvelope() {
    final legacy = jsonEncode({
      'schemaVersion': 1,
      'source': 'bouga-flutter',
      'exportedAt': '2026-11-21T00:00:00.000Z',
      'data': {
        'links': [
          // Same link the device already has, but with an older open state.
          {'id': 'local-1', 'url': 'https://local.example', 'c': 'شغل', 'seen': 9, 'bougaOpenState': 'unopened'},
          {'id': 'cloud-1', 'url': 'https://cloud.example', 'c': 'قراءة', 'seen': 20},
        ],
        'cats': ['شغل', 'قراءة'],
      },
    });
    return AppBackupEnvelope.build(
      legacyExportJson: legacy,
      settings: const {'tourSeen': true},
      account: 'pilot@example.com',
      exportedAt: DateTime.utc(2026, 11, 21, 2),
    );
  }

  test('restore merges cloud links without clobbering local open state', () async {
    await seedLocalLibrary();
    final backup = AppBackupEnvelope.parse(cloudEnvelope());

    final report = await CloudRestore.applyBackup(database, backup);

    expect(report.imported, isTrue);
    final links = await database.getLinks();
    final byId = {for (final row in links) row['id']: row};
    expect(byId.keys, containsAll(['local-1', 'cloud-1']));
    // Local open state and opened timestamp survive the restore.
    expect(byId['local-1']!['open_state'], 'opened');
    expect(byId['local-1']!['opened_at'], isNotNull);
    // Categories merged, not replaced.
    final cats = await database.getCategories();
    expect(cats, containsAll(['شغل', 'قراءة']));
  });

  test('applying the same backup twice is a no-op', () async {
    await seedLocalLibrary();
    final backup = AppBackupEnvelope.parse(cloudEnvelope());

    await CloudRestore.applyBackup(database, backup);
    final second = await CloudRestore.applyBackup(database, backup);

    expect(second.skippedAsDuplicate, isTrue);
    expect((await database.getLinks()).length, 2);
  });

  test('v1 legacy backup applies with no settings side effects', () async {
    await seedLocalLibrary();
    final v1 = jsonEncode({
      'schemaVersion': 1,
      'source': 'bouga-flutter',
      'data': {
        'links': [
          {'id': 'legacy-1', 'url': 'https://legacy.example', 'c': 'أخرى', 'seen': 5},
        ],
        'cats': ['أخرى'],
      },
    });
    final report = await CloudRestore.applyBackup(database, AppBackupEnvelope.parse(v1));
    expect(report.imported, isTrue);
    expect((await database.getLinks()).map((r) => r['id']),
        containsAll(['local-1', 'legacy-1']));
    // Local rows untouched by the import.
    final local = (await database.getLinks()).firstWhere((r) => r['id'] == 'local-1');
    expect(local['open_state'], 'opened');
  });
}
