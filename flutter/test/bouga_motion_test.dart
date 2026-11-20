import 'package:bouga/core/theme/bouga_motion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('ink clip starts empty and ends with full content coverage', () {
    const size = Size(420, 900);
    expect(const BougaInkClipper(0).getClip(size).getBounds().isEmpty, isTrue);
    final full = const BougaInkClipper(1).getClip(size);
    expect(full.getBounds(), Offset.zero & size);
    final middle = const BougaInkClipper(.2).getClip(size);
    expect(middle.contains(const Offset(319, 252)), isTrue);
    expect(middle.contains(const Offset(0, 899)), isFalse);
  });
  testWidgets('reduced motion reveals full page immediately', (tester) async {
    const animation = AlwaysStoppedAnimation<double>(.2);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child:
                BougaInkReveal(animation: animation, child: Text('content')))));
    expect(find.byType(ClipPath), findsNothing);
    expect(find.text('content'), findsOneWidget);
  });
  testWidgets('short route reveal and back retain navigation', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(bougaInkRoute<void>(
                    (_) => const Scaffold(body: Text('next')))),
                child: const Text('open')))));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.byType(BougaInkReveal), findsWidgets);
    expect(
        find.descendant(
            of: find.byType(BougaInkReveal),
            matching: find.byType(SlideTransition)),
        findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('next'), findsOneWidget);
    Navigator.of(tester.element(find.text('next'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
