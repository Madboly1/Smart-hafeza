import 'package:flutter_test/flutter_test.dart';
import 'package:bouga/features/legacy_import/domain/legacy_snapshot.dart';

void main() {
  group('LegacySnapshot', () {
    test('imports the documented hl schema and applies safe defaults', () {
      final snapshot = LegacySnapshot.fromJson('''
        {"links":[{"id":7,"url":"https://example.com","p":"55"}],
         "cats":["مونتاج","رياضة"]}
      ''');

      expect(snapshot.links, hasLength(1));
      expect(snapshot.links.single.id, '7');
      expect(snapshot.links.single.fields['p'], 55);
      expect(snapshot.links.single.fields['c'], 'أخرى');
      expect(snapshot.links.single.fields['seen'], 0);
      expect(snapshot.categories, containsAll(['مونتاج', 'رياضة', 'أخرى']));
    });

    test('preserves unknown fields without data loss', () {
      final snapshot = LegacySnapshot.fromJson('''
        {"links":[{"id":"a1","url":"https://example.com",
          "futureField":{"nested":true},"customFlag":9}],"cats":[]}
      ''');

      expect(snapshot.links.single.fields['futureField'], {'nested': true});
      expect(snapshot.links.single.fields['customFlag'], 9);
    });

    test('normalizes progress and category values', () {
      final snapshot = LegacySnapshot.fromJson('''
        {"links":[
          {"id":"one","url":"https://one.test","p":140,"c":"جديدة"},
          {"id":"two","url":"https://two.test","p":-4}
        ],"cats":[" مونتاج ","مونتاج"]}
      ''');

      expect(snapshot.links[0].fields['p'], 100);
      expect(snapshot.links[0].fields['c'], 'جديدة');
      expect(snapshot.links[1].fields['p'], 0);
      expect(snapshot.categories, ['مونتاج', 'أخرى', 'جديدة']);
    });

    test('skips invalid rows but rejects malformed top-level data', () {
      final snapshot = LegacySnapshot.fromJson('''
        {"links":[null,{"id":"","url":"https://bad.test"},
          {"id":"ok","url":"https://ok.test"}],"cats":[]}
      ''');
      expect(snapshot.links, hasLength(1));
      expect(() => LegacySnapshot.fromJson('[]'), throwsFormatException);
      expect(() => LegacySnapshot.fromJson('{"links":{},"cats":[]}'),
          throwsFormatException);
    });

    test('does not mutate the source map', () {
      final snapshot = LegacySnapshot.fromJson('''
        {"links":[{"id":"x","url":"https://x.test","p":25}],"cats":[]}
      ''');
      expect(snapshot.links.single.fields['p'], 25);
    });
  });
}
