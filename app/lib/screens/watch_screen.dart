import 'package:flutter/material.dart';

import '../background.dart';
import '../category_style.dart';
import '../models.dart';
import '../settings.dart';
import '../ui.dart';
import '../watch.dart';
import 'deal_card.dart';

/// "מעקב": what the user follows, and which of it is on sale right now.
class WatchScreen extends StatefulWidget {
  final Settings settings;
  final DealsFile? file;
  final List<ProductCategory> categories;
  const WatchScreen({super.key, required this.settings, required this.file, required this.categories});

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  final _text = TextEditingController();
  Watchlist get wl => Watchlist.instance;

  @override
  void initState() {
    super.initState();
    wl.addListener(_changed);
  }

  @override
  void dispose() {
    wl.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> _addText() async {
    final v = _text.text.trim();
    if (v.isEmpty) return;
    Haptics.commit();
    await wl.add(WatchItem('text', v, v));
    _text.clear();
    await _ensurePermission();
  }

  Future<void> _ensurePermission() async {
    if (wl.mode != NotifyMode.off) await requestNotificationPermission();
  }

  void _pickCategory() {
    final groups = <String, List<ProductCategory>>{};
    for (final c in widget.categories) {
      groups.putIfAbsent(c.group, () => []).add(c);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListenableBuilder(
          listenable: wl,
          builder: (_, __) => ListView(
            controller: controller,
            physics: kScrollPhysics,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text('לעקוב אחרי קטגוריה', style: display(ctx, 22, weight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('תקבל התראה על כל מבצע בקטגוריה, בלי קשר ליצרן.', style: Theme.of(ctx).textTheme.bodySmall),
              for (final g in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 6),
                  child: Text(g.key, style: Theme.of(ctx).textTheme.titleSmall),
                ),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in g.value)
                    FilterChip(
                      avatar: PIcon(CategoryStyles.iconOfCat(c.id), size: 18, color: CategoryStyles.colorOfCat(c.id)),
                      label: Text(c.name),
                      selected: wl.has('cat', c.id),
                      showCheckmark: false,
                      onSelected: (_) async {
                        Haptics.select();
                        await wl.toggle(WatchItem('cat', c.id, c.name));
                        await _ensurePermission();
                      },
                    ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final file = widget.file;
    final matches = file == null ? <Deal>[] : wl.matches(file.deals, hiddenTags: widget.settings.hiddenTags);

    return Scaffold(
      appBar: AppBar(title: const Text('מעקב')),
      body: ListView(
        physics: kScrollPhysics,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
            child: Text('אני עוקב אחרי', style: display(context, 19, weight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addText(),
                  decoration: InputDecoration(
                    hintText: 'מוצר או מילה, למשל "קפה עלית"',
                    filled: true,
                    fillColor: cs.surfaceContainerHigh,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _addText, icon: const Icon(Icons.add_rounded)),
            ]),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              ActionChip(
                avatar: const Icon(Icons.category_rounded, size: 18),
                label: const Text('הוסף קטגוריה'),
                onPressed: widget.categories.isEmpty ? null : _pickCategory,
              ),
              for (final w in wl.items)
                InputChip(
                  avatar: w.type == 'cat'
                      ? PIcon(CategoryStyles.iconOfCat(w.value), size: 18, color: CategoryStyles.colorOfCat(w.value))
                      : Icon(w.type == 'product' ? Icons.qr_code_rounded : Icons.search_rounded, size: 18),
                  label: Text(w.label, overflow: TextOverflow.ellipsis),
                  onDeleted: () {
                    Haptics.select();
                    wl.remove(w);
                  },
                ),
            ]),
          ),
          if (wl.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'הוסף מוצרים, מילים או קטגוריות, ותקבל התראה כשהם במבצע.\n'
                'אפשר גם ללחוץ על ☆ ליד מוצר בדף של מבצע.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            color: cs.surfaceContainerHigh,
            child: Column(children: [
              for (final m in NotifyMode.values)
                RadioListTile<NotifyMode>(
                  value: m,
                  groupValue: wl.mode,
                  title: Text(notifyModeLabels[m]!),
                  subtitle: m == NotifyMode.daily
                      ? const Text('פעם ביום, בבוקר')
                      : m == NotifyMode.instant
                          ? const Text('בכל עדכון נתונים (לא בין 22:00 ל-8:00)')
                          : null,
                  onChanged: (v) async {
                    Haptics.select();
                    await wl.setMode(v!);
                    await _ensurePermission();
                  },
                ),
            ]),
          ),
          if (wl.items.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 4),
              child: Text(
                matches.isEmpty ? 'שום דבר מהרשימה לא במבצע כרגע' : 'במבצע עכשיו · ${matches.length}',
                style: display(context, 19, weight: FontWeight.w700),
              ),
            ),
            if (file != null)
              for (final (i, d) in matches.indexed)
                Appear(
                  key: ValueKey('w_${d.id}'),
                  index: i,
                  child: DealCard(deal: d, dataDate: file.generated, storeName: widget.settings.storeName),
                ),
          ],
        ],
      ),
    );
  }
}
