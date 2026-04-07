import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

enum AppStatus { saved, applied, interviewing, offer, rejected }

extension AppStatusX on AppStatus {
  String get label {
    switch (this) {
      case AppStatus.saved: return 'Saved';
      case AppStatus.applied: return 'Applied';
      case AppStatus.interviewing: return 'Interviewing';
      case AppStatus.offer: return 'Offer';
      case AppStatus.rejected: return 'Rejected';
    }
  }
}

class TrackedApplication {
  final String id;
  final String jobTitle;
  final String company;
  final String? location;
  final String? salaryRange;
  final String? applyUrl;
  final String? companyLogo;
  AppStatus status;
  String notes;
  final String savedAt;
  String? appliedAt;
  String? interviewAt;

  TrackedApplication({
    required this.id,
    required this.jobTitle,
    required this.company,
    this.location,
    this.salaryRange,
    this.applyUrl,
    this.companyLogo,
    this.status = AppStatus.saved,
    this.notes = '',
    required this.savedAt,
    this.appliedAt,
    this.interviewAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'jobTitle': jobTitle,
    'company': company,
    'location': location,
    'salaryRange': salaryRange,
    'applyUrl': applyUrl,
    'companyLogo': companyLogo,
    'status': status.name,
    'notes': notes,
    'savedAt': savedAt,
    'appliedAt': appliedAt,
    'interviewAt': interviewAt,
  };

  factory TrackedApplication.fromJson(Map<String, dynamic> j) => TrackedApplication(
    id: j['id'] ?? '',
    jobTitle: j['jobTitle'] ?? '',
    company: j['company'] ?? '',
    location: j['location'],
    salaryRange: j['salaryRange'],
    applyUrl: j['applyUrl'],
    companyLogo: j['companyLogo'],
    status: AppStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => AppStatus.saved),
    notes: j['notes'] ?? '',
    savedAt: j['savedAt'] ?? DateTime.now().toIso8601String(),
    appliedAt: j['appliedAt'],
    interviewAt: j['interviewAt'],
  );
}

class ApplicationTrackerService {
  static const _key = 'tracked_applications_v1';

  static Future<List<TrackedApplication>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((j) => TrackedApplication.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> _saveAll(List<TrackedApplication> apps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, json.encode(apps.map((a) => a.toJson()).toList()));
  }

  static Future<void> add(TrackedApplication app) async {
    final all = await ApplicationTrackerService.all();
    if (all.any((a) => a.id == app.id)) return;
    all.add(app);
    await _saveAll(all);
  }

  static Future<void> update(TrackedApplication app) async {
    final all = await ApplicationTrackerService.all();
    final idx = all.indexWhere((a) => a.id == app.id);
    if (idx >= 0) {
      all[idx] = app;
      await _saveAll(all);
    }
  }

  static Future<void> remove(String id) async {
    final all = await ApplicationTrackerService.all();
    all.removeWhere((a) => a.id == id);
    await _saveAll(all);
  }

  static Future<bool> isTracked(String id) async {
    final all = await ApplicationTrackerService.all();
    return all.any((a) => a.id == id);
  }

  static Future<Map<AppStatus, int>> counts() async {
    final all = await ApplicationTrackerService.all();
    final m = <AppStatus, int>{};
    for (final s in AppStatus.values) { m[s] = 0; }
    for (final a in all) { m[a.status] = (m[a.status] ?? 0) + 1; }
    return m;
  }
}
