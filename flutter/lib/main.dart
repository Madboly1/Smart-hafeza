import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'features/account/data/bouga_account.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(BougaAccount.instance.initialize().catchError((_) {}));
  runApp(const BougaApp());
}
