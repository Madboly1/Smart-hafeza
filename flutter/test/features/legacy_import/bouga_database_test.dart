import 'dart:convert';

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
    database = await BougaDatabase.open(
      databasePath: inMemoryDatabasePath,
    );
  });

  tearDown(() async => database.close());

  test('imports records and preserves unrecognized legacy properties', () async {
    final report = await database.importLegacyJson(jsonEncode({
      'schemaVersion': 1,
      'data': {
        'cats': ['مونتاج'],
        'links': [
          {
            'id': 'old-1',
            'url': 'https://example.com',
            'k': 'مقال',
            'c': 'مونتاج',
            'p': 35,
            'seen': 123,
            'newLegacyFlag': {'kept': true},
          }
        ],
      },
    }));

    expect(report.imported, isTrue);
    expect(report.linkCount, 1);
    final rows = await database.getLinks();
    expect(rows, hasLength(1));
    expect(rows.single['progress'], 35);
    expect(jsonDecode(rows.single['extra_json']! as String),
        {'newLegacyFlag': {'kept': true}});
  });

  test('same payload is idempotent and does not duplicate rows', () async {
    const payload = '{"cats":["أخرى"],"links":[{"id":"a","url":"https://a.test"}]}';
    final first = await database.importLegacyJson(payload);
    final second = await database.importLegacyJson(payload);

    expect(first.imported, isTrue);
    expect(second.skippedAsDuplicate, isTrue);
    expect(await database.countLinks(), 1);
  });

  test('changed snapshot updates matching IDs without deleting other rows', () async {
    await database.importLegacyJson(
      '{"cats":[],"links":[{"id":"a","url":"https://a.test","title":"old"}]}',
    );
    await database.importLegacyJson(
      '{"cats":[],"links":[{"id":"a","url":"https://a.test","title":"new"}]}',
    );

    final rows = await database.getLinks();
    expect(rows, hasLength(1));
    expect(rows.single['title'], 'new');
  });

  test('malformed JSON fails before touching existing database content', () async {
    await database.importLegacyJson(
      '{"cats":[],"links":[{"id":"safe","url":"https://safe.test"}]}',
    );

    expect(() => database.importLegacyJson('{broken json'),
        throwsFormatException);
    expect(await database.countLinks(), 1);
  });
}
