import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'models.dart';

/// Visual identity per category group: one hue, used for icon tiles and accents.
class GroupStyle {
  final Color color;
  final String icon;
  const GroupStyle(this.color, this.icon);
}

const _groupStyles = <String, GroupStyle>{
  'מוצרי חלב וביצים': GroupStyle(Color(0xFF2F6FDB), 'cheese'),
  'לחם ומאפים': GroupStyle(Color(0xFFC77700), 'bread'),
  'בשר ודגים': GroupStyle(Color(0xFFC62828), 'cow'),
  'פירות וירקות': GroupStyle(Color(0xFF2E9447), 'carrot'),
  'קפואים': GroupStyle(Color(0xFF0E8FB0), 'snowflake'),
  'מזווה': GroupStyle(Color(0xFFD9541E), 'cooking-pot'),
  'שתייה': GroupStyle(Color(0xFF0F9488), 'coffee'),
  'חטיפים ומתוקים': GroupStyle(Color(0xFFD1356B), 'cookie'),
  'בית וטיפוח': GroupStyle(Color(0xFF7346D9), 'sparkle'),
};

const _fallback = GroupStyle(Color(0xFF64748B), 'tag');

const _catIcons = <String, String>{
  'milk': 'drop',
  'plant_milk': 'leaf',
  'choco_milk': 'drop',
  'cheese': 'cheese',
  'yogurt': 'bowl-food',
  'butter': 'cheese',
  'eggs': 'egg',
  'bread': 'bread',
  'cakes': 'cake',
  'chicken': 'bird',
  'beef': 'cow',
  'fish': 'fish',
  'deli': 'hamburger',
  'vegetables': 'carrot',
  'fruit': 'orange-slice',
  'frozen_veg': 'snowflake',
  'frozen_meals': 'pizza',
  'ice_cream': 'ice-cream',
  'rice_pasta': 'grains',
  'flour_sugar': 'grains',
  'oil': 'drop',
  'spreads': 'knife',
  'canned': 'package',
  'sauces_spices': 'pepper',
  'cereal': 'bowl-food',
  'coffee_tea': 'coffee',
  'soft_drinks': 'orange',
  'water': 'drop',
  'alcohol': 'wine',
  'snacks': 'popcorn',
  'sweets': 'cookie',
  'baby': 'baby',
  'hygiene': 'sparkle',
  'cleaning': 'broom',
  'disposables': 'fork-knife',
  'pets': 'paw-print',
  'home_textile': 't-shirt',
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

  static String iconOfCat(String? catId) => _catIcons[catId] ?? _fallback.icon;

  static String? primaryCat(Deal d) => d.cats.isEmpty ? null : d.cats.first;
}

/// Rounded square with a soft tint and a duotone icon in the category hue.
class CategoryTile extends StatelessWidget {
  final String icon;
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
      child: PIcon(icon, size: size * 0.56, color: dark ? Color.lerp(color, Colors.white, 0.35)! : color),
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

/// Phosphor duotone icon from bundled SVG assets (MIT licensed).
/// srcIn keeps each path's alpha, so the 20% duotone fill is preserved.
class PIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;
  const PIcon(this.name, {super.key, this.size = 24, required this.color});

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
