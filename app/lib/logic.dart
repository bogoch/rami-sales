import 'models.dart';
import 'settings.dart';

String money(double v) {
  final s = v.toStringAsFixed(2);
  return s.endsWith('.00') ? s.substring(0, s.length - 3) : s;
}

String pctText(double v) => '${v.round()}%';

String? unitLabel(String? unit) => switch (unit) {
      'kg' => 'לק״ג',
      'l' => 'לליטר',
      _ => null,
    };

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "today" according to the data file, so badges don't depend on the phone clock.
bool isNew(Deal d, DateTime dataDate) =>
    d.firstSeen != null && !dateOnly(d.firstSeen!).isBefore(dateOnly(dataDate));

/// Days left until the promo ends (0 = ends today), null if far away / unknown.
int? daysLeft(Deal d, DateTime now) {
  if (d.end == null) return null;
  final left = dateOnly(d.end!).difference(dateOnly(now)).inDays;
  return left < 0 ? null : left;
}

String? endingText(Deal d, DateTime now) {
  final left = daysLeft(d, now);
  if (left == null || left > 3) return null;
  return switch (left) {
    0 => 'נגמר היום',
    1 => 'נגמר מחר',
    _ => 'נגמר בעוד $left ימים',
  };
}

const tagLabels = {
  'club': 'מועדון',
  'coupon': 'קופון',
  'credit': 'באשראי',
  'insurance': 'הטבת ביטוח',
  'gift': 'מתנה',
  'complex': 'מבצע מורכב',
};

List<String> tagTexts(Deal d) {
  final out = <String>[];
  for (final t in d.tags) {
    if (t == 'minBasket') {
      out.add(d.minBasket != null ? 'בקנייה מעל ₪${money(d.minBasket!)}' : 'מותנה בסכום קנייה');
    } else if (t == 'limit') {
      out.add('מוגבל ל־${d.limit}');
    } else if (tagLabels.containsKey(t)) {
      out.add(tagLabels[t]!);
    }
  }
  return out;
}

/// What the promo asks you to buy, e.g. "2 ב-₪20" or "₪9.90".
String offerText(Deal d) {
  final it = d.best;
  if (d.buyQty > 1) {
    return '${d.buyQty.round()} ב־₪${money(it.promo * d.buyQty)}';
  }
  return '₪${money(it.promo)}${it.unit == 'kg' && it.regPU == it.regular ? ' לק״ג' : ''}';
}

class Filter {
  final String query;
  final Set<String>? groupCats; // null = all categories

  const Filter({this.query = '', this.groupCats});
}

bool _hiddenByCats(Deal d, Set<String> hidden) =>
    hidden.isNotEmpty && d.cats.isNotEmpty && d.cats.every(hidden.contains);

bool _hiddenByTags(Deal d, Set<String> hidden) => d.tags.any(hidden.contains);

bool _matches(Deal d, Filter f) {
  if (f.groupCats != null && !d.cats.any(f.groupCats!.contains)) return false;
  if (f.query.isNotEmpty) {
    final words = f.query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (!words.every(d.searchText.contains)) return false;
  }
  return true;
}

List<Deal> goodDeals(List<Deal> all, Settings s, Filter f) {
  final out = all
      .where((d) =>
          !d.isComplex &&
          !s.hiddenDeals.contains(d.id) &&
          d.pct >= s.minPct &&
          d.save >= s.minSave &&
          !_hiddenByTags(d, s.hiddenTags) &&
          !_hiddenByCats(d, s.hiddenCats) &&
          _matches(d, f))
      .toList();
  _sort(out, s.sort);
  return out;
}

List<Deal> complexDeals(List<Deal> all, Settings s, Filter f) {
  final out = all
      .where((d) =>
          d.isComplex &&
          !s.hiddenDeals.contains(d.id) &&
          !_hiddenByTags(d, s.hiddenTags) &&
          !_hiddenByCats(d, s.hiddenCats) &&
          _matches(d, f))
      .toList();
  out.sort((a, b) => (a.end ?? DateTime(2100)).compareTo(b.end ?? DateTime(2100)));
  return out;
}

void _sort(List<Deal> list, SortBy by) {
  int cmpNum(double a, double b) => b.compareTo(a);
  switch (by) {
    case SortBy.pct:
      list.sort((a, b) => cmpNum(a.pct, b.pct) != 0 ? cmpNum(a.pct, b.pct) : cmpNum(a.save, b.save));
    case SortBy.save:
      list.sort((a, b) => cmpNum(a.save, b.save));
    case SortBy.perUnit:
      double pu(Deal d) => d.best.promoPU ?? double.infinity;
      list.sort((a, b) => pu(a).compareTo(pu(b)));
    case SortBy.newest:
      list.sort((a, b) =>
          (b.firstSeen ?? DateTime(2000)).compareTo(a.firstSeen ?? DateTime(2000)));
    case SortBy.ending:
      list.sort((a, b) => (a.end ?? DateTime(2100)).compareTo(b.end ?? DateTime(2100)));
  }
}

String shareText(Deal d, String storeName) {
  final it = d.best;
  final b = StringBuffer()
    ..writeln('🔥 ${d.desc}')
    ..writeln(d.isComplex
        ? it.name
        : '${it.name}: ₪${money(it.regular)} ← ${offerText(d)} (${pctText(d.pct)} הנחה)');
  final tags = tagTexts(d);
  if (tags.isNotEmpty) b.writeln(tags.join(' · '));
  if (d.end != null) b.writeln('עד ${d.end!.day}.${d.end!.month}');
  b.write('רמי לוי $storeName');
  return b.toString();
}
