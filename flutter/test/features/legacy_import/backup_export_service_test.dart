import 'dart:convert';
import 'dart:typed_data';

import 'package:bouga/features/legacy_import/data/backup_export_service.dart';
import 'package:bouga/features/legacy_import/data/bouga_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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

  test('exports importer-compatible envelope and round-trips all link fields', () async {
    await database.importLegacyJson(jsonEncode({
      'schemaVersion': 1,
      'data': {
        'cats': ['مونتاج', 'تعلم'],
        'links': [
          {
            'id': 'unicode-id',
            'url': 'https://example.com/درس',
            'title': 'درس عربي 🎬',
            'note': 'ملاحظة بالعربي — 日本語',
            'k': 'فيديو',
            'c': 'مونتاج',
            'img': 'https://example.com/thumb.jpg',
            'p': 73,
            'seen': 1700000000123,
            'futureMetadata': {'nested': true, 'label': 'مستقبل'},
          }
        ],
      },
    }));

    final exported = await database.exportLegacyJson();
    final envelope = jsonDecode(exported) as Map<String, dynamic>;
    expect(envelope['schemaVersion'], 1);
    expect(envelope['source'], 'bouga-flutter');
    expect(envelope['exportedAt'], isA<String>());
    final data = envelope['data'] as Map<String, dynamic>;
    expect(data['cats'], containsAll(['مونتاج', 'تعلم']));
    final link = (data['links'] as List).single as Map<String, dynamic>;
    expect(link['id'], 'unicode-id');
    expect(link['url'], 'https://example.com/درس');
    expect(link['title'], 'درس عربي 🎬');
    expect(link['note'], 'ملاحظة بالعربي — 日本語');
    expect(link['k'], 'فيديو');
    expect(link['c'], 'مونتاج');
    expect(link['img'], 'https://example.com/thumb.jpg');
    expect(link['p'], 73);
    expect(link['seen'], 1700000000123);
    expect(link['futureMetadata'], {'nested': true, 'label': 'مستقبل'});

    final fresh = await BougaDatabase.open(databasePath: inMemoryDatabasePath);
    addTearDown(fresh.close);
    final report = await fresh.importLegacyJson(exported);
    expect(report.imported, isTrue);
    final rows = await fresh.getLinks();
    expect(rows, hasLength(1));
    expect(rows.single['id'], 'unicode-id');
    expect(rows.single['title'], 'درس عربي 🎬');
    expect(rows.single['note'], 'ملاحظة بالعربي — 日本語');
    expect(rows.single['progress'], 73);
    expect(jsonDecode(rows.single['extra_json']! as String)['futureMetadata'],
        {'nested': true, 'label': 'مستقبل'});
    expect(await fresh.getCategories(), containsAll(['مونتاج', 'تعلم']));
    expect((await fresh.importLegacyJson(exported)).skippedAsDuplicate, isTrue);
    expect(await fresh.countLinks(), 1);
  });

  test('exports an empty database as a valid empty envelope', () async {
    final envelope = jsonDecode(await database.exportLegacyJson())
        as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>;
    expect(data['links'], isEmpty);
    expect(data['cats'], isEmpty);
    final report = await database.importLegacyJson(jsonEncode(envelope));
    expect(report.imported, isTrue);
    expect(await database.countLinks(), 0);
  });

  test('saver receives UTF-8 bytes and cancellation is not success', () async {
    Uint8List? savedBytes;
    final service = BackupExportService(saveFile: (bytes) async {
      savedBytes = bytes;
      return '/local/bouga-backup.json';
    });

    expect(await service.save(database), isTrue);
    final text = utf8.decode(savedBytes!);
    expect(text, contains('schemaVersion'));
    expect(text, contains('أخرى'));

    final cancelled = BackupExportService(saveFile: (_) async => null);
    expect(await cancelled.save(database), isFalse);
  });

  test('save errors propagate to the UI error handler', () async {
    final service = BackupExportService(
      saveFile: (_) async => throw Exception('disk unavailable'),
    );
    expect(service.save(database), throwsException);
  });
}
