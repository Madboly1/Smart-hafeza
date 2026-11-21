import 'dart:async';

import 'package:bouga/features/account/data/bouga_account.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeAccount implements GoogleSignInAccount {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  test('stream auth errors are swallowed and keep signed-out state', () async {
    // If the listener had no onError, addError below would surface as an
    // unhandled async error and flutter_test would fail this test.
    final controller = StreamController<GoogleSignInAuthenticationEvent>();
    final user = ValueNotifier<GoogleSignInAccount?>(null);
    final sub = BougaAccount.attachAuthenticationEvents(
      controller.stream,
      user,
    );

    controller.addError(Exception('provider configuration missing'));
    await Future<void>.delayed(Duration.zero);

    expect(user.value, isNull);
    await sub.cancel();
    await controller.close();
  });

  test('sign-in, duplicate sign-in, then sign-out drive currentUser', () async {
    final controller = StreamController<GoogleSignInAuthenticationEvent>();
    final user = ValueNotifier<GoogleSignInAccount?>(null);
    final sub = BougaAccount.attachAuthenticationEvents(
      controller.stream,
      user,
    );
    final account = _FakeAccount();

    controller.add(GoogleSignInAuthenticationEventSignIn(user: account));
    await Future<void>.delayed(Duration.zero);
    expect(user.value, same(account));

    controller.add(GoogleSignInAuthenticationEventSignIn(user: account));
    await Future<void>.delayed(Duration.zero);
    expect(user.value, same(account));

    controller.add(GoogleSignInAuthenticationEventSignOut());
    await Future<void>.delayed(Duration.zero);
    expect(user.value, isNull);

    await sub.cancel();
    await controller.close();
  });

  test('stream error after sign-in does not clear the current user', () async {
    final controller = StreamController<GoogleSignInAuthenticationEvent>();
    final user = ValueNotifier<GoogleSignInAccount?>(null);
    final sub = BougaAccount.attachAuthenticationEvents(
      controller.stream,
      user,
    );
    final account = _FakeAccount();

    controller.add(GoogleSignInAuthenticationEventSignIn(user: account));
    await Future<void>.delayed(Duration.zero);
    controller.addError(Exception('transient provider failure'));
    await Future<void>.delayed(Duration.zero);

    expect(user.value, same(account));
    await sub.cancel();
    await controller.close();
  });
}
