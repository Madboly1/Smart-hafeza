import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'bouga_database.dart';

typedef BackupFileSaver = Future<String?> Function(Uint8List bytes);

class BackupExportService {
  BackupExportService({BackupFileSaver? saveFile})
      : _saveFile = saveFile ?? _saveWithFilePicker;

  final BackupFileSaver _saveFile;

  static Future<String?> _saveWithFilePicker(Uint8List bytes) =>
      FilePicker.platform.saveFile(
        fileName: 'bouga-backup.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: bytes,
      );

  /// Returns false when the user cancels the native save dialog.
  Future<bool> save(BougaDatabase database) async {
    final json = await database.exportLegacyJson();
    final destination = await _saveFile(Uint8List.fromList(utf8.encode(json)));
    return destination != null && destination.isNotEmpty;
  }
}
