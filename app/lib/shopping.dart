import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase project used for the shared household list. Empty = local-only list.
const String kFirebaseProject = String.fromEnvironment('FIREBASE_PROJECT');

class ListItem {
  final String id;
  String name;
  String? code; // barcode when added from the catalog / a deal
  int qty;
  bool done;
  String by;
  int ts;

  ListItem({required this.id, required this.name, this.code, this.qty = 1, this.done = false, this.by = '', int? ts})
      : ts = ts ?? DateTime.now().millisecondsSinceEpoch;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'code': code, 'qty': qty, 'done': done, 'by': by, 'ts': ts};

  factory ListItem.fromJson(Map<String, dynamic> j) => ListItem(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String?,
        qty: (j['qty'] as num?)?.toInt() ?? 1,
        done: j['done'] == true,
        by: (j['by'] ?? '') as String,
        ts: (j['ts'] as num?)?.toInt(),
      );
}

typedef ListOp = void Function(List<ListItem> items);

String _rid(int n) {
  const abc = 'abcdefghjkmnpqrstuvwxyz23456789';
  final r = Random.secure();
  return List.generate(n, (_) => abc[r.nextInt(abc.length)]).join();
}

/// Shopping list: local-first, optionally synced to a household document in Firestore.
/// Every change is an operation that is re-applied on top of the latest remote copy,
/// so two people editing at once never overwrite each other.
class ShoppingList extends ChangeNotifier {
  static final ShoppingList instance = ShoppingList();

  List<ListItem> items = [];
  String? household; // shared code, null = not shared
  String me = '';
  bool syncing = false;
  String? syncError;
  DateTime? lastSync;
  SharedPreferences? _p;
  String? _remoteUpdateTime;
  Timer? _poll;
  final List<ListOp> _pending = []; // ops that failed to sync (offline); replayed on next pull

