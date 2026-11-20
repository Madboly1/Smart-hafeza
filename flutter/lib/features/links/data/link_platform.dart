/// Classifies by the URL host only. Titles and paths cannot spoof a platform.
String linkPlatform(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.contains('@') ||
      (Uri.tryParse(text)?.hasScheme == true && !text.contains('://'))) {
    return 'أخرى';
  }
  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty) {
    return 'أخرى';
  }
  final host = uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  const platforms = {
    'YouTube': ['youtube.com', 'youtu.be', 'youtube-nocookie.com'],
    'TikTok': ['tiktok.com'],
    'Instagram': ['instagram.com', 'instagr.am'],
    'Facebook': ['facebook.com', 'fb.com', 'fb.watch'],
    'X / Twitter': ['x.com', 'twitter.com', 't.co'],
    'Telegram': ['t.me', 'telegram.me', 'telegram.org'],
    'WhatsApp': ['whatsapp.com', 'wa.me'],
    'Pinterest': ['pinterest.com', 'pin.it'],
    'LinkedIn': ['linkedin.com', 'lnkd.in'],
    'Reddit': ['reddit.com', 'redd.it'],
    'Snapchat': ['snapchat.com'],
  };
  for (final entry in platforms.entries) {
    if (entry.value
        .any((domain) => host == domain || host.endsWith('.$domain'))) {
      return entry.key;
    }
  }
  // Unlisted sites stay together, keeping the platform picker compact.
  return 'أخرى';
}

List<String> savedPlatforms(Iterable<Map<String, Object?>> links) {
  final result =
      links.map((link) => linkPlatform(link['url'])).toSet().toList();
  result.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return result;
}

List<Map<String, Object?>> filterPlatform(
        List<Map<String, Object?>> links, String? platform) =>
    platform == null
        ? links
        : links.where((link) => linkPlatform(link['url']) == platform).toList();
