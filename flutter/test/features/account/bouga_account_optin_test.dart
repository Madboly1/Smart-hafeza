import 'dart:io';

import 'package:bouga/features/account/data/bouga_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _FakeAccount implements GoogleSignInAccount {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('bouga-optin-test');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  GoogleSignInOptIn optIn() => GoogleSignInOptIn(directory: () async => dir);

  test('fresh install: startup never attempts lightweight auth', () async {
    var calls = 0;
    final acc = BougaAccount.test(
      optIn: optIn(),
      lightweightAttempt: () async {
        calls++;
        return null;
      },
    );
    await acc.initialize();
    expect(calls, 0);
    expect(acc.currentUser.value, isNull);
    await acc.dispose();
  });

  test('previous explicit sign-in restores silently at startup', () async {
    final marker = optIn();
    await marker.mark();
    var calls = 0;
    final acc = BougaAccount.test(
      optIn: marker,
      lightweightAttempt: () async {
        calls++;
        return null;
      },
    );
    await acc.initialize();
    expect(calls, 1);
    await acc.dispose();
  });

  test('interactive sign-in marks the opt-in for later launches', () async {
    final marker = optIn();
    final fake = _FakeAccount();
    final acc = BougaAccount.test(
      optIn: marker,
      authenticator: () async => fake,
    );
    expect(await marker.chosen, isFalse);
    final result = await acc.signIn();
    expect(result, isNull);
    expect(acc.currentUser.value, same(fake));
    expect(await marker.chosen, isTrue);
    await acc.dispose();
  });

  test('sign-out clears the opt-in and startup stays silent again', () async {
    final marker = optIn();
    var calls = 0;
    final acc = BougaAccount.test(
      optIn: marker,
      authenticator: () async => _FakeAccount(),
      signOutAction: () async {},
    );
    await acc.signIn();
    expect(await marker.chosen, isTrue);
    await acc.signOut();
    expect(acc.currentUser.value, isNull);
    expect(await marker.chosen, isFalse);

    final after = BougaAccount.test(
      optIn: marker,
      lightweightAttempt: () async {
        calls++;
        return null;
      },
    );
    await after.initialize();
    expect(calls, 0);
    await after.dispose();
  });
}
