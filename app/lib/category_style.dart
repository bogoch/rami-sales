import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'models.dart';

/// Visual identity per category group: one hue, used for icon tiles and accents.
class GroupStyle {
  final Color color;
  final IconData icon;
  const GroupStyle(this.color, this.icon);
}

const _groupStyles = <String, GroupStyle>{
  'מוצרי חלב וביצים': GroupStyle(Color(0xFF2F6FDB), PhosphorIconsDuotone.cheese),
  'לחם ומאפים': GroupStyle(Color(0xFFC77700), PhosphorIconsDuotone.bread),
  'בשר ודגים': GroupStyle(Color(0xFFC62828), PhosphorIconsDuotone.cow),
  'פירות וירקות': GroupStyle(Color(0xFF2E9447), PhosphorIconsDuotone.carrot),
  'קפואים': GroupStyle(Color(0xFF0E8FB0), PhosphorIconsDuotone.snowflake),
  'מזווה': GroupStyle(Color(0xFFD9541E), PhosphorIconsDuotone.cookingPot),
  'שתייה': GroupStyle(Color(0xFF0F9488), PhosphorIconsDuotone.coffee),
  'חטיפים ומתוקים': GroupStyle(Color(0xFFD1356B), PhosphorIconsDuotone.cookie),
  'בית וטיפוח': GroupStyle(Color(0xFF7346D9), PhosphorIconsDuotone.sparkle),
};

const _fallback = GroupStyle(Color(0xFF64748B), PhosphorIconsDuotone.tag);

const _catIcons = <String, IconData>{
  'milk': PhosphorIconsDuotone.drop,
  'plant_milk': PhosphorIconsDuotone.leaf,
  'choco_milk': PhosphorIconsDuotone.drop,
  'cheese': PhosphorIconsDuotone.cheese,
  'yogurt': PhosphorIconsDuotone.bowlFood,
  'butter': PhosphorIconsDuotone.cheese,
  'eggs': PhosphorIconsDuotone.egg,
  'bread': PhosphorIconsDuotone.bread,
  'cakes': PhosphorIconsDuotone.cake,
  'chicken': PhosphorIconsDuotone.bird,
  'beef': PhosphorIconsDuotone.cow,
  'fish': PhosphorIconsDuotone.fish,
  'deli': PhosphorIconsDuotone.hamburger,
  'vegetables': PhosphorIconsDuotone.carrot,
  'fruit': PhosphorIconsDuotone.orangeSlice,
  'frozen_veg': PhosphorIconsDuotone.snowflake,
  'frozen_meals': PhosphorIconsDuotone.pizza,
  'ice_cream': PhosphorIconsDuotone.iceCream,
  'rice_pasta': PhosphorIconsDuotone.grains,
  'flour_sugar': PhosphorIconsDuotone.grains,
  'oil': PhosphorIconsDuotone.drop,
  'spreads': PhosphorIconsDuotone.knife,
  'canned': PhosphorIconsDuotone.package,
  'sauces_spices': PhosphorIconsDuotone.pepper,
  'cereal': PhosphorIconsDuotone.bowlFood,
  'coffee_tea': PhosphorIconsDuotone.coffee,
  'soft_drinks': PhosphorIconsDuotone.orange,
  'water': PhosphorIconsDuotone.drop,
  'alcohol': PhosphorIconsDuotone.wine,
  'snacks': PhosphorIconsDuotone.popcorn,
  'sweets': PhosphorIconsDuotone.cookie,
  'baby': PhosphorIconsDuotone.baby,
  'hygiene': PhosphorIconsDuotone.sparkle,
  'cleaning': PhosphorIconsDuotone.broom,
  'disposables': PhosphorIconsDuotone.forkKnife,
  'pets': PhosphorIconsDuotone.pawPrint,
  'home_textile': PhosphorIconsDuotone.tShirt,
};

/// Global lookup filled once categories.json is loaded.
class CategoryStyles {
  static final Map<String, String> _groupOf = {};

  static void load(List<ProductCategory> cats) {
    _groupOf
      ..clear()
      ..addEntries(cats.map((c) => MapEntry(c.id, c.group)));
  }

  static GroupStyle group(String group) => _groupStyles[group] ?? _fallback;

  static Color colorOfCat(String? catId) =>
      catId == null ? _fallback.color : group(_groupOf[catId] ?? '').color;

  static IconData iconOfCat(String? catId) => _catIcons[catId] ?? _fallback.icon;

  static String? primaryCat(Deal d) => d.cats.isEmpty ? null : d.cats.first;
}

/// Rounded square with a soft tint and a duotone icon in the category hue.
class CategoryTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const CategoryTile({super.key, required this.icon, required this.color, this.size = 48});

  factory CategoryTile.forDeal(Deal d, {double size = 48}) {
    final c = CategoryStyles.primaryCat(d);
    return CategoryTile(icon: CategoryStyles.iconOfCat(c), color: CategoryStyles.colorOfCat(c), size: size);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: PhosphorIcon(icon, size: size * 0.56, color: dark ? Color.lerp(color, Colors.white, 0.35) : color),
    );
  }
}

/// Discount strength → color, so strong deals stand out at a glance.
Color pctColor(BuildContext context, double pct) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (pct >= 50) return dark ? const Color(0xFFFF6B6B) : const Color(0xFFC1121F);
  if (pct >= 30) return dark ? const Color(0xFFFFA94D) : const Color(0xFFD9480F);
  return Theme.of(context).colorScheme.onSurface;
}
