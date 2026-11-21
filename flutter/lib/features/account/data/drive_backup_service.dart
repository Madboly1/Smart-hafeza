import 'dart:convert';

import 'package:http/http.dart' as http;

class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.name,
    this.createdTime,
    this.sizeBytes,
  });

  final String id;
  final String name;
  final DateTime? createdTime;
  final int? sizeBytes;
}

class DriveBackupException implements Exception {
  const DriveBackupException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Drive REST v3 over the hidden app-private folder (appDataFolder).
/// Only files this app created are visible. Backups are immutable here:
/// uploads always create a new dated file, nothing is ever overwritten
/// or deleted.
class DriveBackupService {
  DriveBackupService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String filesEndpoint =
      'https://www.googleapis.com/drive/v3/files';
  static const String uploadEndpoint =
      'https://www.googleapis.com/upload/drive/v3/files';
  static const String namePrefix = 'bouga-backup-';

  Future<List<DriveBackupFile>> listBackups(Map<String, String> headers) async {
    final query = Uri(
      queryParameters: <String, String>{
        'spaces': 'appDataFolder',
        'q': "name contains '$namePrefix' and trashed = false",
        'fields': 'files(id,name,createdTime,size)',
        'orderBy': 'createdTime desc',
        'pageSize': '20',
      },
    ).query;
    final response = await _client.get(
      Uri.parse('$filesEndpoint?$query'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'تعذر قراءة قائمة النسخ من درايف',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    final files = (body is Map ? body['files'] : null);
    if (files is! List) return const [];
    return files
        .whereType<Map>()
        .map((raw) {
          return DriveBackupFile(
            id: raw['id']?.toString() ?? '',
            name: raw['name']?.toString() ?? '',
            createdTime: DateTime.tryParse(
              raw['createdTime']?.toString() ?? '',
            ),
            sizeBytes: int.tryParse(raw['size']?.toString() ?? ''),
          );
        })
        .where((file) => file.id.isNotEmpty)
        .toList();
  }

  Future<DriveBackupFile> uploadBackup(
    Map<String, String> headers,
    List<int> bytes,
    String name,
  ) async {
    const boundary = 'bouga_backup_7f3d9a1c';
    final metadata = jsonEncode(<String, Object?>{
      'name': name,
      'parents': <String>['appDataFolder'],
    });
    final body = <int>[
      ...utf8.encode(
        '--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$metadata\r\n',
      ),
      ...utf8.encode('--$boundary\r\nContent-Type: application/json\r\n\r\n'),
      ...bytes,
      ...utf8.encode('\r\n--$boundary--'),
    ];
    final response = await _client.post(
      Uri.parse(
        '$uploadEndpoint?uploadType=multipart&fields=id,name,createdTime,size',
      ),
      headers: <String, String>{
        ...headers,
        'Content-Type': 'multipart/related; boundary=$boundary',
      },
      body: body,
    );
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'تعذر رفع النسخة إلى درايف',
        statusCode: response.statusCode,
      );
    }
    final raw = jsonDecode(response.body);
    return DriveBackupFile(
      id: raw is Map ? raw['id']?.toString() ?? '' : '',
      name: name,
      createdTime: DateTime.tryParse(
        raw is Map ? raw['createdTime']?.toString() ?? '' : '',
      ),
      sizeBytes: bytes.length,
    );
  }

  Future<List<int>> downloadBackup(
    Map<String, String> headers,
    String id,
  ) async {
    final response = await _client.get(
      Uri.parse('$filesEndpoint/$id?alt=media'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw DriveBackupException(
        'تعذر تنزيل النسخة من درايف',
        statusCode: response.statusCode,
      );
    }
    return response.bodyBytes;
  }
}
