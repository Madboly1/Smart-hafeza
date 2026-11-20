import 'dart:io';
import 'package:bouga/features/onboarding/presentation/bouga_tour.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('tour dismissal persists independently, never touches library files',
      () async {
    final dir = await Directory.systemTemp.createTemp('bouga-tour-test');
    final library = File('${dir.path}/bouga.db');
    await library.writeAsString('unchanged');
    final store = BougaTourStore(directory: () async => dir);
    expect(await store.seen, isFalse);
    await store.complete();
    expect(await store.seen, isTrue);
    expect(await library.readAsString(), 'unchanged');
    await dir.delete(recursive: true);
  });
  for (final width in [320.0, 420.0]) {
    testWidgets(
        'spotlight blocks target effects and offers skip/finish at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 750);
      tester.view.devicePixelRatio = 1;
      final target = GlobalKey();
      var targetTaps = 0;
      bool? result;
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: Column(children: [
                    TextButton(
                        onPressed: () async {
                          result = await showBougaTourStep(context,
                              target: target,
                              title: 'عنوان الشرح',
                              text: 'شرح واضح للهدف الفعلي',
                              step: 1,
                              total: 1,
                              last: true);
                        },
                        child: const Text('ابدأ')),
                    const SizedBox(height: 100),
                    FilledButton(
                        key: target,
                        onPressed: () => targetTaps++,
                        child: const Text('هدف فعلي')),
                  ])))));
      await tester.tap(find.text('ابدأ'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('عنوان الشرح'), findsOneWidget);
      expect(find.text('إنهاء'), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.text('هدف فعلي')));
      await tester.pump();
      expect(targetTaps, 0);
      await tester.tap(find.text('إنهاء'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      await tester.tap(find.text('ابدأ'));
      await tester.pump();
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.tap(find.text('تخطّي الجولة'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(tester.takeException(), isNull);
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }
}
