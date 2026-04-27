import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/resume_profile.dart';

class SavedProfile {
  final String id;
  final String label;
  final ResumeProfile profile;
  final String createdAt;

  SavedProfile({
    required this.id,
    required this.label,
    required this.profile,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'createdAt': createdAt,
    'profile': {
      'name': profile.name,
      'skills': profile.skills,
      'experience_level': profile.experienceLevel,
      'years_of_experience': profile.yearsOfExperience,
      'country': profile.country,
      'country_code': profile.countryCode,
      'job_title': profile.jobTitle,
      'summary': profile.summary,
      'projects': profile.projects,
      'certifications': profile.certifications,
      'education': profile.education,
      'strengths': profile.strengths,
      'gaps': profile.gaps,
      'ats_score': profile.atsScore,
      'ats_issues': profile.atsIssues,
    },
  };

  factory SavedProfile.fromJson(Map<String, dynamic> j) => SavedProfile(
    id: j['id'] ?? '',
    label: j['label'] ?? 'Resume',
    createdAt: j['createdAt'] ?? '',
    profile: ResumeProfile.fromJson(Map<String, dynamic>.from(j['profile'] ?? {})),
  );
}

class ProfileStorageService {
  static const _key = 'saved_profiles_v1';
  static const int maxProfiles = 5;

  static Future<List<SavedProfile>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((j) => SavedProfile.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> save(SavedProfile p) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await ProfileStorageService.all();
    all.removeWhere((x) => x.id == p.id);
    all.add(p);
    if (all.length > maxProfiles) all.removeRange(0, all.length - maxProfiles);
    await prefs.setString(_key, json.encode(all.map((x) => x.toJson()).toList()));
  }

  static Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await ProfileStorageService.all();
    all.removeWhere((x) => x.id == id);
    await prefs.setString(_key, json.encode(all.map((x) => x.toJson()).toList()));
  }
}
