import 'package:bouga/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BOUGA application starts', (tester) async {
    await tester.pumpWidget(const BougaApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('BOUGA'), findsOneWidget);
  });
}
