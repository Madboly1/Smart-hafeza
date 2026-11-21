import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';

/// Optional Google sign-in used only for the personal Drive backup.
/// The app works fully without it, and sign-out never touches local data.
class BougaAccount {
  BougaAccount._({
    GoogleSignInOptIn? optIn,
    Future<void> Function()? initializer,
    Future<GoogleSignInAccount?>? Function()? lightweightAttempt,
    Future<GoogleSignInAccount> Function()? authenticator,
    Future<void> Function()? signOutAction,
  })  : _optIn = optIn ?? GoogleSignInOptIn(),
        _initializer = initializer ??
            (() => GoogleSignIn.instance.initialize(
                  serverClientId: serverClientId,
                )),
        _lightweightAttempt = lightweightAttempt ??
            (() => GoogleSignIn.instance.attemptLightweightAuthentication()),
        _authenticator =
            authenticator ?? (() => GoogleSignIn.instance.authenticate()),
        _signOutAction =
            signOutAction ?? (() => GoogleSignIn.instance.signOut());

  static final BougaAccount instance = BougaAccount._();

  static const List<String> driveScopes = <String>[
    'https://www.googleapis.com/auth/drive.appdata',
  ];

  /// Web OAuth client ID from the Bouga Google Cloud project. Required by
  /// Credential Manager on Android as the server client ID. Not a secret.
  static const String serverClientId =
      '366688917615-9eeh8k271moo7vsnumqb11r1fiebu9ba.apps.googleusercontent.com';

  static bool get configured => serverClientId.isNotEmpty;

  final ValueNotifier<GoogleSignInAccount?> currentUser =
      ValueNotifier<GoogleSignInAccount?>(null);

  final GoogleSignInOptIn _optIn;
  final Future<void> Function() _initializer;
  final Future<GoogleSignInAccount?>? Function() _lightweightAttempt;
  final Future<GoogleSignInAccount> Function() _authenticator;
  final Future<void> Function() _signOutAction;

  bool _initialized = false;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @visibleForTesting
  factory BougaAccount.test({
    GoogleSignInOptIn? optIn,
    Future<void> Function()? initializer,
    Future<GoogleSignInAccount?>? Function()? lightweightAttempt,
    Future<GoogleSignInAccount> Function()? authenticator,
    Future<void> Function()? signOutAction,
  }) {
    return BougaAccount._(
      optIn: optIn ?? GoogleSignInOptIn(directory: _missingDirectory),
      initializer: initializer ?? (() async {}),
      lightweightAttempt: lightweightAttempt ?? (() async => null),
      authenticator: authenticator ??
          (() async => throw StateError('no test authenticator provided')),
      signOutAction: signOutAction ?? (() async {}),
    );
  }

  static Future<Directory> _missingDirectory() =>
      Future<Directory>.error(StateError('no test directory provided'));

  Future<void> initialize() async {
    if (!configured || _initialized) return;
    _initialized = true;
    final signIn = GoogleSignIn.instance;
    await _initializer();
    _subscription = attachAuthenticationEvents(
      signIn.authenticationEvents,
      currentUser,
    );
    // attemptLightweightAuthentication may show One Tap UI on Android, so
    // a fresh install or a signed-out user must never reach it. It runs
    // only after the user has explicitly signed in once inside Bouga, and
    // sign-out clears that choice again.
    if (!await _optIn.chosen) return;
    final lightweight = _lightweightAttempt();
    if (lightweight != null) {
      unawaited(lightweight.catchError((_) => null));
    }
  }

  /// Applies authentication events to [currentUser]. Auth failures also
  /// surface on this stream (google_sign_in forwards them via addError),
  /// so onError swallows them: the awaited paths already report errors to
  /// the UI, and an unhandled stream error would reach the zone as an
  /// unhandled exception.
  @visibleForTesting
  static StreamSubscription<GoogleSignInAuthenticationEvent>
      attachAuthenticationEvents(
    Stream<GoogleSignInAuthenticationEvent> events,
    ValueNotifier<GoogleSignInAccount?> currentUser,
  ) {
    return events.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          currentUser.value = event.user;
        } else if (event is GoogleSignInAuthenticationEventSignOut) {
          currentUser.value = null;
        }
      },
      onError: (_) {},
    );
  }

  /// Returns null on success, 'canceled' when the user dismisses the flow,
  /// or a short error description otherwise. A completed sign-in is also
  /// the explicit opt-in that allows silent session restore on later
  /// launches.
  Future<String?> signIn() async {
    try {
      final account = await _authenticator();
      currentUser.value = account;
      await _optIn.mark();
      return null;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return 'canceled';
      return error.description ?? error.code.name;
    } catch (error) {
      return error.toString();
    }
  }

  /// Signs out only. Local data and previous Drive backups stay untouched.
  /// Also clears the sign-in opt-in, so later launches stay silent again.
  Future<void> signOut() async {
    await _signOutAction();
    await _optIn.clear();
    currentUser.value = null;
  }

  /// Authorization headers carrying a Drive access token. Identity sign-in
  /// stays separate from Drive authorization: the first backup asks for the
  /// Drive permission explicitly.
  Future<Map<String, String>?> driveHeaders({bool promptIfNeeded = false}) async {
    final account = currentUser.value;
    if (account == null) return null;
    try {
      return await account.authorizationClient.authorizationHeaders(
        driveScopes,
        promptIfNecessary: promptIfNeeded,
      );
    } on GoogleSignInException {
      return null;
    }
  }

  Future<void> dispose() async => _subscription?.cancel();
}

/// Records whether the user has ever chosen to sign in with Google inside
/// Bouga. A plain file in the app documents directory, following the same
/// local-flag pattern as the onboarding tour. The flag contains no account
/// data; its existence is the whole signal.
class GoogleSignInOptIn {
  GoogleSignInOptIn({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;

  static const String _fileName = 'google-signin-v1.optin';

  final Future<Directory> Function() _directory;

  Future<File> get _flag async =>
      File('${(await _directory()).path}/$_fileName');

  Future<bool> get chosen async {
    try {
      return await (await _flag).exists();
    } catch (_) {
      return false;
    }
  }

  Future<void> mark() async {
    try {
      await (await _flag).writeAsString('1\n');
    } catch (_) {
      // A lost flag only means the next launch skips silent restore.
    }
  }

  Future<void> clear() async {
    try {
      final flag = await _flag;
      if (flag.existsSync()) await flag.delete();
    } catch (_) {
      // Same reasoning as mark().
    }
  }
}
