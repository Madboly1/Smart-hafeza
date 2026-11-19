/// SQL contract for the eventual transactional SQLite importer.
///
/// Unknown legacy properties are retained in [extra_json] so a future field
/// added by the Capacitor app is not silently discarded during migration.
abstract final class LegacyImportSql {
  static const createCategories = '''
    CREATE TABLE categories (
      name TEXT PRIMARY KEY NOT NULL,
      sort_order INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const createLinks = '''
    CREATE TABLE links (
      id TEXT PRIMARY KEY NOT NULL,
      url TEXT NOT NULL,
      kind TEXT NOT NULL DEFAULT 'مقال',
      category TEXT NOT NULL DEFAULT 'أخرى',
      title TEXT NOT NULL DEFAULT '',
      image_url TEXT NOT NULL DEFAULT '',
      progress INTEGER NOT NULL DEFAULT 0 CHECK(progress BETWEEN 0 AND 100),
      note TEXT NOT NULL DEFAULT '',
      last_seen INTEGER NOT NULL DEFAULT 0,
      extra_json TEXT NOT NULL DEFAULT '{}'
    )
  ''';

  static const createImportLog = '''
    CREATE TABLE import_log (
      source_key TEXT PRIMARY KEY NOT NULL,
      imported_at INTEGER NOT NULL,
      link_count INTEGER NOT NULL,
      category_count INTEGER NOT NULL,
      payload_sha256 TEXT NOT NULL
    )
  ''';

  static const indexes = <String>[
    'CREATE INDEX idx_links_category ON links(category)',
    'CREATE INDEX idx_links_last_seen ON links(last_seen DESC)',
  ];
}
