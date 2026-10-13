import 'package:flutter/material.dart';

import '../data.dart';
import '../logic.dart';
import '../models.dart';
import '../settings.dart';
import '../ui.dart';
import 'deal_card.dart';
import 'settings_screen.dart';

class DealsScreen extends StatefulWidget {
  final Settings settings;
  final Api api;
  const DealsScreen({super.key, required this.settings, required this.api});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  DealsFile? _file;
  List<Category> _cats = [];
  bool _loading = true;
  String? _error;
  bool _fromCache = false;
  String _query = '';
  String? _group; // selected category group, null = all
  int _segment = 0; // 0 = good deals, 1 = gifts & complex
  late String _loadedStore;

  Settings get s => widget.settings;

  @override
  void initState() {
    super.initState();
    _loadedStore = s.storeId;
    s.addListener(_onSettings);
    _load();
  }

  @override
  void dispose() {
    s.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() {
    if (s.storeId != _loadedStore) {
      _loadedStore = s.storeId;
      _file = null;
      _load();
    } else {
      setState(() {});
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.api.deals(s.storeId);
      var cats = _cats;
      if (cats.isEmpty) {
        try {
          cats = await widget.api.categories();
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _file = r.data;
        _fromCache = r.fromCache;
        _cats = cats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'לא הצלחתי לטעון את המבצעים.\nבדוק את החיבור לאינטרנט.';
        _loading = false;
      });
    }
  }

  Map<String, Set<String>> get _groups {
    final m = <String, Set<String>>{};
    for (final c in _cats) {
      m.putIfAbsent(c.group, () => {}).add(c.id);
    }
    return m;
  }

  void _openSettings() => Navigator.of(context).push(FluidRoute(
        builder: (_) => SettingsScreen(settings: s, api: widget.api, categories: _cats),
      ));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final file = _file;
    final filter = Filter(query: _query, groupCats: _group == null ? null : _groups[_group]);
    final good = file == null ? <Deal>[] : goodDeals(file.deals, s, filter);
    final complex = file == null ? <Deal>[] : complexDeals(file.deals, s, filter);
    final shown = _segment == 0 ? good : complex;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        edgeOffset: 160,
        child: CustomScrollView(
          physics: kScrollPhysics,
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 116,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              flexibleSpace: Glass(
                child: FlexibleSpaceBar(
                  titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                  expandedTitleScale: 1.7,
                  title: Text('מבצעי רמי', style: display(context, 20)),
                ),
              ),
              actions: [
                PopupMenuButton<SortBy>(
                  icon: const Icon(Icons.swap_vert_rounded),
                  tooltip: 'מיון',
                  initialValue: s.sort,
                  onSelected: (v) {
                    Haptics.select();
                    s.setSort(v);
                  },
                  itemBuilder: (_) => [
                    for (final e in sortLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                ),
                IconButton(icon: const Icon(Icons.tune_rounded), tooltip: 'הגדרות', onPressed: _openSettings),
                const SizedBox(width: 4),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Text(
                  [
                    'סניף ${s.storeName}',
                    if (file != null) 'עודכן ${_fmtTime(file.generated)}',
                    'מעל ${s.minPct.round()}%${s.minSave > 0 ? ' וחיסכון ₪${s.minSave.round()}+' : ''}',
                  ].join(' · '),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _searchField(cs)),
            SliverPersistentHeader(
              pinned: true,
              delegate: _HeaderDelegate(
                child: Glass(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<int>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(value: 0, label: Text('מבצעים · ${good.length}')),
                              ButtonSegment(value: 1, label: Text('מתנות ומורכבים · ${complex.length}')),
                            ],
                            selected: {_segment},
                            onSelectionChanged: (v) {
                              Haptics.select();
                              setState(() => _segment = v.first);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_cats.isNotEmpty) SizedBox(height: 40, child: _groupChips()),
                    ],
                  ),
                ),
              ),
            ),
            if (_fromCache)
              SliverToBoxAdapter(
                child: _Notice(
                  text: 'אין חיבור — מוצגים הנתונים האחרונים שנשמרו',
                  action: 'נסה שוב',
                  onAction: _load,
                ),
              ),
            if (_loading && file == null)
              const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
            else if (_error != null && file == null)
              SliverFillRemaining(hasScrollBody: false, child: _errorView())
            else if (shown.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyView(
                  text: _segment == 0
                      ? (_query.isNotEmpty || _group != null
                          ? 'לא נמצאו מבצעים טובים שמתאימים לחיפוש.'
                          : 'אין כרגע מבצעים שעוברים את הסף שהגדרת.')
                      : 'אין מבצעים מורכבים כרגע.',
                  action: _segment == 0 ? 'שינוי הסף' : null,
                  onAction: _openSettings,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                sliver: SliverList.builder(
                  itemCount: shown.length,
                  itemBuilder: (_, i) => DealCard(
                    deal: shown[i],
                    dataDate: file!.generated,
                    storeName: s.storeName,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          textInputAction: TextInputAction.search,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: InputDecoration(
            hintText: 'חיפוש מוצר, למשל "חלב" או "שמפו"',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            fillColor: cs.surfaceContainerHigh,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      );

  Widget _groupChips() {
    final groups = _groups.keys.toList();
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
            onSelected: (_) {
              Haptics.select();
              onTap();
            },
          ),
        );
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: kScrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      children: [
        chip('הכל', _group == null, () => setState(() => _group = null)),
        for (final g in groups) chip(g, _group == g, () => setState(() => _group = _group == g ? null : g)),
      ],
    );
  }

  Widget _errorView() => _EmptyView(text: _error!, action: 'נסה שוב', onAction: _load, icon: Icons.wifi_off_rounded);

  String _fmtTime(DateTime t) {
    final l = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.day}.${l.month} ${two(l.hour)}:${two(l.minute)}';
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _HeaderDelegate({required this.child});

  @override
  double get minExtent => 100;
  @override
  double get maxExtent => 100;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => SizedBox.expand(child: child);

  @override
  bool shouldRebuild(_HeaderDelegate old) => true;
}

class _EmptyView extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;
  const _EmptyView({required this.text, this.action, this.onAction, this.icon = Icons.local_offer_outlined});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, size: 48, color: cs.outline),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton.tonal(onPressed: onAction, child: Text(action!)),
        ],
      ]),
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final String action;
  final VoidCallback onAction;
  const _Notice({required this.text, required this.action, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Expanded(child: Text(text, style: TextStyle(color: cs.onSecondaryContainer))),
        TextButton(onPressed: onAction, child: Text(action)),
      ]),
    );
  }
}
