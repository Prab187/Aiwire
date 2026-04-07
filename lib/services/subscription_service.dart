import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionService {
  static const String productId = 'aiwire_premium_monthly';
  static const String productIdYearly = 'aiwire_premium_yearly';
  static const String _keyIsPremium = 'is_premium';
  static const String _keyPurchaseDate = 'purchase_date';
  static const String _keyProductId = 'purchased_product_id';
  static const String _keyDailyCount = 'daily_summary_count';
  static const String _keyLastDate = 'last_summary_date';
  static const int freeLimit = 30;
  static const int _kTrialDays = 7;

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _sub;
  static ProductDetails? _product;
  static ProductDetails? _productYearly;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      final available = await _iap.isAvailable()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (!available) {
        debugPrint('IAP: Store not available');
        return;
      }
      final response = await _iap.queryProductDetails({productId, productIdYearly})
          .timeout(const Duration(seconds: 5), onTimeout: () => ProductDetailsResponse(
            productDetails: [], notFoundIDs: [productId, productIdYearly], error: null));
      for (final p in response.productDetails) {
        if (p.id == productId) _product = p;
        if (p.id == productIdYearly) _productYearly = p;
      }
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('IAP: Products not found: ${response.notFoundIDs}');
      }
      _sub = _iap.purchaseStream.listen(_onPurchase, onError: (error) {
        debugPrint('IAP stream error: $error');
      });
      _initialized = true;
    } catch (e) {
      debugPrint('IAP init failed: $e');
    }
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }

  static ProductDetails? get product => _product;
  static ProductDetails? get productYearly => _productYearly;

  static int? introductoryOfferDays({bool yearly = false}) {
    final p = yearly ? _productYearly : _product;
    if (p == null) return null;
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
    if (p == null) throw Exception('Products not loaded. Please try again.');
    await _iap.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: p));
  }

  static Future<void> restorePurchases() async =>
      _iap.restorePurchases();

  /// Validates subscription on startup by restoring purchases from Apple.
  /// This uses Apple's StoreKit transaction history — the device-level
  /// source of truth for active subscriptions.
  static Future<void> validateSubscription() async {
    try {
      final available = await _iap.isAvailable()
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (!available) return;

      final completer = Completer<bool>();
      bool foundActive = false;

      final validateSub = _iap.purchaseStream.listen((purchases) {
        for (final p in purchases) {
          if (p.productID == productId || p.productID == productIdYearly) {
            if (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored) {
              foundActive = true;
              // Complete any pending transactions
              if (p.pendingCompletePurchase) {
                _iap.completePurchase(p);
              }
            }
          }
        }
      }, onError: (e) {
        debugPrint('Validation stream error: $e');
      });

      await _iap.restorePurchases();
      // Wait for restore to deliver all transactions
      await Future.delayed(const Duration(seconds: 4));
      await validateSub.cancel();

      final prefs = await SharedPreferences.getInstance();
      if (foundActive) {
        await prefs.setBool(_keyIsPremium, true);
        debugPrint('IAP: Active subscription confirmed');
      } else {
        await prefs.setBool(_keyIsPremium, false);
        debugPrint('IAP: No active subscription found');
      }

      if (!completer.isCompleted) completer.complete(foundActive);
    } catch (e) {
      debugPrint('Subscription validation failed: $e');
    }
  }

  static Future<void> _onPurchase(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != productId && p.productID != productIdYearly) continue;

      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_keyIsPremium, true);
          await prefs.setString(_keyPurchaseDate, DateTime.now().toIso8601String());
          await prefs.setString(_keyProductId, p.productID);
          debugPrint('IAP: Premium activated (${p.productID})');
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;

        case PurchaseStatus.pending:
          debugPrint('IAP: Purchase pending for ${p.productID}');
          break;

        case PurchaseStatus.error:
          debugPrint('IAP: Purchase error — ${p.error?.message ?? "unknown"}');
          if (p.pendingCompletePurchase) {
            await _iap.completePurchase(p);
          }
          break;

        case PurchaseStatus.canceled:
          debugPrint('IAP: Purchase canceled');
          break;
      }
    }
  }
}
