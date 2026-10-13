import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

const baseUrl = 'https://bogoch.github.io/rami-sales';

/// Result of a load: data plus whether it came from the offline cache.
class Loaded<T> {
  final T data;
  final bool fromCache;
  final String? error;
  Loaded(this.data, {this.fromCache = false, this.error});
}

class Api {
  Future<File> _cacheFile(String path) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/cache/${path.replaceAll('/', '_')}');
  }

  /// Fetch JSON from the network, falling back to the last cached copy.
  Future<Loaded<Map<String, dynamic>>> _getJson(String path) async {
    final cache = await _cacheFile(path);
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/$path?t=${DateTime.now().millisecondsSinceEpoch ~/ 600000}'))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) {
        throw HttpException('HTTP ${res.statusCode}');
      }
      final body = utf8.decode(res.bodyBytes);
      final json = jsonDecode(body) as Map<String, dynamic>;
      await cache.parent.create(recursive: true);
      await cache.writeAsString(body);
      return Loaded(json);
    } catch (e) {
      if (await cache.exists()) {
        final json = jsonDecode(await cache.readAsString()) as Map<String, dynamic>;
        return Loaded(json, fromCache: true, error: e.toString());
      }
      rethrow;
    }
  }

  Future<Loaded<DealsFile>> deals(String storeId) async {
    final r = await _getJson('deals/$storeId.json');
    return Loaded(await compute(_parseDeals, r.data), fromCache: r.fromCache, error: r.error);
  }

  Future<List<Store>> stores() async {
    final r = await _getJson('stores.json');
    return (r.data['stores'] as List)
        .map((e) => Store.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Category>> categories() async {
    final r = await _getJson('categories.json');
    return (r.data['categories'] as List)
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

DealsFile _parseDeals(Map<String, dynamic> j) => DealsFile.fromJson(j);
