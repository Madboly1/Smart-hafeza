import 'package:bouga/features/settings/presentation/settings_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('backup export action invokes the supplied local export callback',
      (tester) async {
    var exports = 0;
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        onImportBackup: () async {},
        onExportBackup: () async {
          exports++;
        },
      ),
    ));

    await tester.tap(find.text('تصدير نسخة احتياطية'));
    await tester.pump();

    expect(exports, 1);
  });

  testWidgets('cancelled export does not show a success message',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsPage(
        onImportBackup: () async {},
        onExportBackup: () async {},
      ),
    ));

    await tester.tap(find.text('تصدير نسخة احتياطية'));
    await tester.pump();

    expect(find.text('تم حفظ النسخة الاحتياطية بنجاح.'), findsNothing);
  });
}
