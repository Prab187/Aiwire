import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Lightweight wrapper for Firebase Analytics events.
/// All calls are no-op safe — if Firebase isn't initialized, nothing happens.
class AnalyticsService {
  static FirebaseAnalytics? _analytics;
  static bool _disabled = false;

  static FirebaseAnalytics? _getAnalytics() {
    if (_disabled) return null;
    if (_analytics != null) return _analytics;
    try {
      // Check if Firebase is actually initialized
      Firebase.app();
      _analytics = FirebaseAnalytics.instance;
      return _analytics;
    } catch (_) {
      _disabled = true;
      return null;
    }
  }

  static Future<void> _log(String name, [Map<String, Object>? params]) async {
    try {
      final fa = _getAnalytics();
      if (fa == null) return;
      await fa.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('Analytics: $e');
      _disabled = true;
    }
  }

  // ── Resume ──
  static Future<void> resumeScanned({required String country}) =>
      _log('resume_scanned', {'country': country});
  static Future<void> sampleResumeUsed() => _log('sample_resume_used');

  // ── Career Plan ──
  static Future<void> careerPlanGenerated() => _log('career_plan_generated');
  static Future<void> manualCareerCheck() => _log('manual_career_check');

  // ── Jobs ──
  static Future<void> jobSaved({required String jobTitle}) =>
      _log('job_saved', {'title': jobTitle});
  static Future<void> jobApplied({required String jobTitle}) =>
      _log('job_applied', {'title': jobTitle});

  // ── Interview ──
  static Future<void> interviewStarted({required String role, required String type}) =>
      _log('interview_started', {'role': role, 'type': type});
  static Future<void> interviewCompleted({required int avgScore}) =>
      _log('interview_completed', {'avg_score': avgScore});
  static Future<void> prepGuideViewed({required String role}) =>
      _log('prep_guide_viewed', {'role': role});

  // ── Salary ──
  static Future<void> salaryCalculated({required String role, required String location}) =>
      _log('salary_calculated', {'role': role, 'location': location});

  // ── Content ──
  static Future<void> articleSummaryViewed() => _log('article_summary_viewed');
  static Future<void> videoSummaryViewed({required String videoId}) =>
      _log('video_summary_viewed', {'video_id': videoId});

  // ── Subscription ──
  static Future<void> paywallViewed() => _log('paywall_viewed');
  static Future<void> subscriptionStarted({required bool yearly}) =>
      _log('subscription_started', {'yearly': yearly});

  // ── Feature discovery ──
  static Future<void> featureTapped({required String feature}) =>
      _log('feature_tapped', {'feature': feature});
}
