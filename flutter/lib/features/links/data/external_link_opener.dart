import 'package:url_launcher/url_launcher.dart';

enum LinkOpenResult { opened, invalidUrl, launchFailed }

typedef ExternalUrlLauncher = Future<bool> Function(Uri uri);

class ExternalLinkOpener {
  ExternalLinkOpener({ExternalUrlLauncher? launcher})
      : _launcher = launcher ?? _launchExternally;

  final ExternalUrlLauncher _launcher;

  static Future<bool> _launchExternally(Uri uri) => launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

  Future<LinkOpenResult> open(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        !uri.hasAuthority ||
        uri.host.trim().isEmpty) {
      return LinkOpenResult.invalidUrl;
    }

    try {
      return await _launcher(uri)
          ? LinkOpenResult.opened
          : LinkOpenResult.launchFailed;
    } catch (_) {
      return LinkOpenResult.launchFailed;
    }
  }
}
