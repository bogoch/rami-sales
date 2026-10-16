import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../settings.dart';
import '../ui.dart';
import '../updater.dart';
import 'store_picker.dart';

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  final Api api;
  final List<ProductCategory> categories;
  final Updater updater;
  const SettingsScreen(
      {super.key, required this.settings, required this.api, required this.categories, required this.updater});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([settings, updater]),
      builder: (context, _) {
        final s = settings;
        final tt = Theme.of(context).textTheme;
        final groups = <String, List<ProductCategory>>{};
        for (final c in categories) {
          groups.putIfAbsent(c.group, () => []).add(c);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('הגדרות')),
          body: ListView(
            physics: kScrollPhysics,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              ListTile(
                leading: const Icon(Icons.store),
                title: const Text('סניף'),
                subtitle: Text(s.storeName),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(FluidRoute(
                  builder: (_) => StorePicker(settings: s, api: api),
                )),
              ),
              const Divider(),
              _Section('מה נחשב "מבצע טוב"'),
              ListTile(
                title: Text('הנחה של לפחות ${s.minPct.round()}%'),
                subtitle: Slider(
                  value: s.minPct,
                  min: 10,
                  max: 80,
                  divisions: 14,
                  label: '${s.minPct.round()}%',
                  onChanged: (v) {
                    if (v.round() != s.minPct.round()) Haptics.select();
                    s.setThresholds(pct: v);
                  },
                ),
              ),
              ListTile(
                title: Text(s.minSave == 0 ? 'בלי מינימום חיסכון בשקלים' : 'חיסכון של לפחות ₪${s.minSave.round()}'),
                subtitle: Slider(
                  value: s.minSave,
                  min: 0,
                  max: 20,
                  divisions: 20,
                  label: '₪${s.minSave.round()}',
                  onChanged: (v) {
                    if (v.round() != s.minSave.round()) Haptics.select();
                    s.setThresholds(save: v);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('מבצע צריך לעבור את שני התנאים כדי להופיע.', style: tt.bodySmall),
              ),
              const Divider(),
              _Section('להסתיר מבצעים מסוג'),
              for (final e in hideableTags.entries)
                SwitchListTile(
                  title: Text(e.value),
                  value: s.hiddenTags.contains(e.key),
                  onChanged: (v) {
                    Haptics.select();
                    s.toggleTag(e.key, v);
                  },
                ),
              if (s.hiddenDeals.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.visibility_rounded),
                  title: Text('הצג שוב ${s.hiddenDeals.length} מבצעים שהסתרתי'),
                  onTap: () {
                    Haptics.commit();
                    s.clearHiddenDeals();
                  },
                ),
              const Divider(),
              _Section('קטגוריות להסתרה'),
              if (categories.isEmpty)
                const ListTile(title: Text('הקטגוריות ייטענו אחרי שהמבצעים ייטענו')),
              for (final g in groups.entries)
                ExpansionTile(
                  title: Text(g.key),
                  subtitle: Text(_hiddenSummary(g.value, s)),
                  children: [
                    for (final c in g.value)
                      CheckboxListTile(
                        title: Text(c.name),
                        value: s.hiddenCats.contains(c.id),
                        onChanged: (v) {
                          Haptics.select();
                          s.toggleCat(c.id, v ?? false);
                        },
                      ),
                  ],
                ),
              const Divider(),
              _Section('אודות'),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: Text('גרסה $kVersionName'),
                subtitle: Text(updater.checking
                    ? 'בודק עדכונים…'
                    : updater.available != null
                        ? 'גרסה ${updater.available!.name} זמינה'
                        : (updater.lastError ?? 'הנתונים מתעדכנים כל לילה מקבצי השקיפות של רמי לוי')),
                trailing: updater.available != null
                    ? FilledButton(
                        onPressed: () => showUpdateSheet(context, updater.available!),
                        child: const Text('עדכן'),
                      )
                    : TextButton(
                        onPressed: updater.checking || !updater.supported
                            ? null
                            : () async {
                                final r = await updater.check(force: true);
                                if (r == null && updater.lastError == null && context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(content: Text('יש לך את הגרסה האחרונה')));
                                }
                              },
                        child: const Text('בדוק עדכונים'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _hiddenSummary(List<ProductCategory> cats, Settings s) {
    final n = cats.where((c) => s.hiddenCats.contains(c.id)).length;
    if (n == 0) return 'הכל מוצג';
    if (n == cats.length) return 'הכל מוסתר';
    return '$n מתוך ${cats.length} מוסתרות';
  }
}

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
