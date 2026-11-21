import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../legacy_import/data/bouga_database.dart';
import 'app_backup_envelope.dart';
import 'backup_settings.dart';

/// Shared restore execution for the settings section and the reinstall
/// offer: a local safety snapshot first, then the confirmed restore.
class CloudRestore {
  static Future<void> writeSafetySnapshot(
    BougaDatabase database, {
    String? account,
  }) async {
    try {
      final legacy = await database.exportLegacyJson();
      final settings = await BougaBackupSettings.capture();
      final envelope = AppBackupEnvelope.build(
        legacyExportJson: legacy,
        settings: settings,
        account: account,
      );
      final dir = Directory(
        '${(await getApplicationDocumentsDirectory()).path}/safety-snapshots',
      );
      await dir.create(recursive: true);
      final stamp = DateTime.now().millisecondsSinceEpoch;
      await File(
        '${dir.path}/bouga-pre-restore-$stamp.json',
      ).writeAsString(envelope, flush: true);
      final snapshots = dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.contains('bouga-pre-restore-'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final stale in snapshots.skip(5)) {
        await stale.delete();
      }
    } catch (_) {
      // A missing snapshot must never block a user-confirmed restore.
    }
  }

  static Future<ImportReport> applyBackup(
    BougaDatabase database,
    AppBackup backup,
  ) async {
    final report = await database.importLegacyJson(
      AppBackupEnvelope.libraryImportPayload(backup),
    );
    final settings = backup.settings;
    if (settings != null) {
      await BougaBackupSettings.apply(settings);
    }
    return report;
  }
}
