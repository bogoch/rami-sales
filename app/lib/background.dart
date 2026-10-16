import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'data.dart';
import 'logic.dart';
import 'models.dart';
import 'watch.dart';

const _taskName = 'rami-sales-watch';
final _notifs = FlutterLocalNotificationsPlugin();

const _channel = AndroidNotificationDetails(
  'deals',
  'מבצעים שאתה עוקב אחריהם',
  channelDescription: 'התראות על מבצעים במוצרים ובקטגוריות שבמעקב',
  importance: Importance.defaultImportance,
  icon: 'ic_stat_notify',
  color: Color(0xFFD21F2C),
);

Future<void> initNotifications() async {
  await _notifs.initialize(
    settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_notify')),
  );
}

Future<bool> requestNotificationPermission() async {
  final android = _notifs.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  return await android?.requestNotificationsPermission() ?? false;
}

/// Registers the periodic background check (Android keeps it across restarts).
Future<void> initBackground() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(_taskName, _taskName, frequency: const Duration(hours: 2));
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await initNotifications();
      await runWatchCheck();
    } catch (_) {}
    return true;
  });
}

bool _quietHours(DateTime t) => t.hour >= 22 || t.hour < 8;

/// Fetches today's deals and notifies about watched items. Safe to call from UI or background.
Future<void> runWatchCheck({DateTime? now}) async {
  now ??= DateTime.now();
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final wl = Watchlist();
  await wl.load();
  if (wl.mode == NotifyMode.off || wl.items.isEmpty || _quietHours(now)) return;

  final storeId = prefs.getString('storeId') ?? '23';
  final hidden = (prefs.getStringList('hiddenTags') ?? []).toSet();
  final file = (await Api().deals(storeId)).data;
  final matches = wl.matches(file.deals, hiddenTags: hidden);

  final today = '${now.year}-${now.month}-${now.day}';
  final notified = Map<String, String>.from(jsonDecode(prefs.getString('notifiedDeals') ?? '{}') as Map);
  final ending = Map<String, String>.from(jsonDecode(prefs.getString('endingNotified') ?? '{}') as Map);
  // forget entries for deals that no longer exist
  final ids = file.deals.map((d) => d.id).toSet();
  notified.removeWhere((k, _) => !ids.contains(k));
  ending.removeWhere((k, _) => !ids.contains(k));

  final fresh = matches.where((d) => !notified.containsKey(d.id)).toList();
  final digestDue = prefs.getString('lastDigest') != today;

  if (fresh.isNotEmpty && (wl.mode == NotifyMode.instant || digestDue)) {
    final title = fresh.length == 1 ? 'מבצע על משהו שאתה עוקב אחריו' : '${fresh.length} מבצעים על דברים שאתה עוקב אחריהם';
    final body = fresh.take(4).map((d) => '${pctText(d.pct)} · ${d.desc}').join('\n');
    await _notifs.show(
      id: 1,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.channelId,
          _channel.channelName,
          channelDescription: _channel.channelDescription,
          icon: _channel.icon,
          color: _channel.color,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
    for (final d in fresh) {
      notified[d.id] = today;
    }
    await prefs.setString('lastDigest', today);
  }

  // "ends tomorrow" reminders for watched deals, once per deal
  final endingSoon = matches.where((d) => daysLeft(d, now!) == 1 && !ending.containsKey(d.id)).toList();
  if (endingSoon.isNotEmpty) {
    await _notifs.show(
      id: 2,
      title: endingSoon.length == 1 ? 'מבצע שאתה עוקב אחריו נגמר מחר' : '${endingSoon.length} מבצעים שאתה עוקב אחריהם נגמרים מחר',
      body: endingSoon.take(4).map((d) => d.desc).join('\n'),
      notificationDetails: const NotificationDetails(android: _channel),
    );
    for (final d in endingSoon) {
      ending[d.id] = today;
    }
  }
  await prefs.setString('notifiedDeals', jsonEncode(notified));
  await prefs.setString('endingNotified', jsonEncode(ending));
}

/// Marks everything currently matching as already notified (used when the user just looked at them).
Future<void> markSeen(List<Deal> matches) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final today = '${now.year}-${now.month}-${now.day}';
  final notified = Map<String, String>.from(jsonDecode(prefs.getString('notifiedDeals') ?? '{}') as Map);
  for (final d in matches) {
    notified.putIfAbsent(d.id, () => today);
  }
  await prefs.setString('notifiedDeals', jsonEncode(notified));
}
