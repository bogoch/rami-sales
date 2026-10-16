import 'package:flutter/material.dart';

import '../category_style.dart';
import '../data.dart';
import '../logic.dart';
import '../models.dart';
import '../product_image.dart';
import '../settings.dart';
import '../ui.dart';
import '../updater.dart';
import '../watch.dart';
import 'watch_screen.dart';
import 'deal_card.dart';
import 'settings_screen.dart';

class DealsScreen extends StatefulWidget {
  final Settings settings;
  final Api api;
  final Updater updater;
  const DealsScreen({super.key, required this.settings, required this.api, required this.updater});

  @override
  State<DealsScreen> createState() => _DealsScreenState();
}

class _DealsScreenState extends State<DealsScreen> {
  DealsFile? _file;
  List<ProductCategory> _cats = [];
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
    widget.updater.addListener(_onSettings);
    Watchlist.instance.addListener(_onSettings);
    _load();
    widget.updater.check();
  }

  @override
  void dispose() {
    s.removeListener(_onSettings);
    widget.updater.removeListener(_onSettings);
    Watchlist.instance.removeListener(_onSettings);
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
      CategoryStyles.load(cats);
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
        builder: (_) => SettingsScreen(settings: s, api: widget.api, categories: _cats, updater: widget.updater),
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
                IconButton(
                  icon: Badge(
                    isLabelVisible: file != null && Watchlist.instance.matches(file.deals, hiddenTags: s.hiddenTags).isNotEmpty,
                    label: Text('${file == null ? 0 : Watchlist.instance.matches(file.deals, hiddenTags: s.hiddenTags).length}'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  tooltip: 'מעקב',
                  onPressed: () => Navigator.of(context).push(FluidRoute(
                    builder: (_) => WatchScreen(settings: s, file: _file, categories: _cats),
                  )),
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
            if (_cats.isNotEmpty) SliverToBoxAdapter(child: SizedBox(height: 92, child: _groupTiles())),
            if (_segment == 0 && _query.isEmpty && _group == null && good.length >= 3)
              SliverToBoxAdapter(child: _hero(good, file!)),
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
                    ],
                  ),
                ),
              ),
            ),
            if (widget.updater.available != null)
              SliverToBoxAdapter(
                child: _Notice(
                  text: 'גרסה חדשה ${widget.updater.available!.name} זמינה',
                  action: 'עדכן',
                  onAction: () => showUpdateSheet(context, widget.updater.available!),
                ),
              ),
            if (file != null && DateTime.now().difference(file.generated).inHours >= 30)
              SliverToBoxAdapter(
                child: _Notice(
                  text: 'הנתונים מעודכנים ל-${_fmtTime(file.generated)}. ייתכן שחלק מהמבצעים כבר הסתיימו.',
                  action: 'רענן',
                  onAction: _load,
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
                  itemBuilder: (_, i) => Appear(
                    key: ValueKey('${_segment}_${_group}_${shown[i].id}'),
                    index: i,
                    child: DealCard(
                      deal: shown[i],
                      dataDate: file!.generated,
                      storeName: s.storeName,
                    ),
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

  Widget _groupTiles() {
    final groups = _groups.keys.toList();
    Widget tile(String label, GroupStyle st, bool selected, VoidCallback onTap) => _GroupTile(
          label: label,
          style: st,
          selected: selected,
          onTap: () {
            Haptics.select();
            onTap();
          },
        );
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: kScrollPhysics,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      children: [
        tile('הכל', const GroupStyle(Color(0xFFD62828), 'basket'), _group == null,
            () => setState(() => _group = null)),
        for (final g in groups)
          tile(_shortGroup(g), CategoryStyles.group(g), _group == g, () => setState(() => _group = _group == g ? null : g)),
      ],
    );
  }

  /// Short labels so tiles stay compact.
  String _shortGroup(String g) => const {
        'מוצרי חלב וביצים': 'חלב וביצים',
        'פירות וירקות': 'פירות וירקות',
        'חטיפים ומתוקים': 'מתוקים',
        'בית וטיפוח': 'בית וטיפוח',
        'לחם ומאפים': 'לחם',
        'בשר ודגים': 'בשר ודגים',
      }[g] ??
      g;

  Widget _hero(List<Deal> good, DealsFile file) {
    // strongest deals that don't need a coupon/insurance, falling back to anything
    var top = good.where((d) => !d.tags.contains('insurance') && !d.tags.contains('coupon')).toList();
    if (top.length < 3) top = List.of(good);
    top.sort((a, b) => b.pct.compareTo(a.pct));
    top = top.take(6).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Text('הכי שווים היום', style: display(context, 19, weight: FontWeight.w700)),
        ),
        SizedBox(
          height: 156,
          child: PageView.builder(
            controller: PageController(viewportFraction: 0.84),
            padEnds: false,
            physics: kScrollPhysics,
            itemCount: top.length,
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsetsDirectional.only(start: i == 0 ? 16 : 6, end: 6),
              child: _HeroCard(deal: top[i], storeName: s.storeName),
            ),
          ),
        ),
      ]),
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
  double get minExtent => 60;
  @override
  double get maxExtent => 60;

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

class _GroupTile extends StatelessWidget {
  final String label;
  final GroupStyle style;
  final bool selected;
  final VoidCallback onTap;
  const _GroupTile({required this.label, required this.style, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Pressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: SizedBox(
        width: 74,
        child: Column(children: [
          AnimatedContainer(
            duration: reduceMotion(context) ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: selected ? style.color : style.color.withValues(alpha: dark ? 0.22 : 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: PIcon(
              style.icon,
              size: 28,
              color: selected ? Colors.white : (dark ? Color.lerp(style.color, Colors.white, 0.35)! : style.color),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
              )),
        ]),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Deal deal;
  final String storeName;
  const _HeroCard({required this.deal, required this.storeName});

  @override
  Widget build(BuildContext context) {
    final cat = CategoryStyles.primaryCat(deal);
    final base = CategoryStyles.colorOfCat(cat);
    final it = deal.best;
    final hsl = HSLColor.fromColor(base);
    final c1 = hsl.withLightness((hsl.lightness - 0.08).clamp(0.0, 1.0)).toColor();
    final c2 = hsl.withHue((hsl.hue + 28) % 360).withLightness((hsl.lightness + 0.04).clamp(0.0, 1.0)).toColor();
    const white = Colors.white;
    return Pressable(
      onTap: () => showDealSheet(context, deal, storeName),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [c1, c2]),
          boxShadow: [BoxShadow(color: base.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Stack(children: [
          PositionedDirectional(
            end: 0,
            top: 0,
            child: ProductImage(
              code: it.code,
              size: 76,
              fallback: PIcon(CategoryStyles.iconOfCat(cat), size: 76, color: white.withValues(alpha: 0.22)),
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${deal.pct.round()}%',
                textDirection: TextDirection.ltr, style: display(context, 38, color: white)),
            Text('הנחה · חוסכים ₪${money(it.save * deal.buyQty)}',
                style: TextStyle(color: white.withValues(alpha: 0.9), fontSize: 12.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(deal.desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.25)),
            const SizedBox(height: 2),
            Text('${offerText(deal)} · במקום ₪${money(it.regular)}',
                style: TextStyle(color: white.withValues(alpha: 0.9), fontSize: 12.5)),
          ]),
        ]),
      ),
    );
  }
}
