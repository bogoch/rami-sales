import 'models.dart';

/// One product in the store catalog (compact rows from catalog/<store>.json).
class Product {
  final String code;
  final String name;
  final String manuf;
  final double price;
  final String? unit;
  final double? perUnit;
  final List<String> cats;
  final String? promoId;
  late final String _search = '$name $manuf'.toLowerCase();

  Product(this.code, this.name, this.manuf, this.price, this.unit, this.perUnit, this.cats, this.promoId);

  bool matches(List<String> words) => words.every(_search.contains);
}

class Catalog {
  final List<Product> products;
  final Map<String, Product> byCode;
  Catalog(this.products) : byCode = {for (final p in products) p.code: p};

  static Catalog fromJson(Map<String, dynamic> j) {
    final cols = List<String>.from(j['cols'] as List);
    int ix(String c) => cols.indexOf(c);
    final iCode = ix('code'), iName = ix('name'), iManuf = ix('manuf'), iPrice = ix('price');
    final iUnit = ix('unit'), iPU = ix('perUnit'), iCats = ix('cats'), iPromo = ix('promoId');
    final out = <Product>[];
    for (final r in (j['rows'] as List)) {
      final row = r as List;
      out.add(Product(
        row[iCode] as String,
        row[iName] as String,
        (row[iManuf] ?? '') as String,
        (row[iPrice] as num).toDouble(),
        row[iUnit] as String?,
        (row[iPU] as num?)?.toDouble(),
        List<String>.from((row[iCats] ?? const []) as List),
        row[iPromo] as String?,
      ));
    }
    return Catalog(out);
  }

  /// Search by words; products on promotion first, then shortest names (most generic).
  List<Product> search(String q, {int limit = 8}) {
    final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    final hits = products.where((p) => p.matches(words)).toList()
      ..sort((a, b) {
        if ((a.promoId != null) != (b.promoId != null)) return a.promoId != null ? -1 : 1;
        return a.name.length.compareTo(b.name.length);
      });
    return hits.take(limit).toList();
  }
}

/// Effective unit price for a product given today's deals (promo unit price when on sale).
({double price, Deal? deal, DealItem? item}) effectivePrice(Product p, Map<String, Deal> dealsById) {
  final d = p.promoId == null ? null : dealsById[p.promoId];
  if (d != null && !d.isComplex) {
    for (final it in d.items) {
      if (it.code == p.code && !it.complex) return (price: it.promo, deal: d, item: it);
    }
  }
  return (price: p.price, deal: null, item: null);
}
