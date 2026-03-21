import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String productId = 'aiwire_premium_monthly';
  static const String _keyIsPremium = 'is_premium';
  static const String _keyDailyCount = 'daily_summary_count';
  static const String _keyLastDate = 'last_summary_date';
  static const int freeLimit = 999; // dev mode

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static ProductDetails? _product;

  static Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) return;
    final response = await _iap.queryProductDetails({productId});
    if (response.productDetails.isNotEmpty) {
      _product = response.productDetails.first;
    }
    _sub = _iap.purchaseStream.listen(_onPurchase);
  }

  static void dispose() => _sub?.cancel();

  static ProductDetails? get product => _product;

  static Future<bool> isPremium() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPremium) ?? false;
  }

  static Future<bool> canUseSummary() async {
    if (await isPremium()) return true;
    return (await _getDailyCount()) < freeLimit;
  }

  static Future<int> remainingFree() async {
    if (await isPremium()) return freeLimit;
    return (freeLimit - await _getDailyCount()).clamp(0, freeLimit);
  }

  static Future<void> recordUsage() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _today();
    await prefs.setString(_keyLastDate, today);
    final count = prefs.getInt(_keyDailyCount) ?? 0;
    await prefs.setInt(_keyDailyCount, count + 1);
  }

  static Future<int> _getDailyCount() async {
    final prefs = await SharedPreferences.getInstance();
    if ((prefs.getString(_keyLastDate) ?? '') != _today()) {
      await prefs.setInt(_keyDailyCount, 0);
      await prefs.setString(_keyLastDate, _today());
      return 0;
    }
    return prefs.getInt(_keyDailyCount) ?? 0;
  }

  static String _today() =>
      DateTime.now().toIso8601String().substring(0, 10);

  static Future<void> purchase() async {
    if (_product == null) throw Exception('Product unavailable');
    await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _product!));
  }

  static Future<void> restorePurchases() async =>
      _iap.restorePurchases();

  static Future<void> _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == productId) {
        if (p.status == PurchaseStatus.purchased ||
            p.status == PurchaseStatus.restored) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyIsPremium, true);
          await _iap.completePurchase(p);
        } else if (p.status == PurchaseStatus.error) {
          await _iap.completePurchase(p);
        }
      }
    }
  }
}
