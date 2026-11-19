import '../../legacy_import/data/bouga_database.dart';

class BougaLinksRepository {
  BougaLinksRepository(this.database);

  final BougaDatabase database;

  Future<List<Map<String, Object?>>> list({String query = '', String? category}) =>
      database.getLinks(query: query, category: category);

  Future<List<String>> categories() => database.getCategories();

  Future<int> add({
    required String url,
    required String title,
    required String category,
    required String kind,
  }) => database.addLink(url: url, title: title, category: category, kind: kind);

  Future<void> update({
    required String id,
    required String title,
    required String category,
    required String note,
    required int progress,
  }) => database.updateLink(
    id: id, title: title, category: category, note: note, progress: progress,
  );

  Future<void> delete(String id) => database.deleteLink(id);

  Future<int> count() => database.countLinks();
}
