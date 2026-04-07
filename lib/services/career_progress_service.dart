import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CareerSnapshot {
  final String date;
  final int skillsCount;
  final int matchScore;
  final int atsScore;
  final String level;
  final List<String> skills;

  CareerSnapshot({
    required this.date,
    required this.skillsCount,
    required this.matchScore,
    required this.atsScore,
    required this.level,
    required this.skills,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'skillsCount': skillsCount,
    'matchScore': matchScore,
    'atsScore': atsScore,
    'level': level,
    'skills': skills,
  };

  factory CareerSnapshot.fromJson(Map<String, dynamic> j) => CareerSnapshot(
    date: j['date'] ?? '',
    skillsCount: j['skillsCount'] ?? 0,
    matchScore: j['matchScore'] ?? 0,
    atsScore: j['atsScore'] ?? 0,
    level: j['level'] ?? 'Mid',
    skills: List<String>.from(j['skills'] ?? []),
  );
}

class CareerProgressService {
  static const _key = 'career_snapshots_v1';
  static const _streakKey = 'career_streak_v1';
  static const _streakDateKey = 'career_streak_date_v1';

  static Future<List<CareerSnapshot>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = json.decode(raw) as List;
      return list.map((j) => CareerSnapshot.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) { return []; }
  }

  static Future<void> add(CareerSnapshot snap) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await CareerProgressService.all();
    // Replace if same day
    all.removeWhere((s) => s.date.substring(0, 10) == snap.date.substring(0, 10));
    all.add(snap);
    // Keep last 90 days max
    if (all.length > 90) all.removeRange(0, all.length - 90);
    await prefs.setString(_key, json.encode(all.map((s) => s.toJson()).toList()));
  }

  static Future<int> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final lastDate = prefs.getString(_streakDateKey);
    final streak = prefs.getInt(_streakKey) ?? 0;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastDate == today) return streak;

    int newStreak = 1;
    if (lastDate != null) {
      final last = DateTime.tryParse(lastDate);
      if (last != null) {
        final diff = DateTime.parse(today).difference(last).inDays;
        if (diff == 1) newStreak = streak + 1;
      }
    }
    await prefs.setInt(_streakKey, newStreak);
    await prefs.setString(_streakDateKey, today);
    return newStreak;
  }

  static Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_streakKey) ?? 0;
  }
}
