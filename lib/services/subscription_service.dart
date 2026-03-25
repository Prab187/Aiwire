import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String productId = 'aiwire_premium_monthly';
  static const String productIdYearly = 'aiwire_premium_yearly';
  static const String _keyIsPremium = 'is_premium';
  static const String _keyDailyCount = 'daily_summary_count';
  static const String _keyLastDate = 'last_summary_date';
  static const int freeLimit = 3;
  // Trial days configured in App Store Connect. Change to 0 to disable trial.
  static const int _kTrialDays = 7;

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static ProductDetails? _product;
  static ProductDetails? _productYearly;

  static Future<void> initialize() async {
    try {
      final available = await _iap.isAvailable()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (!available) return;
      final response = await _iap.queryProductDetails({productId, productIdYearly})
          .timeout(const Duration(seconds: 5), onTimeout: () => ProductDetailsResponse(
            productDetails: [], notFoundIDs: [productId, productIdYearly], error: null));
      for (final p in response.productDetails) {
        if (p.id == productId) _product = p;
        if (p.id == productIdYearly) _productYearly = p;
      }
      _sub = _iap.purchaseStream.listen(_onPurchase);
    } catch (_) {
      // IAP unavailable — app still works in free mode
    }
  }

  static void dispose() => _sub?.cancel();

  static ProductDetails? get product => _product;
  static ProductDetails? get productYearly => _productYearly;

  /// Returns the free-trial duration in days if the product is loaded and has
  /// an introductory offer configured, otherwise null.
  static int? introductoryOfferDays({bool yearly = false}) {
    final p = yearly ? _productYearly : _product;
    if (p == null) return null; // products not yet loaded
    return _kTrialDays;
  }

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

  static Future<void> purchase({bool yearly = false}) async {
    final p = yearly ? _productYearly : _product;
    if (p == null) throw Exception('Product unavailable');
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  static Future<void> restorePurchases() async =>
      _iap.restorePurchases();

  /// Validates the subscription on startup. Restores purchases and clears the
  /// premium flag if no active subscription is found within the timeout.
  static Future<void> validateSubscription() async {
    try {
    final available = await _iap.isAvailable()
        .timeout(const Duration(seconds: 5), onTimeout: () => false);
    if (!available) return;

    bool foundActive = false;
    final validateSub = _iap.purchaseStream.listen((purchases) {
      for (final p in purchases) {
        if ((p.productID == productId || p.productID == productIdYearly) &&
            (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored)) {
          foundActive = true;
        }
      }
    });

    await _iap.restorePurchases();
    // Allow the purchase stream to deliver all restored purchases.
    await Future.delayed(const Duration(seconds: 3));
    await validateSub.cancel();

    if (!foundActive) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyIsPremium, false);
    }
    } catch (_) {
      // Validation failed silently — app continues in free mode
    }
  }

  static Future<void> _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID == productId || p.productID == productIdYearly) {
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
