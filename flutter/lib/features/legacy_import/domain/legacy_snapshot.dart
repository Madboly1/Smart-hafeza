import 'dart:convert';

class LegacySnapshot {
  const LegacySnapshot({required this.links, required this.categories});

  final List<LegacyLink> links;
  final List<String> categories;

  factory LegacySnapshot.fromJson(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Legacy export must be a JSON object.');
    }

    final rawLinks = decoded['links'];
    final rawCategories = decoded['cats'];
    if (rawLinks != null && rawLinks is! List) {
      throw const FormatException('Legacy links must be a list.');
    }
    if (rawCategories != null && rawCategories is! List) {
      throw const FormatException('Legacy categories must be a list.');
    }

    final categories = <String>[];
    for (final item in (rawCategories as List? ?? const [])) {
      if (item is String &&
          item.trim().isNotEmpty &&
          !categories.contains(item.trim())) {
        categories.add(item.trim());
      }
    }
    if (!categories.contains('أخرى')) categories.add('أخرى');

    final links = <LegacyLink>[];
    for (final item in (rawLinks as List? ?? const [])) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString().trim() ?? '';
      final url = map['url']?.toString().trim() ?? '';
      if (id.isEmpty || url.isEmpty) continue;
      final category = map['c']?.toString().trim();
      if (category == null || category.isEmpty) {
        map['c'] = 'أخرى';
      } else if (!categories.contains(category)) {
        categories.add(category);
      }
      map['p'] = _progress(map['p']);
      map['seen'] = _timestamp(map['seen']);
      map['title'] ??= '';
      map['note'] ??= '';
      map['k'] ??= 'مقال';
      links.add(LegacyLink.fromMap(map));
    }

    return LegacySnapshot(links: links, categories: categories);
  }

  static int _progress(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return parsed.clamp(0, 100).toInt();
  }

  static int _timestamp(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    return parsed ?? 0;
  }
}

class LegacyLink {
  const LegacyLink({required this.id, required this.url, required this.fields});

  final String id;
  final String url;

  /// Includes known legacy fields and every unknown field for lossless migration.
  final Map<String, dynamic> fields;

  factory LegacyLink.fromMap(Map<String, dynamic> map) => LegacyLink(
        id: map['id'].toString(),
        url: map['url'].toString(),
        fields: Map.unmodifiable(map),
      );
}
