// Data models matching the JSON produced by pipeline/build.py.

double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();
double? _dn(dynamic v) => v == null ? null : (v as num).toDouble();

class DealItem {
  final String code;
  final String name;
  final double regular;
  final double promo;
  final double pct;
  final double save;
  final String? unit; // kg / l / unit
  final double? regPU;
  final double? promoPU;
  final double? min30;
  final bool complex;

  DealItem.fromJson(Map<String, dynamic> j)
      : code = j['code'] as String,
        name = j['name'] as String,
        regular = _d(j['regular']),
        promo = _d(j['promo']),
        pct = _d(j['pct']),
        save = _d(j['save']),
        unit = j['unit'] as String?,
        regPU = _dn(j['regPU']),
        promoPU = _dn(j['promoPU']),
        min30 = _dn(j['min30']),
        complex = j['complex'] == true;
}

class Deal {
  final String id;
  final String desc;
  final DateTime? start;
  final DateTime? end;
  final DateTime? firstSeen;
  final double pct;
  final double save;
  final double buyQty;
  final List<String> cats;
  final List<String> tags;
  final double? minBasket;
  final int? limit;
  final List<DealItem> items;

  Deal.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        desc = prettyDesc(j['desc'] as String),
        start = DateTime.tryParse((j['start'] ?? '') as String),
        end = DateTime.tryParse((j['end'] ?? '') as String),
        firstSeen = DateTime.tryParse((j['firstSeen'] ?? '') as String),
        pct = _d(j['pct']),
        save = _d(j['save']),
        buyQty = _d(j['buyQty'] ?? 1),
        cats = List<String>.from(j['cats'] as List? ?? const []),
        tags = List<String>.from(j['tags'] as List? ?? const []),
        minBasket = _dn(j['minBasket']),
        limit = (j['limit'] as num?)?.toInt(),
        items = (j['items'] as List)
            .map((e) => DealItem.fromJson(e as Map<String, dynamic>))
            .toList();

  bool get isComplex => tags.contains('complex');
  DealItem get best => items.first;

  /// Text used for free-text search.
  late final String searchText =
      ('$desc ${items.map((e) => e.name).join(' ')}').toLowerCase();
}

class DealsFile {
  final String store;
  final DateTime generated;
  final List<Deal> deals;

  DealsFile.fromJson(Map<String, dynamic> j)
      : store = j['store'] as String,
        generated = DateTime.parse(j['generated'] as String),
        deals = (j['deals'] as List)
            .map((e) => Deal.fromJson(e as Map<String, dynamic>))
            .toList();
}

class Store {
  final String id;
  final String name;
  final String address;
  final String city;
  final double? lat;
  final double? lon;
  final bool hasData;
  final int deals;

  Store.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        address = (j['address'] ?? '') as String,
        city = (j['city'] ?? '') as String,
        lat = _dn(j['lat']),
        lon = _dn(j['lon']),
        hasData = j['hasData'] == true,
        deals = (j['deals'] as num?)?.toInt() ?? 0;
}

class ProductCategory {
  final String id;
  final String name;
  final String group;

  ProductCategory.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        group = j['group'] as String;
}

/// Cleans Rami Levy's terse promo descriptions and fixes bidi-hostile patterns:
/// "2ב10" renders as "10ב2" in RTL, so it becomes "2 ב־10" — the Hebrew maqaf (U+05BE) is a strong
/// RTL character, unlike "-", so the number stays after the letter. "מו3" → "(מוגבל ל־3)".
String prettyDesc(String s) {
  var t = ' $s ';
  t = t.replaceAllMapped(RegExp(r'(?<=\s)(\d+)\s*ב\s*-?\s*(\d+(?:\.\d+)?)'), (m) => '${m[1]} ב־${m[2]}');
  t = t.replaceAllMapped(RegExp(r'(?<=\s)ב-?(\d+(?:\.\d+)?)'), (m) => 'ב־${m[1]}');
  t = t.replaceAllMapped(RegExp(r'(?<=\s)מו(\d+)(?=\s)'), (m) => '(מוגבל ל־${m[1]})');
  const words = {
    ' ש ח ': ' ₪ ',
    ' מ ל ': ' מ"ל ',
    ' ק ג ': ' ק"ג ',
    ' לל ג ': ' ללא גלוטן ',
    ' לל ס ': ' ללא סוכר ',
    ' לי ': ' ל\' ',
  };
  for (final e in words.entries) {
    t = t.replaceAll(e.key, e.value);
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}
