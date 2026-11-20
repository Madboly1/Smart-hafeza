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
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE links ADD COLUMN opened_at INTEGER');
          await db.execute(
              "ALTER TABLE links ADD COLUMN open_state TEXT NOT NULL DEFAULT 'unknown'");
        }
      },
      onCreate: (db, version) async {
        await db.execute(LegacyImportSql.createCategories);
        await db.execute(LegacyImportSql.createLinks);
        await db.execute('ALTER TABLE links ADD COLUMN opened_at INTEGER');
        await db.execute(
            "ALTER TABLE links ADD COLUMN open_state TEXT NOT NULL DEFAULT 'unknown'");
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
        const known = {
          'id',
          'url',
          'k',
          'c',
          'title',
          'img',
          'p',
          'note',
          'seen'
        };
        final extra = <String, dynamic>{
          for (final entry in fields.entries)
            if (!known.contains(entry.key)) entry.key: entry.value,
        };
        final existing = await txn.query('links',
            columns: ['open_state', 'opened_at'],
            where: 'id = ?',
            whereArgs: [link.id],
            limit: 1);
        final old = existing.isEmpty ? <String, Object?>{} : existing.first;
        final state =
            ['unknown', 'unopened', 'opened'].contains(fields['bougaOpenState'])
                ? fields['bougaOpenState']
                : old['open_state'] ?? 'unknown';
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
            'open_state': state,
            'opened_at': fields['bougaOpenedAt'] is int
                ? fields['bougaOpenedAt']
                : old['opened_at'],
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

  /// Creates an importer-compatible backup from one consistent SQLite snapshot.
  Future<String> exportLegacyJson() async {
    return _database.transaction((txn) async {
      final categoryRows = await txn.query(
        'categories',
        columns: ['name'],
        orderBy: 'sort_order, name',
      );
      final categories =
          categoryRows.map((row) => row['name'] as String).toList();
      final linkRows = await txn.query(
        'links',
        orderBy: 'last_seen DESC, rowid DESC',
      );
      final links = <Map<String, dynamic>>[];
      for (final row in linkRows) {
        final extra = jsonDecode(row['extra_json'] as String);
        final unknown = extra is Map
            ? Map<String, dynamic>.from(extra)
            : <String, dynamic>{};
        links.add({
          ...unknown,
          'id': row['id'],
          'url': row['url'],
          'k': row['kind'],
          'c': row['category'],
          'title': row['title'],
          'img': row['image_url'],
          'p': row['progress'],
          'note': row['note'],
          'seen': row['last_seen'],
          'bougaOpenState': row['open_state'],
          'bougaOpenedAt': row['opened_at'],
        });
        final category = row['category'] as String;
        if (!categories.contains(category)) categories.add(category);
      }
      return jsonEncode({
        'schemaVersion': 1,
        'source': 'bouga-flutter',
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'data': {'links': links, 'cats': categories},
      });
    });
  }

  String _unwrapExport(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic> && decoded['data'] is Map) {
      return jsonEncode(decoded['data']);
    }
    return source;
  }

  Future<List<Map<String, Object?>>> getLinks(
      {String query = '', String? category}) async {
    final clauses = <String>[];
    final args = <Object?>[];
    if (query.trim().isNotEmpty) {
      clauses.add('(title LIKE ? OR url LIKE ? OR note LIKE ?)');
      final term = '%${query.trim()}%';
      args.addAll([term, term, term]);
    }
    if (category != null && category != 'الكل') {
      clauses.add('category = ?');
      args.add(category);
    }
    return _database.query(
      'links',
      where: clauses.isEmpty ? null : clauses.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'last_seen DESC, rowid DESC',
    );
  }

  Future<List<String>> getCategories() async {
    final rows =
        await _database.query('categories', orderBy: 'sort_order, name');
    final values = rows.map((row) => row['name'] as String).toList();
    final linkRows = await _database.rawQuery(
      "SELECT DISTINCT category FROM links WHERE category NOT IN (${values.isEmpty ? "''" : List.filled(values.length, '?').join(',')})",
      values,
    );
    for (final row in linkRows) {
      final value = row['category'] as String?;
      if (value != null && value.isNotEmpty && !values.contains(value)) {
        values.add(value);
      }
    }
    return values;
  }

  Future<int> countLinks() async =>
      Sqflite.firstIntValue(
          await _database.rawQuery('SELECT COUNT(*) FROM links')) ??
      0;

  Future<int> addLink(
      {required String url,
      required String title,
      required String category,
      required String kind}) async {
    final normalized = url.trim();
    final existing = await _database.query('links',
        where: 'url = ?', whereArgs: [normalized], limit: 1);
    if (existing.isNotEmpty) {
      return 0;
    }
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await _database.insert('links', {
      'id': id,
      'url': normalized,
      'title': title.trim(),
      'category': category,
      'kind': kind,
      'progress': 0,
      'note': '',
      'last_seen': DateTime.now().millisecondsSinceEpoch,
      'extra_json': '{}',
      'open_state': 'unopened',
    });
    if (category.trim().isNotEmpty) {
      await _database.insert(
          'categories', {'name': category, 'sort_order': 999},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    return 1;
  }

  Future<void> updateLink(
      {required String id,
      required String title,
      required String category,
      required String note,
      required int progress}) async {
    await _database.update(
        'links',
        {
          'title': title,
          'category': category,
          'note': note,
          'progress': progress.clamp(0, 100),
        },
        where: 'id = ?',
        whereArgs: [id]);
    if (category.trim().isNotEmpty) {
      await _database.insert(
          'categories', {'name': category, 'sort_order': 999},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> addCategory(String name) async {
    final value = name.trim();
    if (value.isEmpty || value.length > 60) {
      throw const FormatException('اسم المجموعة من 1 إلى 60 حرف.');
    }
    await _database.insert('categories', {'name': value, 'sort_order': 999},
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> markOpened(String id) async {
    await _database.update(
        'links',
        {
          'open_state': 'opened',
          'opened_at': DateTime.now().millisecondsSinceEpoch
        },
        where: 'id = ?',
        whereArgs: [id]);
  }

  Future<void> deleteLink(String id) =>
      _database.delete('links', where: 'id = ?', whereArgs: [id]);

  Future<void> close() => _database.close();
}
