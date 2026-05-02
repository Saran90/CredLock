import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'key_derivation_service.dart';

/// Manages Google Sign-In session lifecycle.
/// Call [init] once at app startup to silently restore any existing session.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';

  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile', _driveAppDataScope],
  );

  GoogleSignInAccount? _currentUser;

  /// Returns true if a valid session is currently active.
  bool get isSignedIn => _currentUser != null;

  /// The signed-in account, or null if not signed in.
  GoogleSignInAccount? get currentUser => _currentUser;

  /// Initialise at app startup. Silently restores session if available.
  /// Never throws — errors are caught so [isSignedIn] remains false on failure.
  Future<void> init() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        await KeyDerivationService.instance.initForAccount(account.id);
        _currentUser = account;
      }
    } catch (_) {
      // Silent restore failed — user will be routed to LoginScreen.
      _currentUser = null;
    }
  }

  /// Triggers the Google OAuth consent screen.
  /// Returns the account on success, null if the user cancelled.
  /// Throws on network or server errors.
  Future<GoogleSignInAccount?> signIn() async {
    final account = await _googleSignIn.signIn();
    if (account != null) {
      _currentUser = account;
    }
    return account;
  }

  /// Revokes the local Google sign-in session.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Disconnects the account entirely, forcing a fresh consent screen on next
  /// sign-in. Use this to recover from a 403 caused by a stale/scope-less token.
  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
    _currentUser = null;
  }

  /// Returns a fresh [AuthClient] for use with the googleapis package.
  /// Throws [StateError] if not signed in.
  Future<AuthClient> getAuthClient() async {
    if (_currentUser == null) {
      throw StateError('AuthService: not signed in');
    }
    final auth = await _currentUser!.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null) {
      throw StateError('AuthService: could not obtain access token');
    }
    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      auth.idToken,
      [_driveAppDataScope],
    );
    return authenticatedClient(http.Client(), credentials);
  }
}
