import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Receives text only. A share is never opened or saved without user review.
class IncomingShareService {
  IncomingShareService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('bouga/incoming_share');

  final MethodChannel _channel;
  bool _disposed = false;
  bool _draining = false;
  bool _again = false;
  void Function(String)? _onText;

  Future<void> start(void Function(String) onText) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    _onText = onText;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'available') await _drain();
    });
    await _drain();
  }

  Future<void> _drain() async {
    if (_disposed) return;
    if (_draining) {
      _again = true;
      return;
    }
    _draining = true;
    try {
      do {
        _again = false;
        final values = await _channel.invokeListMethod<String>('takePending');
        if (_disposed) return;
        for (final value in values ?? <String>[]) {
          _onText?.call(value);
        }
      } while (_again);
    } on MissingPluginException {
      // Other platform runners do not expose the Android adapter.
    } on PlatformException {
      // Do not interrupt the library if a platform share cannot be read.
    } finally {
      _draining = false;
    }
  }

  void dispose() {
    _disposed = true;
    _onText = null;
    _channel.setMethodCallHandler(null);
  }

  static String? firstWebUrl(String text) {
    final matches = RegExp(r'https?://[^\s<>"\x00-\x1f]+', caseSensitive: false)
        .allMatches(text);
    for (final match in matches) {
      var candidate = match.group(0)!;
      candidate = candidate.replaceFirst(RegExp(r'[.,;!،؛؟]+$'), '');
      while (candidate.endsWith(')') &&
          ')'.allMatches(candidate).length > '('.allMatches(candidate).length) {
        candidate = candidate.substring(0, candidate.length - 1);
      }
      final uri = Uri.tryParse(candidate);
      if (uri != null &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty) {
        return candidate;
      }
    }
    return null;
  }
}
