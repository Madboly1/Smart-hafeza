import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Parsed app backup (v1 legacy export or v2 envelope with settings).
class AppBackup {
  const AppBackup({
    required this.version,
    required this.library,
    this.exportedAt,
    this.settings,
    this.account,
  });

  final int version;

  /// Importer-compatible payload content: {'links': [...], 'cats': [...]}.
  final Map<String, dynamic> library;
  final String? exportedAt;
  final Map<String, dynamic>? settings;
  final String? account;

  int get linkCount => (library['links'] as List?)?.length ?? 0;
  int get categoryCount => (library['cats'] as List?)?.length ?? 0;
}

/// Versioned backup envelope. v2 wraps the existing library export with
/// user settings (reminder prefs, tour marker) and a tamper checksum.
/// v1 files keep importing exactly as before.
class AppBackupEnvelope {
  static const int currentVersion = 2;

  static String build({
    required String legacyExportJson,
    Map<String, Object?>? settings,
    String? account,
    DateTime? exportedAt,
  }) {
    final decoded = jsonDecode(legacyExportJson);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is! Map) {
      throw const FormatException('تعذر بناء النسخة الاحتياطية');
    }
    final library = Map<String, dynamic>.from(data);
    final envelope = <String, Object?>{
      'schemaVersion': currentVersion,
      'app': 'bouga',
      'source': 'bouga-flutter',
      'exportedAt': (exportedAt ?? DateTime.now().toUtc()).toIso8601String(),
      if (account != null && account.isNotEmpty) 'account': account,
      'library': library,
      if (settings != null) 'settings': settings,
    };
    envelope['checksum'] = checksumOf(library, settings);
    return jsonEncode(envelope);
  }

  static AppBackup parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    }
    final version = decoded['schemaVersion'];
    if (version == currentVersion) {
      final library = decoded['library'];
      if (library is! Map) {
        throw const FormatException('ملف النسخة الاحتياطية غير صالح');
      }
      final settings = decoded['settings'];
      final expected = decoded['checksum'];
      if (expected is String && expected != checksumOf(library, settings)) {
        throw const FormatException('النسخة الاحتياطية اتعدلت أو اتلفت');
      }
      return AppBackup(
        version: currentVersion,
        library: Map<String, dynamic>.from(library),
        exportedAt: decoded['exportedAt']?.toString(),
        settings: settings is Map ? Map<String, dynamic>.from(settings) : null,
        account: decoded['account']?.toString(),
      );
    }
    final data = decoded['data'];
    if (data is! Map) {
      throw const FormatException('ملف النسخة الاحتياطية غير صالح');
    }
    return AppBackup(
      version: 1,
      library: Map<String, dynamic>.from(data),
      exportedAt: decoded['exportedAt']?.toString(),
    );
  }

  /// Payload accepted by BougaDatabase.importLegacyJson.
  static String libraryImportPayload(AppBackup backup) =>
      jsonEncode(<String, Object?>{'data': backup.library});

  static String checksumOf(Object? library, Object? settings) {
    final canonical =
        '${jsonEncode(sortJson(library))}|${jsonEncode(sortJson(settings))}';
    return sha256.convert(utf8.encode(canonical)).toString();
  }

  static Object? sortJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: sortJson(value[key]),
      };
    }
    if (value is List) return value.map(sortJson).toList();
    return value;
  }
}
