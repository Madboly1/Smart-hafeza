import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'update_service.dart';

class AndroidUpdateService {
  AndroidUpdateService(
      {http.Client? client, Future<Directory> Function()? temporaryDirectory})
      : _client = client,
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory;
  final http.Client? _client;
  final Future<Directory> Function() _temporaryDirectory;
  static const _channel = MethodChannel('bouga/updates');
  static const _downloadHost = 'github.com';
  static const _releaseRoot =
      'https://github.com/Madboly1/Smart-hafeza/releases/latest/download/';

  Future<UpdateCheckResult> check() async {
    try {
      final installed =
          await _channel.invokeMapMethod<String, Object?>('installed');
      final abi = installed?['abi'];
      final code = installed?['versionCode'];
      if (code is! int ||
          !['arm64-v8a', 'armeabi-v7a', 'x86_64'].contains(abi)) {
        return const UpdateCheckResult(UpdateStatus.temporarilyUnavailable);
      }
      return await UpdateService(
              manifestUrl: '${_releaseRoot}update-$abi.json',
              currentVersionCode: code)
          .checkForUpdate();
    } catch (_) {
      return const UpdateCheckResult(UpdateStatus.temporarilyUnavailable);
    }
  }

  Future<void> downloadAndInstall(
      UpdateManifest manifest, void Function(double?) onProgress) async {
    final uri = manifest.apkUrl;
    if (uri.scheme != 'https' ||
        uri.host != _downloadHost ||
        !uri.path.startsWith('/Madboly1/Smart-hafeza/releases/download/')) {
      throw const FormatException('مصدر التحديث غير موثوق.');
    }
    final dir =
        Directory('${(await _temporaryDirectory()).path}/bouga_updates');
    await dir.create(recursive: true);
    final part = File('${dir.path}/update.part');
    final apk = File('${dir.path}/bouga-${manifest.versionCode}.apk');
    final client = _client ?? http.Client();
    IOSink? sink;
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        throw const HttpException('تعذر تنزيل التحديث.');
      }
      final total = response.contentLength;
      var received = 0;
      sink = part.openWrite();
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 25))) {
        received += chunk.length;
        if (received > 100 * 1024 * 1024) {
          throw const FormatException('حجم التحديث غير صالح.');
        }
        sink.add(chunk);
        onProgress(total == null ? null : received / total);
      }
      await sink.close();
      sink = null;
      if (total != null && received != total) {
        throw const HttpException('التنزيل غير مكتمل.');
      }
      final digest = await sha256.bind(part.openRead()).first;
      if (digest.toString() != manifest.sha256) {
        throw const FormatException('فشل التحقق من سلامة ملف التحديث.');
      }
      if (await apk.exists()) await apk.delete();
      await part.rename(apk.path);
      await _channel.invokeMethod<bool>('install', {'path': apk.path});
    } finally {
      await sink?.close();
      client.close();
      if (await part.exists()) await part.delete();
    }
  }
}