  bool get canShare => kFirebaseProject.isNotEmpty;
  int get openCount => items.where((i) => !i.done).length;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final raw = _p!.getString('shoppingList');
    items = raw == null
        ? []
        : (jsonDecode(raw) as List).map((e) => ListItem.fromJson(e as Map<String, dynamic>)).toList();
    household = _p!.getString('household');
    me = _p!.getString('memberName') ?? '';
    if (household != null) unawaited(pull());
  }

  Future<void> _saveLocal() async {
    await _p?.setString('shoppingList', jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  // ------------------------------------------------------------------ operations
  Future<void> _apply(ListOp op) async {
    op(items);
    await _saveLocal();
    notifyListeners();
    if (household != null) await _push(op);
  }

  Future<void> addItem(String name, {String? code, int qty = 1}) => _apply((list) {
        final existing = list.where((i) => !i.done && ((code != null && i.code == code) || (code == null && i.name == name)));
        if (existing.isNotEmpty) {
          existing.first.qty += qty;
          existing.first.ts = DateTime.now().millisecondsSinceEpoch;
        } else {
          list.add(ListItem(id: _rid(10), name: name, code: code, qty: qty, by: me));
        }
      });

  Future<void> setQty(String id, int qty) => _apply((list) {
        final i = list.where((x) => x.id == id);
        if (i.isEmpty) return;
        if (qty <= 0) {
          list.removeWhere((x) => x.id == id);
        } else {
          i.first.qty = qty;
        }
      });

  Future<void> toggleDone(String id) => _apply((list) {
        for (final x in list.where((x) => x.id == id)) {
          x.done = !x.done;
          x.ts = DateTime.now().millisecondsSinceEpoch;
        }
      });

  Future<void> remove(String id) => _apply((list) => list.removeWhere((x) => x.id == id));

  Future<void> restore(ListItem item) => _apply((list) {
        if (!list.any((x) => x.id == item.id)) list.add(item);
      });

  Future<void> clearDone() => _apply((list) => list.removeWhere((x) => x.done));

  // ------------------------------------------------------------------ household
  String _docUrl(String code) =>
      'https://firestore.googleapis.com/v1/projects/$kFirebaseProject/databases/(default)/documents/households/$code';

  Future<({List<ListItem> items, String? updateTime})?> _fetch(String code) async {
    final res = await http.get(Uri.parse(_docUrl(code))).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final data = (((j['fields'] as Map?)?['data'] as Map?)?['stringValue'] ?? '[]') as String;
    final list = (jsonDecode(data) as List).map((e) => ListItem.fromJson(e as Map<String, dynamic>)).toList();
    return (items: list, updateTime: j['updateTime'] as String?);
  }

  Future<bool> _write(String code, List<ListItem> list, String? updateTime) async {
    final pre = updateTime == null ? 'currentDocument.exists=false' : 'currentDocument.updateTime=$updateTime';
    final body = jsonEncode({
      'fields': {
        'data': {'stringValue': jsonEncode(list.map((e) => e.toJson()).toList())},
        'v': {'integerValue': '${DateTime.now().millisecondsSinceEpoch}'},
      }
    });
    final res = await http
        .patch(Uri.parse('${_docUrl(code)}?$pre'), headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 200) {
      _remoteUpdateTime = (jsonDecode(res.body) as Map<String, dynamic>)['updateTime'] as String?;
      return true;
    }
    if (res.statusCode == 400 || res.statusCode == 409 || res.statusCode == 412) return false; // precondition
    throw 'HTTP ${res.statusCode}';
  }

  /// Re-applies [op] on the latest remote copy and writes it back (optimistic concurrency).
  Future<void> _push(ListOp op) async {
    final code = household!;
    syncing = true;
    notifyListeners();
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        final remote = await _fetch(code);
        final list = remote?.items ?? <ListItem>[];
        op(list);
        if (await _write(code, list, remote?.updateTime)) {
          items = list;
          await _saveLocal();
          syncError = null;
          lastSync = DateTime.now();
          return;
        }
      }
      syncError = 'לא הצלחתי לסנכרן';
    } catch (_) {
      _pending.add(op);
      syncError = 'אין חיבור — השינוי נשמר בטלפון';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Fetches the household list (no-op when not shared).
  Future<void> pull() async {
    final code = household;
    if (code == null) return;
    if (_pending.isNotEmpty && !syncing) {
      final ops = List<ListOp>.from(_pending);
      _pending.clear();
      for (final op in ops) {
        await _push(op);
      }
      if (_pending.isNotEmpty) return; // still offline
    }
    try {
      final remote = await _fetch(code);
      if (remote == null) return;
      if (remote.updateTime != _remoteUpdateTime) {
        _remoteUpdateTime = remote.updateTime;
        items = remote.items;
        await _saveLocal();
      }
      syncError = null;
      lastSync = DateTime.now();
    } catch (_) {
      syncError = 'אין חיבור — מוצגת הרשימה ששמורה בטלפון';
    }
    notifyListeners();
  }

  /// Poll while the list screen is open, so changes by others appear within seconds.
  void startPolling() {
    _poll?.cancel();
    if (household == null) return;
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => pull());
  }

  void stopPolling() => _poll?.cancel();

  Future<void> setMe(String name) async {
    me = name.trim();
    await _p?.setString('memberName', me);
    notifyListeners();
  }

  /// Creates a new household from the current list; returns its code.
  Future<String> createHousehold() async {
    final code = _rid(12);
    if (!await _write(code, items, null)) throw 'קוד תפוס, נסה שוב';
    household = code;
    await _p?.setString('household', code);
    notifyListeners();
    startPolling();
    return code;
  }

  /// Joins an existing household; local items are merged into it.
  Future<void> joinHousehold(String code) async {
    code = code.trim().toLowerCase();
    final remote = await _fetch(code);
    if (remote == null) throw 'לא מצאתי רשימה עם הקוד הזה';
    household = code;
    await _p?.setString('household', code);
    final mine = List<ListItem>.from(items);
    items = remote.items;
    _remoteUpdateTime = remote.updateTime;
    notifyListeners();
    if (mine.isNotEmpty) {
      await _push((list) {
        for (final m in mine) {
          if (!list.any((x) => x.id == m.id)) list.add(m);
        }
      });
    }
    startPolling();
  }

  Future<void> leaveHousehold() async {
    stopPolling();
    household = null;
    await _p?.remove('household');
    notifyListeners();
  }
}
