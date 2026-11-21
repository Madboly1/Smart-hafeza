import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Optional Google sign-in used only for the personal Drive backup.
/// The app works fully without it, and sign-out never touches local data.
class BougaAccount {
  BougaAccount._();

  static final BougaAccount instance = BougaAccount._();

  static const List<String> driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  /// Web OAuth client ID from the Bouga Google Cloud project. Required by
  /// Credential Manager on Android as the server client ID. Not a secret.
  /// TODO(cloud-setup): fill in once the OAuth client exists.
  static const String serverClientId =
      '366688917615-9eeh8k271moo7vsnumqb11r1fiebu9ba.apps.googleusercontent.com';

  static bool get configured => serverClientId.isNotEmpty;

  final ValueNotifier<GoogleSignInAccount?> currentUser =
      ValueNotifier<GoogleSignInAccount?>(null);

  bool _initialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  Future<void> initialize() async {
    if (!configured || _initialized) return;
    _initialized = true;
    final signIn = GoogleSignIn.instance;
    await signIn.initialize(serverClientId: serverClientId);
    _subscription = signIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          currentUser.value = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          currentUser.value = null;
        }
      },
      // Auth failures also surface on this stream; without onError they
      // reach the zone as unhandled. The awaited paths report errors already.
      onError: (_) {},
    );
    final lightweight = signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      unawaited(lightweight.catchError((_) => null));
    }
  }

  /// Returns null on success, 'canceled' when the user dismisses the flow,
  /// or a short error description otherwise.
  Future<String?> signIn() async {
    try {
      final account = await GoogleSignIn.instance.authenticate();
      currentUser.value = account;
      return null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return 'canceled';
      return error.description ?? error.code.name;
    }
  }

  /// Signs out only. Local data and previous Drive backups stay untouched.
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    currentUser.value = null;
  }

  /// Authorization headers carrying a Drive access token. Identity sign-in
  /// stays separate from Drive authorization: the first backup asks for the
  /// Drive permission explicitly.
  Future<Map<String, String>?> driveHeaders({bool promptIfNeeded = false}) {
    final account = currentUser.value;
    if (account == null) return Future.value();
    try {
      return account.authorizationClient.authorizationHeaders(
        driveScopes,
        promptIfNecessary: promptIfNeeded,
      );
    } on GoogleSignInException {
      return Future.value();
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}
