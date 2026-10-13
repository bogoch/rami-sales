import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../settings.dart';
import '../ui.dart';
import 'store_picker.dart';

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  final Api api;
  final List<Category> categories;
  const SettingsScreen({super.key, required this.settings, required this.api, required this.categories});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final s = settings;
        final tt = Theme.of(context).textTheme;
        final groups = <String, List<Category>>{};
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
            ],
          ),
        );
      },
    );
  }

  String _hiddenSummary(List<Category> cats, Settings s) {
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
