import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../data.dart';
import '../models.dart';
import '../settings.dart';
import '../ui.dart';

class StorePicker extends StatefulWidget {
  final Settings settings;
  final Api api;
  const StorePicker({super.key, required this.settings, required this.api});

  @override
  State<StorePicker> createState() => _StorePickerState();
}

class _StorePickerState extends State<StorePicker> {
  List<Store>? _stores;
  String? _error;
  String _query = '';
  bool _locating = false;
  Map<String, double> _distKm = {};

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      final v = await widget.api.stores();
      if (mounted) setState(() => _stores = v);
    } catch (_) {
      if (mounted) setState(() => _error = 'לא הצלחתי לטעון את רשימת הסניפים');
    }
  }

  Future<void> _nearest() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'שירותי המיקום כבויים בטלפון';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        throw 'אין הרשאת מיקום';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );
      final d = <String, double>{};
      for (final s in _stores ?? <Store>[]) {
        if (s.lat != null && s.lon != null) {
          d[s.id] = Geolocator.distanceBetween(pos.latitude, pos.longitude, s.lat!, s.lon!) / 1000;
        }
      }
      setState(() => _distKm = d);
      final withData = (_stores ?? []).where((s) => s.hasData && d.containsKey(s.id)).toList()
        ..sort((a, b) => d[a.id]!.compareTo(d[b.id]!));
      if (withData.isNotEmpty && mounted) {
        final s = withData.first;
        _choose(s, note: 'נבחר הסניף הקרוב: ${s.name} (${d[s.id]!.toStringAsFixed(1)} ק״מ)');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _choose(Store s, {String? note}) {
    Haptics.commit();
    widget.settings.setStore(s.id, s.name);
    if (note != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final stores = _stores;
    final tt = Theme.of(context).textTheme;
    List<Store> shown = [];
    if (stores != null) {
      shown = stores
          .where((s) => _query.isEmpty || '${s.name} ${s.address} ${s.city}'.contains(_query))
          .toList()
        ..sort((a, b) {
          if (a.hasData != b.hasData) return a.hasData ? -1 : 1;
          final da = _distKm[a.id], db = _distKm[b.id];
          if (da != null && db != null) return da.compareTo(db);
          return a.name.compareTo(b.name);
        });
    }
    final withData = stores?.where((s) => s.hasData).length ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('בחירת סניף')),
      body: stores == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : ListView(physics: kScrollPhysics, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: FilledButton.tonalIcon(
                  icon: _locating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                  label: const Text('הסניף הקרוב אליי'),
                  onPressed: _locating ? null : _nearest,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'חיפוש סניף או עיר'),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
              ),
              if (withData < stores.length)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'כרגע יש נתונים ל-$withData ${withData == 1 ? 'סניף' : 'סניפים'}. '
                    'סניפים אחרים אפשר להוסיף בהגדרות הצינור (config.json).',
                    style: tt.bodySmall,
                  ),
                ),
              for (final s in shown)
                ListTile(
                  enabled: s.hasData,
                  leading: Icon(s.id == widget.settings.storeId ? Icons.radio_button_checked : Icons.radio_button_off),
                  title: Text(s.name),
                  subtitle: Text([
                    if (s.address.isNotEmpty) s.address,
                    if (s.city.isNotEmpty) s.city,
                    if (_distKm[s.id] != null) '${_distKm[s.id]!.toStringAsFixed(1)} ק״מ',
                    if (!s.hasData) 'אין נתונים',
                  ].join(' · ')),
                  onTap: s.hasData ? () => _choose(s) : null,
                ),
            ]),
    );
  }
}
