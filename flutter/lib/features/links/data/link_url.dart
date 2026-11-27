/// Canonicalizes a saved web link so the same page stored in different
/// shapes (mobile host, youtu.be short form, tracking fragment, trailing
/// slash) is recognized as one link.
library;

/// Returns the canonical form of [raw], or the trimmed input when it is
/// not an http(s) URL.
String normalizeLinkUrl(String raw) {
  final trimmed = raw.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      !uri.hasAuthority ||
      uri.host.isEmpty ||
      !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return trimmed;
  }
  final scheme = uri.scheme.toLowerCase();
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) host = host.substring(4);
  if (host.startsWith('m.') && host.length > 2) host = host.substring(2);
  var segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
  var query = uri.query.isEmpty ? null : uri.query;

  // youtu.be/<id> is the same page as youtube.com/watch?v=<id>.
  if (host == 'youtu.be' && segments.isNotEmpty) {
    final id = segments.first;
    host = 'youtube.com';
    segments = ['watch'];
    query = 'v=${Uri.encodeQueryComponent(id)}';
  }
  final defaultPort = (scheme == 'https' && uri.port == 443) ||
      (scheme == 'http' && uri.port == 80);
  final normalized = Uri(
    scheme: scheme,
    host: host,
    port: uri.hasPort && !defaultPort ? uri.port : null,
    pathSegments: segments,
    query: query,
  );
  return normalized.toString();
}

/// Candidate stored values that all refer to the same page as [raw].
/// Used for duplicate detection against rows saved before normalization.
List<String> linkUrlKeys(String raw) {
  final trimmed = raw.trim();
  final keys = <String>{trimmed};
  final normalized = normalizeLinkUrl(raw);
  keys.add(normalized);

  final uri = Uri.tryParse(normalized);
  if (uri != null && uri.hasAuthority) {
    // Legacy rows may carry the www. host.
    keys.add(Uri(
      scheme: uri.scheme,
      host: 'www.${uri.host}',
      port: uri.hasPort ? uri.port : null,
      pathSegments: uri.pathSegments,
      query: uri.query.isEmpty ? null : uri.query,
    ).toString());
    // Legacy rows may carry the youtu.be short form of a watch URL.
    if (uri.host == 'youtube.com' &&
        uri.pathSegments.length == 1 &&
        uri.pathSegments.single == 'watch') {
      final id = uri.queryParameters['v'];
      if (id != null && id.isNotEmpty && uri.queryParameters.length == 1) {
        keys.add('https://youtu.be/$id');
        keys.add('https://www.youtube.com/watch?v=$id');
      }
    }
  }
  return keys.toList();
}
