import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  static const _keyIsGuest = 'auth_is_guest';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserEmail = 'auth_user_email';
  static const _keyProvider = 'auth_provider'; // 'apple', 'google', 'guest'

  static final _googleSignIn = GoogleSignIn(
    clientId: '392694757606-th4472jah3e03mq6dnalkuu5aumo8vmg.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  static Future<bool> isGuest() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsGuest) ?? true;
  }

  static Future<String?> userName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserName);
  }

  static Future<String?> userEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserEmail);
  }

  static Future<String?> provider() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyProvider);
  }

  static Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
    await prefs.setString(_keyProvider, 'guest');
  }

  static Future<bool> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsGuest, false);
      await prefs.setString(_keyProvider, 'apple');

      // Apple only sends name/email on first sign-in
      final firstName = credential.givenName ?? '';
      final lastName = credential.familyName ?? '';
      final fullName = '$firstName $lastName'.trim();
      if (fullName.isNotEmpty) {
        await prefs.setString(_keyUserName, fullName);
      }
      if (credential.email != null) {
        await prefs.setString(_keyUserEmail, credential.email!);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsGuest, false);
      await prefs.setString(_keyProvider, 'google');
      await prefs.setString(_keyUserName, account.displayName ?? '');
      await prefs.setString(_keyUserEmail, account.email);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final prov = prefs.getString(_keyProvider);
    if (prov == 'google') {
      await _googleSignIn.signOut();
    }
    await prefs.setBool(_keyIsGuest, true);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyProvider);
  }
}
