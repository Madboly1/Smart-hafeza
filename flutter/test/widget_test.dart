import 'package:flutter/services.dart';
import 'package:bouga/app.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BOUGA application starts', (tester) async {
    await tester.pumpWidget(const BougaApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('بُؤجة'), findsOneWidget);
  });
  testWidgets('root back prompts then exits', (tester) async {
    var exits = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    await tester.pumpWidget(const BougaApp());
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('اضغط رجوع مرة كمان للخروج'), findsOneWidget);
    expect(exits, 0);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(exits, 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
}
