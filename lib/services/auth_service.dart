import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const _keyIsGuest = 'auth_is_guest';
  static const _keyUserName = 'auth_user_name';
  static const _keyUserEmail = 'auth_user_email';

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

  static Future<void> continueAsGuest() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
  }

  static Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsGuest, true);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyUserEmail);
  }
}
