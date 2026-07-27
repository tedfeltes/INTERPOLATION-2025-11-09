import 'package:flutter/services.dart';

import 'block_catalog.dart';

/// Flutter asset helpers for [BlockCatalog] (keeps core catalog free of dart:ui).
class BlockCatalogAsset {
  BlockCatalogAsset._();

  static Future<BlockCatalog> loadAsset() async {
    final text = await rootBundle.loadString(BlockCatalog.assetPath);
    return BlockCatalog.parseString(text);
  }

  static Future<BlockCatalog> loadCached() async {
    final existing = BlockCatalog.cached;
    if (existing != null) return existing;
    final loaded = await loadAsset();
    BlockCatalog.setCached(loaded);
    return loaded;
  }
}
