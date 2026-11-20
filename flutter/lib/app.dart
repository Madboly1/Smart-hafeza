import 'package:material_ui/material_ui.dart';

import 'core/theme/bouga_theme.dart';
import 'features/home/presentation/home_page.dart';

class BougaApp extends StatelessWidget {
  const BougaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BOUGA | بُؤجة',
      debugShowCheckedModeBanner: false,
      theme: BougaTheme.dark,
      home: const HomePage(),
    );
  }
}
