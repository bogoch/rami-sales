import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../catalog.dart';
import '../category_style.dart';
import '../data.dart';
import '../logic.dart';
import '../models.dart';
import '../product_image.dart';
import '../settings.dart';
import '../shopping.dart';
import '../ui.dart';
import 'deal_card.dart';

/// Shared shopping list with catalog search, promo marks and an estimated total.
class ListScreen extends StatefulWidget {
  final Settings settings;
  final Api api;
  final DealsFile? file;
  const ListScreen({super.key, required this.settings, required this.api, required this.file});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen> {
  final _ctl = TextEditingController();
  final _focus = FocusNode();
  Catalog? _catalog;
  String _q = '';
  late final Map<String, Deal> _dealsById = {for (final d in widget.file?.deals ?? <Deal>[]) d.id: d};

  ShoppingList get sl => ShoppingList.instance;

  /// Coupons / insurance perks need extra steps, so the estimate ignores them (plus anything the user hid).
  Set<String> get _skip => {...widget.settings.hiddenTags, 'coupon', 'insurance'};

  @override
  void initState() {
    super.initState();
    sl.addListener(_changed);
    sl.pull();
    sl.startPolling();
    widget.api.catalog(widget.settings.storeId).then((c) {
      if (mounted) setState(() => _catalog = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    sl.stopPolling();
    sl.removeListener(_changed);
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _add(String name, {String? code}) async {
    if (name.trim().isEmpty) return;
    Haptics.commit();
    _ctl.clear();
    setState(() => _q = '');
    await sl.addItem(name.trim(), code: code);
  }

  ({double price, Deal? deal, DealItem? item})? _priceOf(ListItem i) {
    final p = i.code == null ? null : _catalog?.byCode[i.code];
    if (p == null) return null;
    return effectivePrice(p, _dealsById, skipTags: _skip);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final open = sl.items.where((i) => !i.done).toList()..sort((a, b) => a.ts.compareTo(b.ts));
    final done = sl.items.where((i) => i.done).toList()..sort((a, b) => b.ts.compareTo(a.ts));
    final suggestions = _q.length >= 2 ? (_catalog?.search(_q) ?? const <Product>[]) : const <Product>[];

    var total = 0.0, saved = 0.0;
    var unpriced = 0;
    for (final i in open) {
      final p = _priceOf(i);
      if (p == null) {
        unpriced++;
        continue;
      }
      total += p.price * i.qty;
      if (p.item != null) saved += (p.item!.regular - p.price) * i.qty;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('רשימת קניות'),
        actions: [
          if (sl.canShare)
            IconButton(
              tooltip: 'שיתוף עם הבית',
              icon: Icon(sl.household != null ? Icons.group_rounded : Icons.group_add_outlined),
              onPressed: () => _shareSheet(context),
            ),
          if (done.isNotEmpty)
            IconButton(
              tooltip: 'מחק את מה שכבר בעגלה',
              icon: const Icon(Icons.remove_done_rounded),
              onPressed: () {
                Haptics.commit();
                sl.clearDone();
              },
            ),
        ],
      ),
      body: Column(children: [
        if (sl.household != null && sl.syncError != null)
          Container(
            width: double.infinity,
            color: cs.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(sl.syncError!, style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12.5)),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _ctl,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onChanged: (v) => setState(() => _q = v.trim()),
            onSubmitted: (v) => _add(v),
            decoration: InputDecoration(
              hintText: 'מה צריך לקנות?',
              prefixIcon: const Icon(Icons.add_shopping_cart_rounded),
              suffixIcon: _q.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.keyboard_return_rounded), onPressed: () => _add(_ctl.text)),
              filled: true,
              fillColor: cs.surfaceContainerHigh,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ),
        Expanded(
          child: suggestions.isNotEmpty
              ? _suggestions(suggestions)
              : (open.isEmpty && done.isEmpty)
                  ? _empty(tt, cs)
                  : ListView(
                      physics: kScrollPhysics,
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      children: [
                        for (final i in open) _row(i),
                        if (done.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
                            child: Text('בעגלה · ${done.length}', style: tt.titleSmall),
                          ),
                        for (final i in done) _row(i),
                      ],
                    ),
        ),
        if (open.isNotEmpty) _totalBar(total, saved, unpriced, open.length),
      ]),
    );
  }

  Widget _empty(TextTheme tt, ColorScheme cs) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.shopping_basket_outlined, size: 52, color: cs.outline),
            const SizedBox(height: 12),
            Text('הרשימה ריקה', style: tt.titleMedium),
            const SizedBox(height: 6),
            Text(
              'כתוב מוצר למעלה, או החלק מבצע שמאלה ברשימת המבצעים כדי להוסיף אותו לכאן.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      );

  Widget _suggestions(List<Product> list) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: kScrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: [
        ListTile(
          leading: const Icon(Icons.edit_note_rounded),
          title: Text('הוסף "$_q"'),
          subtitle: const Text('בלי לבחור מוצר מסוים'),
          onTap: () => _add(_q),
        ),
        for (final p in list)
          Builder(builder: (context) {
            final ep = effectivePrice(p, _dealsById, skipTags: _skip);
            final c = p.cats.isEmpty ? null : p.cats.first;
            return ListTile(
              leading: ProductImage(
                code: p.code,
                size: 44,
                fallback: CategoryTile(icon: CategoryStyles.iconOfCat(c), color: CategoryStyles.colorOfCat(c), size: 44),
              ),
              title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([
                '₪${money(ep.price)}',
                if (ep.item != null) 'במבצע (במקום ₪${money(p.price)})',
                if (p.perUnit != null && unitLabel(p.unit) != null) '₪${money(p.perUnit!)} ${unitLabel(p.unit)}',
              ].join(' · ')),
              trailing: ep.item != null ? Icon(Icons.local_offer_rounded, color: cs.primary, size: 20) : null,
              onTap: () => _add(p.name, code: p.code),
            );
          }),
      ],
    );
  }

