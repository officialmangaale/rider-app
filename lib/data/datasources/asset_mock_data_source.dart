import 'dart:convert';

import 'package:flutter/services.dart';

class AssetMockDataSource {
  const AssetMockDataSource(this._bundle);

  final AssetBundle _bundle;

  Future<Map<String, dynamic>> loadObject(String path) async {
    final raw = await _bundle.loadString(path);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<List<dynamic>> loadList(String path) async {
    final raw = await _bundle.loadString(path);
    return jsonDecode(raw) as List<dynamic>;
  }
}
