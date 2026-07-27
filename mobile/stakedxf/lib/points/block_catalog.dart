import 'dart:convert';
import 'dart:io';

/// One polyline / path from an extracted DWG block (normalized to ~unit square).
class BlockPath {
  const BlockPath({required this.closed, required this.points});

  final bool closed;
  /// Normalized coordinates roughly in [-0.5, 0.5].
  final List<List<double>> points;

  factory BlockPath.fromJson(Map<String, dynamic> json) {
    final raw = json['points'] as List? ?? const [];
    final points = <List<double>>[];
    for (final p in raw) {
      if (p is List && p.length >= 2) {
        points.add([
          (p[0] as num).toDouble(),
          (p[1] as num).toDouble(),
        ]);
      }
    }
    return BlockPath(
      closed: json['closed'] == true,
      points: points,
    );
  }
}

/// A DWG BLOCK definition extracted into the plot object library.
class DwgBlockSymbol {
  const DwgBlockSymbol({
    required this.id,
    required this.name,
    required this.source,
    required this.defaultSizeFt,
    required this.paths,
    this.nativeSpan = 1,
    this.pathCount = 0,
  });

  final String id;
  final String name;
  final String source;
  final double defaultSizeFt;
  final double nativeSpan;
  final int pathCount;
  final List<BlockPath> paths;

  factory DwgBlockSymbol.fromJson(Map<String, dynamic> json) {
    final rawPaths = json['paths'] as List? ?? const [];
    return DwgBlockSymbol(
      id: json['id']?.toString() ?? json['name']?.toString() ?? '',
      name: json['name']?.toString() ?? json['id']?.toString() ?? '',
      source: json['source']?.toString() ?? 'DWG block',
      defaultSizeFt: (json['default_size_ft'] as num?)?.toDouble() ?? 12,
      nativeSpan: (json['native_span'] as num?)?.toDouble() ?? 1,
      pathCount: (json['path_count'] as num?)?.toInt() ?? rawPaths.length,
      paths: rawPaths
          .whereType<Map>()
          .map((e) => BlockPath.fromJson(Map<String, dynamic>.from(e)))
          .where((p) => p.points.length >= 2)
          .toList(),
    );
  }
}

/// Catalog of DWG blocks available as placeable plot objects.
class BlockCatalog {
  BlockCatalog(this.blocks, {this.sourceFile = ''});

  final List<DwgBlockSymbol> blocks;
  final String sourceFile;

  static const assetPath = 'assets/symbol_library/dwg_blocks.json';

  DwgBlockSymbol? operator [](String id) {
    for (final b in blocks) {
      if (b.id == id) return b;
    }
    // Fall back to display name / normalized id so "NORTH ARROW" finds NORTH_ARROW.
    final needle = _normalizeKey(id);
    for (final b in blocks) {
      if (_normalizeKey(b.id) == needle || _normalizeKey(b.name) == needle) {
        return b;
      }
    }
    return null;
  }

  static String _normalizeKey(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_]+'), ' ');

  List<DwgBlockSymbol> get sorted {
    final copy = List<DwgBlockSymbol>.from(blocks)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return copy;
  }

  factory BlockCatalog.fromJson(Map<String, dynamic> json) {
    final raw = json['blocks'] as List? ?? const [];
    final blocks = raw
        .whereType<Map>()
        .map((e) => DwgBlockSymbol.fromJson(Map<String, dynamic>.from(e)))
        .where((b) => b.id.isNotEmpty && b.paths.isNotEmpty)
        .toList();
    return BlockCatalog(
      blocks,
      sourceFile: json['source_file']?.toString() ?? '',
    );
  }

  static BlockCatalog parseString(String text) {
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      return BlockCatalog(const []);
    }
    return BlockCatalog.fromJson(Map<String, dynamic>.from(decoded));
  }

  /// Load from a filesystem path (tests / codegen tools).
  static BlockCatalog loadFile(String path) {
    return parseString(File(path).readAsStringSync());
  }

  static BlockCatalog? _cached;

  /// For tests / app — inject or reuse a catalog.
  static BlockCatalog? get cached => _cached;

  static void setCached(BlockCatalog catalog) {
    _cached = catalog;
  }

  static void clearCache() => _cached = null;
}
