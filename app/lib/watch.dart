import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Something the user follows: a specific product (barcode), a category, or free text.
class WatchItem {
  final String type; // product | cat | text
  final String value;
  final String label;
  const WatchItem(this.type, this.value, this.label);

  Map<String, String> toJson() => {'type': type, 'value': value, 'label': label};
  factory WatchItem.fromJson(Map<String, dynamic> j) =>
      WatchItem(j['type'] as String, j['value'] as String, (j['label'] ?? j['value']) as String);

  String get key => '$type:$value';

  bool matches(Deal d) => switch (type) {
        'product' => d.items.any((i) => i.code == value),
        'cat' => d.cats.contains(value),
        _ => value
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .every(d.searchText.contains),
      };
}

enum NotifyMode { off, daily, instant }

const notifyModeLabels = {
  NotifyMode.off: 'כבוי',
  NotifyMode.daily: 'סיכום אחד בבוקר',
  NotifyMode.instant: 'מיד כשמופיע מבצע',
};

/// Persistent watchlist + notification preference. Used by the UI and the background task.
class Watchlist extends ChangeNotifier {
  static final Watchlist instance = Watchlist();

  List<WatchItem> items = [];
  NotifyMode mode = NotifyMode.daily;
  SharedPreferences? _p;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    await _p!.reload();
    final raw = _p!.getString('watchlist');
    items = raw == null
        ? []
        : (jsonDecode(raw) as List).map((e) => WatchItem.fromJson(e as Map<String, dynamic>)).toList();
    mode = NotifyMode.values[(_p!.getInt('notifyMode') ?? NotifyMode.daily.index).clamp(0, 2)];
  }

  Future<void> _save() async {
    await _p?.setString('watchlist', jsonEncode(items.map((e) => e.toJson()).toList()));
    await _p?.setInt('notifyMode', mode.index);
    notifyListeners();
  }

  bool has(String type, String value) => items.any((w) => w.type == type && w.value == value);

  Future<void> toggle(WatchItem w) async {
    if (has(w.type, w.value)) {
      items.removeWhere((x) => x.key == w.key);
    } else {
      items.add(w);
    }
    await _save();
  }

  Future<void> add(WatchItem w) async {
    if (!has(w.type, w.value)) {
      items.add(w);
      await _save();
    }
  }

  Future<void> remove(WatchItem w) async {
    items.removeWhere((x) => x.key == w.key);
    await _save();
  }

  Future<void> setMode(NotifyMode m) async {
    mode = m;
    await _save();
  }

  bool watched(Deal d) => items.any((w) => w.matches(d));

  List<Deal> matches(Iterable<Deal> deals, {Set<String> hiddenTags = const {}}) => deals
      .where((d) => !d.tags.any(hiddenTags.contains) && items.any((w) => w.matches(d)))
      .toList()
    ..sort((a, b) => b.pct.compareTo(a.pct));
}
