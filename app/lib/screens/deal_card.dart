import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../category_style.dart';
import '../logic.dart';
import '../models.dart';
import '../product_image.dart';
import '../ui.dart';
import '../shopping.dart';
import '../watch.dart';

class DealCard extends StatelessWidget {
  final Deal deal;
  final DateTime dataDate;
  final String storeName;
  const DealCard({super.key, required this.deal, required this.dataDate, required this.storeName});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final it = deal.best;
    final ending = endingText(deal, DateTime.now());
    final fresh = isNew(deal, dataDate);
    final pu = unitLabel(it.unit);
    final showPU = pu != null && it.promoPU != null && it.regPU != it.regular;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Pressable(
        onTap: () => showDealSheet(context, deal, storeName),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: cs.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductImage(code: deal.best.code, size: 64, fallback: CategoryTile.forDeal(deal, size: 64)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                        TextSpan(children: [
                          if (Watchlist.instance.watched(deal))
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: const EdgeInsetsDirectional.only(end: 4),
                                child: Icon(Icons.notifications_active_rounded, size: 15, color: cs.primary),
                              ),
                            ),
                          TextSpan(text: deal.desc),
                        ]),
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600, height: 1.25),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      deal.items.length > 1 ? '${it.name} ועוד ${deal.items.length - 1}' : it.name,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!deal.isComplex) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 8,
                        children: [
                          Text(offerText(deal), style: display(context, 18, weight: FontWeight.w700)),
                          Text(
                            '₪${money(it.regular)}',
                            style: tt.bodyMedium?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      if (showPU)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('₪${money(it.promoPU!)} $pu · במקום ₪${money(it.regPU!)}',
                              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                        ),
                    ],
                    if (fresh || ending != null || deal.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (fresh) _Tag('חדש היום', color: cs.tertiaryContainer, fg: cs.onTertiaryContainer),
                        if (ending != null) _Tag(ending, color: cs.errorContainer, fg: cs.onErrorContainer),
                        for (final t in tagTexts(deal)) _Tag(t),
                      ]),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PctBadge(deal: deal),
            ],
          ),
        ),
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  final Deal deal;
  const _PctBadge({required this.deal});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (deal.isComplex) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(16)),
        child: Icon(deal.tags.contains('gift') ? Icons.card_giftcard_rounded : Icons.help_outline_rounded,
            color: cs.onSecondaryContainer),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('${deal.pct.round()}%',
            textDirection: TextDirection.ltr, style: display(context, 28, color: pctColor(context, deal.pct))),
        Text('הנחה', style: TextStyle(fontSize: 11, color: pctColor(context, deal.pct), fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('₪${money(deal.best.save * deal.buyQty)}',
            textDirection: TextDirection.ltr,
            style: display(context, 14, weight: FontWeight.w700, color: cs.onSurface)),
        Text('חיסכון', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? fg;
  const _Tag(this.text, {this.color, this.fg});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color ?? cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 11.5, letterSpacing: 0.1, fontWeight: FontWeight.w500, color: fg ?? cs.onSecondaryContainer)),
    );
  }
}

void showDealSheet(BuildContext context, Deal deal, String storeName) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      final tt = Theme.of(ctx).textTheme;
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProductImage(code: deal.best.code, size: 72, large: true, fallback: CategoryTile.forDeal(deal, size: 72)),
              const SizedBox(width: 14),
              Expanded(child: Text(deal.desc, style: display(ctx, 22, weight: FontWeight.w700))),
            ]),
            const SizedBox(height: 4),
            Text(
              [
                if (deal.end != null) 'בתוקף עד ${deal.end!.day}.${deal.end!.month}.${deal.end!.year}',
                ...tagTexts(deal),
              ].join(' · '),
              style: tt.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('שתף בוואטסאפ'),
                  onPressed: () {
                    Haptics.commit();
                    launchUrl(
                    Uri.parse('https://wa.me/?text=${Uri.encodeComponent(shareText(deal, storeName))}'),
                    mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                icon: const Icon(Icons.copy),
                tooltip: 'העתק',
                onPressed: () {
                  Haptics.commit();
                  Clipboard.setData(ClipboardData(text: shareText(deal, storeName)));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('הועתק')));
                },
              ),
            ]),
            const SizedBox(height: 16),
            Text('מוצרים במבצע (${deal.items.length})', style: tt.titleSmall),
            for (final it in deal.items.take(60)) _ItemRow(item: it, deal: deal),
          ],
        ),
      );
    },
  );
}

class _ItemRow extends StatelessWidget {
  final DealItem item;
  final Deal deal;
  const _ItemRow({required this.item, required this.deal});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final pu = unitLabel(item.unit);
    final lines = <String>[
      if (!item.complex) '₪${money(item.regular)} ← ₪${money(item.promo)} ליחידה (${pctText(item.pct)})'
      else 'מחיר רגיל ₪${money(item.regular)}',
      if (pu != null && item.regPU != null && item.regPU != item.regular)
        item.promoPU != null
            ? '₪${money(item.regPU!)} ← ₪${money(item.promoPU!)} $pu'
            : '₪${money(item.regPU!)} $pu',
      if (item.min30 != null) 'המחיר הרגיל היה ₪${money(item.min30!)} בחודש האחרון',
    ];
    final wl = Watchlist.instance;
    return ListenableBuilder(
      listenable: wl,
      builder: (context, _) {
        final on = wl.has('product', item.code);
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: ProductImage(code: item.code, size: 48, fallback: CategoryTile.forDeal(deal, size: 48)),
          title: Text(item.name),
          subtitle: Text('${lines.join('\n')}\n${item.code}', style: tt.bodySmall),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: 'הוסף לרשימת הקניות',
              icon: const Icon(Icons.add_shopping_cart_rounded),
              onPressed: () {
                Haptics.commit();
                ShoppingList.instance.addItem(item.name, code: item.code, qty: deal.buyQty > 1 ? deal.buyQty.round() : 1);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('נוסף לרשימה: ${item.name}')));
              },
            ),
            IconButton(
              tooltip: on ? 'הפסק לעקוב' : 'עקוב אחרי המוצר',
              icon: Icon(on ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: on ? const Color(0xFFF2A900) : null),
              onPressed: () {
                Haptics.select();
                wl.toggle(WatchItem('product', item.code, item.name));
              },
            ),
          ]),
        );
      },
    );
  }
}
