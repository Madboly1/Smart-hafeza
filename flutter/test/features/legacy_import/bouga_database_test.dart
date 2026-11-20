import 'dart:io';
import 'package:bouga/features/legacy_import/data/legacy_import_contract.dart';
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

  test('version1 upgrade preserves links and groups with unknown opened state',
      () async {
    final temp = await Directory.systemTemp.createTemp('bouga-migration-test');
    final path = '${temp.path}/old.db';
    final old = await databaseFactory.openDatabase(path,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute(LegacyImportSql.createCategories);
              await db.execute(LegacyImportSql.createLinks);
              await db.execute(LegacyImportSql.createImportLog);
              await db.insert('categories', {'name': 'قديم', 'sort_order': 1});
              await db.insert('links', {
                'id': 'existing',
                'url': 'https://old.example',
                'category': 'قديم',
                'note': 'مهم',
                'last_seen': 123
              });
            }));
    await old.close();
    final upgraded = await BougaDatabase.open(databasePath: path);
    final row = (await upgraded.getLinks()).single;
    expect(row['note'], 'مهم');
    expect(row['open_state'], 'unknown');
    expect(row['last_seen'], 123);
    expect(await upgraded.getCategories(), ['قديم']);
    await upgraded.close();
    await temp.delete(recursive: true);
  });

  test('fresh groups are empty and users create their own without fixed seeds',
      () async {
    expect(await database.getCategories(), isEmpty);
    await database.addCategory('مجموعتي');
    expect(await database.getCategories(), ['مجموعتي']);
  });

  test(
      'new unopened and imported unknown remain distinct and backup preserves state',
      () async {
    await database.addLink(
        url: 'https://new.example', title: '', category: '', kind: 'رابط');
    expect((await database.getLinks()).single['open_state'], 'unopened');
    await database.importLegacyJson(jsonEncode({
      'links': [
        {'id': 'legacy', 'url': 'https://old.example', 'seen': 123}
      ]
    }));
    final old =
        (await database.getLinks()).firstWhere((row) => row['id'] == 'legacy');
    expect(old['open_state'], 'unknown');
    final current = (await database.getLinks())
        .firstWhere((row) => row['url'] == 'https://new.example');
    await database.markOpened(current['id'] as String);
    final backup = await database.exportLegacyJson();
    final restored = await BougaDatabase.open(
      databasePath: inMemoryDatabasePath,
    );
    await restored.importLegacyJson(backup);
    expect(
        (await restored.getLinks()).firstWhere(
            (row) => row['url'] == 'https://new.example')['open_state'],
        'opened');
    await restored.close();
  });

  test('imports records and preserves unrecognized legacy properties',
      () async {
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
    expect(jsonDecode(rows.single['extra_json']! as String), {
      'newLegacyFlag': {'kept': true}
    });
  });

  test('maps the complete real Capacitor hl link shape into database columns',
      () async {
    await database.importLegacyJson(jsonEncode({
      'schemaVersion': 1,
      'source': 'bouga-capacitor-hl',
      'data': {
        'cats': ['مونتاج'],
        'links': [
          {
            'id': 'legacy-real-1',
            'url': 'https://example.com/watch',
            'title': 'درس مونتاج',
            'note': 'وقفت عند الدقيقة 12',
            'p': '65',
            'seen': 1700000000123,
            'c': 'مونتاج',
            'k': 'فيديو',
            'img': 'https://example.com/thumb.jpg',
            'futureField': 'preserve-me',
          }
        ],
      },
    }));

    final rows = await database.getLinks();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row['id'], 'legacy-real-1');
    expect(row['url'], 'https://example.com/watch');
    expect(row['title'], 'درس مونتاج');
    expect(row['note'], 'وقفت عند الدقيقة 12');
    expect(row['progress'], 65);
    expect(row['last_seen'], 1700000000123);
    expect(row['category'], 'مونتاج');
    expect(row['kind'], 'فيديو');
    expect(row['image_url'], 'https://example.com/thumb.jpg');
    expect(jsonDecode(row['extra_json']! as String),
        {'futureField': 'preserve-me'});
    expect(await database.getCategories(), contains('مونتاج'));
  });

  test('same payload is idempotent and does not duplicate rows', () async {
    const payload =
        '{"cats":["أخرى"],"links":[{"id":"a","url":"https://a.test"}]}';
    final first = await database.importLegacyJson(payload);
    final second = await database.importLegacyJson(payload);

    expect(first.imported, isTrue);
    expect(second.skippedAsDuplicate, isTrue);
    expect(await database.countLinks(), 1);
  });

  test('changed snapshot updates matching IDs without deleting other rows',
      () async {
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

  test('malformed JSON fails before touching existing database content',
      () async {
    await database.importLegacyJson(
      '{"cats":[],"links":[{"id":"safe","url":"https://safe.test"}]}',
    );

    expect(database.importLegacyJson('{broken json'), throwsFormatException);
    expect(await database.countLinks(), 1);
  });
}
