import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui.dart';

/// Build number baked in by CI (`--dart-define=BUILD_NUMBER=<run number>`); 0 for local builds.
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER');
const String kVersionName = String.fromEnvironment('VERSION_NAME', defaultValue: 'dev');

const _latestApi = 'https://api.github.com/repos/bogoch/rami-sales/releases/latest';

class Release {
  final int build;
  final String name;
  final String apkUrl;
  final String pageUrl;
  final String notes;
  Release(this.build, this.name, this.apkUrl, this.pageUrl, this.notes);
}

class Updater extends ChangeNotifier {
  Release? available;
  bool checking = false;
  String? lastError;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks GitHub for a newer release. With [force] = false it runs at most every 6 hours.
  Future<Release?> check({bool force = false}) async {
    if (!supported) return null;
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('updateCheckedAt') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && now - last < const Duration(hours: 6).inMilliseconds) {
      return available;
    }
    checking = true;
    lastError = null;
    notifyListeners();
    try {
      final res = await http
          .get(Uri.parse(_latestApi), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '') as String; // v0.1.<build>
      final build = int.tryParse(tag.split('.').last) ?? 0;
      final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
      final apk = assets.firstWhere((a) => (a['name'] as String).endsWith('.apk'), orElse: () => {});
      await prefs.setInt('updateCheckedAt', now);
      if (build > kBuildNumber && apk.isNotEmpty) {
        available = Release(build, tag.replaceFirst('v', ''), apk['browser_download_url'] as String,
            (j['html_url'] ?? '') as String, (j['body'] ?? '') as String);
      } else {
        available = null;
      }
    } catch (e) {
      lastError = 'לא הצלחתי לבדוק עדכונים';
    } finally {
      checking = false;
      notifyListeners();
    }
    return available;
  }
}

/// Bottom sheet that downloads and launches the installer, with live progress.
Future<void> showUpdateSheet(BuildContext context, Release r) => showModalBottomSheet(
      context: context,
      isDismissible: true,
      showDragHandle: true,
      builder: (_) => _UpdateSheet(release: r),
    );

class _UpdateSheet extends StatefulWidget {
  final Release release;
  const _UpdateSheet({required this.release});

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  double? _progress; // null = not started
  String? _status;
  bool _failed = false;

  void _start() {
    Haptics.commit();
    setState(() {
      _progress = 0;
      _status = 'מוריד…';
      _failed = false;
    });
    try {
      OtaUpdate()
          .execute(widget.release.apkUrl, destinationFilename: 'rami-sales-${widget.release.build}.apk')
          .listen((e) {
        if (!mounted) return;
        setState(() {
          switch (e.status) {
            case OtaStatus.DOWNLOADING:
              _progress = (double.tryParse(e.value ?? '') ?? 0) / 100;
              _status = 'מוריד… ${e.value ?? 0}%';
            case OtaStatus.INSTALLING:
              _progress = 1;
              _status = 'פותח את ההתקנה — אשר בחלון של אנדרואיד';
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
              _failed = true;
              _status = 'צריך לאשר לאפליקציה להתקין עדכונים (הגדרות ← התקנת אפליקציות לא מוכרות)';
            default:
              if (e.status.toString().contains('ERROR') || e.status == OtaStatus.CANCELED) {
                _failed = true;
                _status = 'ההורדה נכשלה';
              }
          }
        });
      }, onError: (_) {
        if (mounted) {
          setState(() {
            _failed = true;
            _status = 'ההורדה נכשלה';
          });
        }
      });
    } catch (_) {
      setState(() {
        _failed = true;
        _status = 'ההורדה נכשלה';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final r = widget.release;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('גרסה חדשה ${r.name}', style: display(context, 22, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('הגרסה שלך: $kVersionName', style: tt.bodySmall),
        if (r.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(r.notes.trim(), maxLines: 6, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: 20),
        if (_progress != null && !_failed) ...[
          LinearProgressIndicator(value: _progress == 0 ? null : _progress, borderRadius: BorderRadius.circular(8)),
          const SizedBox(height: 8),
          Text(_status ?? '', style: tt.bodyMedium),
        ] else ...[
          if (_failed) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_status ?? '')),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.system_update_rounded),
              label: Text(_failed ? 'נסה שוב' : 'עדכן עכשיו'),
              onPressed: _start,
            ),
          ),
          if (_failed)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(r.apkUrl), mode: LaunchMode.externalApplication),
              child: const Text('הורד דרך הדפדפן במקום'),
            ),
        ],
      ]),
    );
  }
}
