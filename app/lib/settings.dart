import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SortBy { pct, save, perUnit, newest, ending }

const sortLabels = {
  SortBy.pct: 'אחוז הנחה',
  SortBy.save: 'חיסכון בשקלים',
  SortBy.perUnit: 'מחיר לק״ג/ליטר',
  SortBy.newest: 'חדשים קודם',
  SortBy.ending: 'נגמרים בקרוב',
};

/// Tags the user can choose to hide.
const hideableTags = {
  'club': 'מבצעי מועדון',
  'coupon': 'קופונים',
  'credit': 'מבצעי אשראי',
  'insurance': 'הטבות ביטוח רמי לוי',
  'minBasket': 'מותנה בקנייה מינימלית',
  'limit': 'מוגבל בכמות',
};

class Settings extends ChangeNotifier {
  late SharedPreferences _p;

  String storeId = '23';
  String storeName = 'גוש עציון';
  double minPct = 30;
  double minSave = 3;
  Set<String> hiddenTags = {};
  Set<String> hiddenCats = {};
  Set<String> hiddenDeals = {};
  SortBy sort = SortBy.pct;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    storeId = _p.getString('storeId') ?? storeId;
    storeName = _p.getString('storeName') ?? storeName;
    minPct = _p.getDouble('minPct') ?? minPct;
    minSave = _p.getDouble('minSave') ?? minSave;
    hiddenTags = (_p.getStringList('hiddenTags') ?? []).toSet();
    hiddenCats = (_p.getStringList('hiddenCats') ?? []).toSet();
    hiddenDeals = (_p.getStringList('hiddenDeals') ?? []).toSet();
    sort = SortBy.values[(_p.getInt('sort') ?? 0).clamp(0, SortBy.values.length - 1)];
  }

  void _save() {
    _p.setString('storeId', storeId);
    _p.setString('storeName', storeName);
    _p.setDouble('minPct', minPct);
    _p.setDouble('minSave', minSave);
    _p.setStringList('hiddenTags', hiddenTags.toList());
    _p.setStringList('hiddenCats', hiddenCats.toList());
    _p.setStringList('hiddenDeals', hiddenDeals.toList());
    _p.setInt('sort', sort.index);
    notifyListeners();
  }

  void setStore(String id, String name) {
    storeId = id;
    storeName = name;
    _save();
  }

  void setThresholds({double? pct, double? save}) {
    if (pct != null) minPct = pct;
    if (save != null) minSave = save;
    _save();
  }

  void setSort(SortBy s) {
    sort = s;
    _save();
  }

  void toggleTag(String tag, bool hidden) {
    hidden ? hiddenTags.add(tag) : hiddenTags.remove(tag);
    _save();
  }

  void toggleCat(String cat, bool hidden) {
    hidden ? hiddenCats.add(cat) : hiddenCats.remove(cat);
    _save();
  }

  void hideDeal(String id, bool hidden) {
    hidden ? hiddenDeals.add(id) : hiddenDeals.remove(id);
    _save();
  }

  void clearHiddenDeals() {
    hiddenDeals.clear();
    _save();
  }

  void setCats(Iterable<String> cats, bool hidden) {
    hidden ? hiddenCats.addAll(cats) : hiddenCats.removeAll(cats);
    _save();
  }
}
