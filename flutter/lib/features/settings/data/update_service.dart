import 'dart:convert';

import 'package:http/http.dart' as http;

class UpdateConfig {
  // The final manifest URL will be selected when the distribution channel is decided.
  static const String manifestUrl = 'https://example.invalid/update.json';
  static const int currentVersionCode = 1;
}

enum UpdateStatus {
  noUpdate,
  updateAvailable,
  temporarilyUnavailable,
}

class UpdateManifest {
  const UpdateManifest({
    required this.versionCode,
    required this.versionName,
    required this.releaseMessage,
    required this.apkUrl,
    required this.sha256,
    this.minSupportedVersion,
    this.mandatory = false,
  });

  final int versionCode;
  final String versionName;
  final String releaseMessage;
  final Uri apkUrl;
  final String sha256;
  final int? minSupportedVersion;
  final bool mandatory;

  factory UpdateManifest.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Manifest must be a JSON object.');
    }

    final versionCode = value['versionCode'];
    final versionName = value['versionName'];
    final releaseMessage = value['releaseMessage'];
    final apkUrlValue = value['apkUrl'];
    final sha256 = value['sha256'];
    final minSupportedVersion = value['minSupportedVersion'];
    final mandatory = value['mandatory'];

    if (versionCode is! int || versionCode < 1 ||
        versionName is! String || versionName.trim().isEmpty ||
        releaseMessage is! String || releaseMessage.trim().isEmpty ||
        apkUrlValue is! String || sha256 is! String ||
        !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(sha256) ||
        (minSupportedVersion != null &&
            (minSupportedVersion is! int || minSupportedVersion < 1)) ||
        (mandatory != null && mandatory is! bool)) {
      throw const FormatException('Manifest fields are missing or invalid.');
    }

    final apkUrl = Uri.tryParse(apkUrlValue);
    if (apkUrl == null || apkUrl.scheme != 'https' || !apkUrl.hasAuthority) {
      throw const FormatException('APK URL must be a valid HTTPS URL.');
    }

    return UpdateManifest(
      versionCode: versionCode,
      versionName: versionName,
      releaseMessage: releaseMessage,
      apkUrl: apkUrl,
      sha256: sha256.toLowerCase(),
      minSupportedVersion: minSupportedVersion as int?,
      mandatory: mandatory as bool? ?? false,
    );
  }
}

class UpdateCheckResult {
  const UpdateCheckResult(this.status, {this.manifest});

  final UpdateStatus status;
  final UpdateManifest? manifest;
}

typedef ManifestLoader = Future<String> Function(Uri uri);

class UpdateService {
  UpdateService({
    this.manifestUrl = UpdateConfig.manifestUrl,
    this.currentVersionCode = UpdateConfig.currentVersionCode,
    ManifestLoader? loader,
  }) : _loader = loader ?? _loadManifest;

  final String manifestUrl;
  final int currentVersionCode;
  final ManifestLoader _loader;

  static Future<String> _loadManifest(Uri uri) async {
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Manifest request failed: ${response.statusCode}');
    }
    return response.body;
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final uri = Uri.parse(manifestUrl);
      if (uri.scheme != 'https' || !uri.hasAuthority) {
        throw const FormatException('Manifest URL must use HTTPS.');
      }
      final source = await _loader(uri);
      final decoded = jsonDecode(source);
      final manifest = UpdateManifest.fromJson(decoded);
      if (manifest.versionCode <= currentVersionCode) {
        return const UpdateCheckResult(UpdateStatus.noUpdate);
      }
      return UpdateCheckResult(
        UpdateStatus.updateAvailable,
        manifest: manifest,
      );
    } catch (_) {
      return const UpdateCheckResult(UpdateStatus.temporarilyUnavailable);
    }
  }
}