  Widget _row(ListItem i) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final p = i.code == null ? null : _catalog?.byCode[i.code];
    final ep = _priceOf(i);
    final c = (p?.cats.isEmpty ?? true) ? null : p!.cats.first;
    return Dismissible(
      key: ValueKey(i.id),
      direction: DismissDirection.horizontal,
      background: Container(
        alignment: AlignmentDirectional.centerStart,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
      ),
      secondaryBackground: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.delete_outline_rounded, color: cs.onErrorContainer),
      ),
      onDismissed: (_) {
        Haptics.commit();
        final copy = ListItem.fromJson(i.toJson());
        sl.remove(i.id);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('"${i.name}" נמחק'),
            action: SnackBarAction(label: 'בטל', onPressed: () => sl.restore(copy)),
          ));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Pressable(
          pressedScale: 0.98,
          onTap: () {
            Haptics.select();
            sl.toggleDone(i.id);
          },
          onLongPress: ep?.deal == null ? null : () => showDealSheet(context, ep!.deal!, widget.settings.storeName),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: i.done ? 0.5 : 1,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              decoration: BoxDecoration(
                color: cs.brightness == Brightness.dark ? cs.surfaceContainerHigh : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Icon(i.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: i.done ? cs.primary : cs.outline),
                const SizedBox(width: 10),
                if (i.code != null) ...[
                  ProductImage(
                    code: i.code!,
                    size: 40,
                    fallback:
                        CategoryTile(icon: CategoryStyles.iconOfCat(c), color: CategoryStyles.colorOfCat(c), size: 40),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyLarge?.copyWith(decoration: i.done ? TextDecoration.lineThrough : null)),
                    if (ep != null || i.by.isNotEmpty)
                      Text(
                        [
                          if (ep != null) '₪${money(ep.price * i.qty)}',
                          if (ep?.item != null) 'במבצע${ep!.deal!.buyQty > 1 ? ' (${offerText(ep.deal!)})' : ''}',
                          if (i.by.isNotEmpty && sl.household != null) 'הוסיף/ה: ${i.by}',
                        ].join(' · '),
                        style: tt.bodySmall?.copyWith(color: ep?.item != null ? cs.primary : cs.onSurfaceVariant),
                      ),
                  ]),
                ),
                if (!i.done) _qty(i),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _qty(ListItem i) => Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(i.qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded, size: 20),
          onPressed: () {
            Haptics.select();
            sl.setQty(i.id, i.qty - 1);
          },
        ),
        Text('${i.qty}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_rounded, size: 20),
          onPressed: () {
            Haptics.select();
            sl.setQty(i.id, i.qty + 1);
          },
        ),
      ]);

  Widget _totalBar(double total, double saved, int unpriced, int count) {
    final cs = Theme.of(context).colorScheme;
    return Glass(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('הערכה: ₪${money(total)}', style: display(context, 20, weight: FontWeight.w700)),
                Text(
                  [
                    '$count פריטים',
                    if (saved > 0.5) 'חוסכים ₪${money(saved)} במבצעים',
                    if (unpriced > 0) '$unpriced בלי מחיר',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ]),
            ),
            if (_catalog == null) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
        ),
      ),
    );
  }

  void _shareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _ShareHousehold(),
      ),
    );
  }
}

class _ShareHousehold extends StatefulWidget {
  @override
  State<_ShareHousehold> createState() => _ShareHouseholdState();
}

class _ShareHouseholdState extends State<_ShareHousehold> {
  final _name = TextEditingController(text: ShoppingList.instance.me);
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;

  ShoppingList get sl => ShoppingList.instance;

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await sl.setMe(_name.text);
      await f();
    } catch (e) {
      _err = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final code = sl.household;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('רשימה משותפת לבית', style: display(context, 22, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('כולם רואים ועורכים את אותה רשימה, והשינויים מופיעים אצל כולם תוך כמה שניות.', style: tt.bodySmall),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'השם שלך (יופיע ליד מה שהוספת)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        if (code != null) ...[
          Text('קוד הבית:', style: tt.titleSmall),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: SelectableText(code,
                  textDirection: TextDirection.ltr, style: display(context, 24, weight: FontWeight.w700)),
            ),
            IconButton(
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                Haptics.commit();
              },
            ),
          ]),
          Text('שלח את הקוד לבני הבית. הם מזינים אותו באפליקציה שלהם ב"הצטרף לרשימה קיימת".', style: tt.bodySmall),
          const SizedBox(height: 12),
          TextButton(onPressed: _busy ? null : () => _run(sl.leaveHousehold), child: const Text('הפסק לשתף בטלפון הזה')),
        ] else ...[
          FilledButton.icon(
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('צור רשימה משותפת'),
            onPressed: _busy ? null : () => _run(() async => sl.createHousehold()),
          ),
          const SizedBox(height: 20),
          Text('או הצטרף לרשימה קיימת:', style: tt.titleSmall),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'קוד הבית', border: OutlineInputBorder(), isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _busy ? null : () => _run(() => sl.joinHousehold(_code.text)),
              child: const Text('הצטרף'),
            ),
          ]),
        ],
        if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
        if (_err != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_err!)),
      ]),
    );
  }
}
