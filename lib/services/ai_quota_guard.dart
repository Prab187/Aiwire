import 'package:shared_preferences/shared_preferences.dart';
import 'subscription_service.dart';

/// Guards AI feature usage behind a daily free quota.
/// Premium users bypass all limits. Free users get [dailyFreeLimit]
/// AI actions per day (resets at midnight local time).
///
/// Call [canUse] before every Claude API call. If it returns false,
/// show the paywall. Call [record] after a successful Claude call.
class AiQuotaGuard {
  static const int dailyFreeLimit = 10;
  static const String _countKey = 'ai_quota_count';
  static const String _dateKey = 'ai_quota_date';

  /// Returns true if the user can make an AI call right now.
  /// Premium users always return true.
  static Future<bool> canUse() async {
    if (await SubscriptionService.isPremium()) return true;
    final count = await _todayCount();
    return count < dailyFreeLimit;
  }

  /// Returns how many free AI calls remain today.
  static Future<int> remaining() async {
    if (await SubscriptionService.isPremium()) return dailyFreeLimit;
    final count = await _todayCount();
    return (dailyFreeLimit - count).clamp(0, dailyFreeLimit);
  }

  /// Record one AI usage. Call after a successful Claude API response.
  static Future<void> record() async {
    if (await SubscriptionService.isPremium()) return;
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final storedDate = prefs.getString(_dateKey) ?? '';
    if (storedDate != today) {
      await prefs.setInt(_countKey, 1);
      await prefs.setString(_dateKey, today);
    } else {
      final count = prefs.getInt(_countKey) ?? 0;
      await prefs.setInt(_countKey, count + 1);
    }
  }

  static Future<int> _todayCount() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    final storedDate = prefs.getString(_dateKey) ?? '';
    if (storedDate != today) {
      // New day — reset
      await prefs.setInt(_countKey, 0);
      await prefs.setString(_dateKey, today);
      return 0;
    }
    return prefs.getInt(_countKey) ?? 0;
  }

  static String _today() =>
      DateTime.now().toIso8601String().substring(0, 10);
}
