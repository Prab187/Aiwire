import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Holds all app data in memory and saves it to the phone after every change.
/// Nothing leaves the device.
class AppStore extends ChangeNotifier {
  AppStore(this.data, [this._prefs]);

  static const _key = 'school_day_v1';
  final AppData data;
  final SharedPreferences? _prefs;

  static Future<AppStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    AppData data;
    try {
      data = raw == null ? AppData.example(DateTime.now()) : AppData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      data = AppData.example(DateTime.now());
    }
    return AppStore(data, prefs);
  }

  /// Change data, tell the screens, and save. Pass [clearsExample] false for
  /// edits (like typing a name) that should not remove the sample content.
  void update(void Function(AppData d) change, {bool clearsExample = true}) {
    change(data);
    if (clearsExample) data.example = false;
    notifyListeners();
    _prefs?.setString(_key, jsonEncode(data.toJson()));
  }

  void startFresh() {
    update((d) {
      for (final l in d.timetable.values) {
        for (var i = 0; i < l.length; i++) {
          l[i] = '';
        }
      }
      d.homework.clear();
      d.people.clear();
      d.bagExtra.clear();
      d.bagGot = [];
      d.notes = '';
    });
  }
}
