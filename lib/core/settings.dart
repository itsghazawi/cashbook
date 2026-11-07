import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// App-wide settings shared by every screen.
class AppSettings {
  AppSettings._();

  /// Name shown as the sender on PDF statements.
  static final ownerName = ValueNotifier<String>('');

  /// Reminder offsets (minutes before due) applied to every expense.
  static final reminders = ValueNotifier<List<int>>([Remind.day, Remind.half, Remind.hour, Remind.atTime]);

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    ownerName.value = p.getString('owner_name') ?? '';
    final r = p.getStringList('reminders');
    if (r != null) reminders.value = r.map(int.parse).toList();
  }

  static Future<void> setOwnerName(String v) async {
    ownerName.value = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('owner_name', ownerName.value);
  }

  static Future<void> setReminder(int minutes, bool on) async {
    final set = {...reminders.value};
    on ? set.add(minutes) : set.remove(minutes);
    reminders.value = Remind.all.where(set.contains).toList();
    final p = await SharedPreferences.getInstance();
    await p.setStringList('reminders', reminders.value.map((e) => '$e').toList());
  }
}
