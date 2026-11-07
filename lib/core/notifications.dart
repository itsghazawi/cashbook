import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'format.dart';
import 'models.dart';
import 'settings.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService I = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'cashbook_reminders',
    'تذكيرات المصاريف',
    channelDescription: 'تذكير بمواعيد دفع المصاريف الشهرية',
    importance: Importance.max,
    priority: Priority.high,
    icon: 'ic_stat_cashbook',
    color: Color.fromARGB(255, 217, 178, 106),
    styleInformation: BigTextStyleInformation(''),
  );

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Damascus'));
      } catch (_) {}
    }
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_cashbook'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Ask for notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isAndroid) {
      return await _android?.requestNotificationsPermission() ?? true;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  /// First launch: only the small system "allow notifications" prompt.
  Future<void> requestAllOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('perm_asked') == true) return;
    await prefs.setBool('perm_asked', true);
    await requestPermission();
  }

  /// Cancels everything and schedules reminders for the next two
  /// occurrences of every active expense.
  Future<void> rescheduleAll(List<Expense> expenses) async {
    try {
      await init();
      await _plugin.cancelAll();
      // Payment reminders don't need second-level precision: inexact alarms
      // need no special permission or settings screen.
      const mode = AndroidScheduleMode.inexactAllowWhileIdle;
      final now = DateTime.now();

      for (final e in expenses) {
        if (!e.active || e.done) continue;
        // Occurrences: current due (if still upcoming) + following ones.
        final occ = <DateTime>[];
        var d = e.due;
        var guard = 0;
        while (occ.length < 2 && guard < 600) {
          if (d.isAfter(now)) occ.add(d);
          if (e.repeat == Repeat.none) break;
          d = e.repeat.next(d);
          guard++;
        }
        for (var o = 0; o < occ.length; o++) {
          for (final m in AppSettings.reminders.value) {
            final slot = Remind.all.indexOf(m);
            if (slot < 0) continue;
            final at = occ[o].subtract(Duration(minutes: m));
            if (!at.isAfter(now)) continue;
            final id = e.notifBase * 10 + o * 4 + slot;
            final money = fmtMoney(e.amount, e.currency);
            final title = m == 0 ? 'حان موعد الدفع: ${e.title}' : 'تذكير: ${e.title}';
            final body = m == 0
                ? 'اليوم موعد دفع ${e.title} بقيمة $money'
                : 'باقي ${_left(m)} على موعد دفع ${e.title} ($money) — ${fmtDateTime(occ[o])}';
            await _plugin.zonedSchedule(
              id: id,
              title: title,
              body: body,
              scheduledDate: tz.TZDateTime.from(at, tz.local),
              notificationDetails: NotificationDetails(
                android: AndroidNotificationDetails(
                  _channel.channelId,
                  _channel.channelName,
                  channelDescription: _channel.channelDescription,
                  importance: _channel.importance,
                  priority: _channel.priority,
                  icon: _channel.icon,
                  color: _channel.color,
                  styleInformation: BigTextStyleInformation(body),
                ),
                iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
              ),
              androidScheduleMode: mode,
              payload: e.id,
            );
          }
        }
      }
    } catch (err) {
      debugPrint('reschedule failed: $err');
    }
  }

  String _left(int m) => switch (m) {
        1440 => '24 ساعة',
        720 => '12 ساعة',
        60 => 'ساعة واحدة',
        _ => '$m دقيقة',
      };

  Future<void> showTest() async {
    await init();
    await _plugin.show(
      id: 999999,
      title: 'كاش بوك',
      body: 'التذكيرات تعمل بشكل صحيح ✓',
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
    );
  }
}
