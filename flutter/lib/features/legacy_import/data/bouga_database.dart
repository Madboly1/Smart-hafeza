import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/legacy_snapshot.dart';
import 'legacy_import_contract.dart';

class ImportReport {
  const ImportReport({
    required this.imported,
    required this.skippedAsDuplicate,
    required this.linkCount,
    required this.categoryCount,
  });

  final bool imported;
  final bool skippedAsDuplicate;
  final int linkCount;
  final int categoryCount;
}

class BougaDatabase {
  BougaDatabase._(this._database);

  final Database _database;
  static const databaseName = 'bouga.db';
  static const legacySourceKey = 'legacy-hl-v1';

  static Future<BougaDatabase> open({String? databasePath}) async {
    final path = databasePath ??
        p.join((await getApplicationDocumentsDirectory()).path, databaseName);
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(LegacyImportSql.createCategories);
        await db.execute(LegacyImportSql.createLinks);
        await db.execute(LegacyImportSql.createImportLog);
        for (final index in LegacyImportSql.indexes) {
          await db.execute(index);
        }
      },
    );
    return BougaDatabase._(db);
  }

  /// Imports a JSON export atomically. Identical payloads are no-ops.
  /// Changed payloads upsert by stable legacy ID without deleting local rows.
  Future<ImportReport> importLegacyJson(String source) async {
    final snapshot = LegacySnapshot.fromJson(_unwrapExport(source));
    final canonical = jsonEncode({
      'categories': snapshot.categories,
      'links': snapshot.links.map((link) => link.fields).toList(),
    });
    final digest = sha256.convert(utf8.encode(canonical)).toString();

    return _database.transaction((txn) async {
      final previous = await txn.query(
        'import_log',
        where: 'source_key = ?',
        whereArgs: [legacySourceKey],
        limit: 1,
      );
      if (previous.isNotEmpty && previous.first['payload_sha256'] == digest) {
        return ImportReport(
          imported: false,
          skippedAsDuplicate: true,
          linkCount: snapshot.links.length,
          categoryCount: snapshot.categories.length,
        );
      }

      for (var i = 0; i < snapshot.categories.length; i++) {
        await txn.insert(
          'categories',
          {'name': snapshot.categories[i], 'sort_order': i},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }

      for (final link in snapshot.links) {
        final fields = link.fields;
        const known = {'id', 'url', 'k', 'c', 'title', 'img', 'p', 'note', 'seen'};
        final extra = <String, dynamic>{
          for (final entry in fields.entries)
            if (!known.contains(entry.key)) entry.key: entry.value,
        };
        await txn.insert(
          'links',
          {
            'id': link.id,
            'url': link.url,
            'kind': fields['k']?.toString() ?? 'مقال',
            'category': fields['c']?.toString() ?? 'أخرى',
            'title': fields['title']?.toString() ?? '',
            'image_url': fields['img']?.toString() ?? '',
            'progress': fields['p'] as int? ?? 0,
            'note': fields['note']?.toString() ?? '',
            'last_seen': fields['seen'] as int? ?? 0,
            'extra_json': jsonEncode(extra),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await txn.insert(
        'import_log',
        {
          'source_key': legacySourceKey,
          'imported_at': DateTime.now().millisecondsSinceEpoch,
          'link_count': snapshot.links.length,
          'category_count': snapshot.categories.length,
          'payload_sha256': digest,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return ImportReport(
        imported: true,
        skippedAsDuplicate: false,
        linkCount: snapshot.links.length,
        categoryCount: snapshot.categories.length,
      );
    });
  }

  String _unwrapExport(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic> && decoded['data'] is Map) {
      return jsonEncode(decoded['data']);
    }
    return source;
  }

  Future<List<Map<String, Object?>>> getLinks() =>
      _database.query('links', orderBy: 'last_seen DESC');

  Future<int> countLinks() async =>
      Sqflite.firstIntValue(await _database.rawQuery('SELECT COUNT(*) FROM links')) ?? 0;

  Future<void> close() => _database.close();
}
