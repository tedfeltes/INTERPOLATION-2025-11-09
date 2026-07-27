/// Placeable symbol library for staking plots.
///
/// Catalog extracted from the Three Pillars Phase 1C civil set
/// (Google Drive folder — sheets C7.00–C7.03 DETAILS, C6.11 SIGNAGE,
/// C3.0 EROSION CONTROL, C5.06–C5.07 drainage structures).
library;

/// High-level grouping shown in the library picker.
enum PlotSymbolCategory {
  utilities('Utilities'),
  drainage('Drainage'),
  signs('Signs'),
  site('Site / survey'),
  erosion('Erosion control'),
  annotation('Annotation'),
  dwgBlocks('DWG blocks');

  const PlotSymbolCategory(this.label);
  final String label;
}

/// Built-in library kinds (plan-view symbols for staking sheets).
enum PlotSymbolKind {
  // Utilities — C7.00 hydrant / sanitary / water details
  fireHydrant(
    'Fire hydrant',
    PlotSymbolCategory.utilities,
    'C7.00 Hydrant Setting Detail',
    10,
  ),
  waterValve(
    'Water valve',
    PlotSymbolCategory.utilities,
    'C7.00 / C4 water valve box',
    8,
  ),
  sanitaryManhole(
    'Sanitary manhole',
    PlotSymbolCategory.utilities,
    'C7.00 Sanitary Manhole Detail',
    12,
  ),
  stormManhole(
    'Storm manhole',
    PlotSymbolCategory.utilities,
    'C7.00 Storm Manhole Detail',
    12,
  ),
  cleanout(
    'Cleanout',
    PlotSymbolCategory.utilities,
    'C7.00 Cleanout Detail',
    8,
  ),
  gateValve(
    'Gate valve',
    PlotSymbolCategory.utilities,
    'C7.00 hydrant gate valve / C7.01 meter room',
    8,
  ),

  // Drainage — C7.00 inlets, C7.01 rip-rap / flume, C7.02 nyloplast
  catchBasin(
    'Catch basin',
    PlotSymbolCategory.drainage,
    'C7.00 Storm Sewer Inlet',
    12,
  ),
  curbInlet(
    'Curb inlet',
    PlotSymbolCategory.drainage,
    'C7.00 curb-side inlet',
    12,
  ),
  fieldInlet(
    'Field inlet',
    PlotSymbolCategory.drainage,
    'C7.00 Storm Sewer Field Inlet',
    12,
  ),
  flaredEnd(
    'Flared end / culvert',
    PlotSymbolCategory.drainage,
    'C7.01 Pipe Grate / culvert details',
    16,
  ),
  ripRap(
    'Rip-rap area',
    PlotSymbolCategory.drainage,
    'C7.01 Rip-Rap Detail',
    20,
  ),
  inlineDrain(
    'Inline drain',
    PlotSymbolCategory.drainage,
    'C7.02 Nyloplast Inline Drain',
    10,
  ),

  // Signs — C6.11 Site Signage Plan legend
  stopSign(
    'STOP sign',
    PlotSymbolCategory.signs,
    'C6.11 R1-1',
    14,
  ),
  yieldSign(
    'YIELD sign',
    PlotSymbolCategory.signs,
    'C6.11 R1-2',
    14,
  ),
  doNotEnter(
    'DO NOT ENTER',
    PlotSymbolCategory.signs,
    'C6.11 R5-1',
    14,
  ),
  oneWay(
    'ONE WAY',
    PlotSymbolCategory.signs,
    'C6.11 R6-2',
    12,
  ),
  speedLimit(
    'Speed limit',
    PlotSymbolCategory.signs,
    'C6.11 R2-1',
    12,
  ),
  noOutlet(
    'NO OUTLET',
    PlotSymbolCategory.signs,
    'C6.11 W14-2',
    14,
  ),
  pedCrossing(
    'Pedestrian crossing',
    PlotSymbolCategory.signs,
    'C6.11 W11-2',
    14,
  ),
  bikeCrossing(
    'Bicycle crossing',
    PlotSymbolCategory.signs,
    'C6.11 W11-15',
    14,
  ),
  handicapSign(
    'Handicap parking sign',
    PlotSymbolCategory.signs,
    'C7.01 Handicap Signage Detail',
    12,
  ),

  // Site / survey
  bollard(
    'Bollard',
    PlotSymbolCategory.site,
    'C7.02 Bollard Detail',
    8,
  ),
  lightPole(
    'Light pole',
    PlotSymbolCategory.site,
    'Site lighting (typical civil legend)',
    10,
  ),
  tree(
    'Tree',
    PlotSymbolCategory.site,
    'Landscape / site plans',
    14,
  ),
  ironPipe(
    'Iron pipe / monument',
    PlotSymbolCategory.site,
    'Survey monument (typical)',
    8,
  ),
  benchmark(
    'Benchmark',
    PlotSymbolCategory.site,
    'Survey benchmark (typical)',
    10,
  ),
  hub(
    'Hub / stake',
    PlotSymbolCategory.site,
    'Construction hub (typical)',
    8,
  ),

  // Erosion — C3.0 / C7.00
  siltFence(
    'Silt fence',
    PlotSymbolCategory.erosion,
    'C7.00 / C3.0 Silt Fence',
    16,
  ),
  inletProtection(
    'Inlet protection',
    PlotSymbolCategory.erosion,
    'C7.00 Inlet Protection Types A-D',
    12,
  ),
  wattle(
    'Wattle',
    PlotSymbolCategory.erosion,
    'C3.0 Wattles',
    14,
  ),
  dewateringBag(
    'Dewatering bag',
    PlotSymbolCategory.erosion,
    'C7.02 Geotextile Filter Bag',
    16,
  ),

  // Annotation
  callout(
    'Callout bubble',
    PlotSymbolCategory.annotation,
    'Plan callout style',
    12,
  ),
  detailRef(
    'Detail reference',
    PlotSymbolCategory.annotation,
    'SEE DETAIL (C7.xx)',
    18,
  ),
  noteBox(
    'Note box',
    PlotSymbolCategory.annotation,
    'General notes block',
    24,
  );

  const PlotSymbolKind(
    this.label,
    this.category,
    this.source,
    this.defaultSizeFt,
  );

  final String label;
  final PlotSymbolCategory category;
  final String source;
  /// Nominal plan footprint (feet) at scale 1.0.
  final double defaultSizeFt;
}

/// Preset colors for placed symbols.
class PlotSymbolColor {
  const PlotSymbolColor(this.label, this.argb);
  final String label;
  final int argb;

  static const presets = <PlotSymbolColor>[
    PlotSymbolColor('Black', 0xFF1A1A1A),
    PlotSymbolColor('Red', 0xFFE10600),
    PlotSymbolColor('Blue', 0xFF0057B8),
    PlotSymbolColor('Green', 0xFF1B7A3D),
    PlotSymbolColor('Orange', 0xFFE4572E),
    PlotSymbolColor('Purple', 0xFF6B3FA0),
    PlotSymbolColor('Brown', 0xFF8B5A2B),
    PlotSymbolColor('Gray', 0xFF666666),
  ];
}

/// One placed instance on a staking plot (survey coordinates).
///
/// Either a built-in [kind] or a [blockId] from the extracted DWG block catalog.
class PlacedPlotSymbol {
  const PlacedPlotSymbol({
    required this.id,
    required this.easting,
    required this.northing,
    this.kind,
    this.blockId,
    this.displayName = '',
    this.defaultSizeFt = 12,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    this.colorArgb = 0xFF1A1A1A,
    this.opacity = 1.0,
    this.label = '',
  }) : assert(kind != null || blockId != null);

  /// Built-in library symbol.
  factory PlacedPlotSymbol.builtin({
    required String id,
    required PlotSymbolKind kind,
    required double easting,
    required double northing,
    double scale = 1.0,
    double rotationDeg = 0.0,
    int colorArgb = 0xFF1A1A1A,
    double opacity = 1.0,
    String label = '',
  }) {
    return PlacedPlotSymbol(
      id: id,
      kind: kind,
      easting: easting,
      northing: northing,
      displayName: kind.label,
      defaultSizeFt: kind.defaultSizeFt,
      scale: scale,
      rotationDeg: rotationDeg,
      colorArgb: colorArgb,
      opacity: opacity,
      label: label,
    );
  }

  /// Extracted DWG BLOCK symbol.
  factory PlacedPlotSymbol.block({
    required String id,
    required String blockId,
    required String displayName,
    required double defaultSizeFt,
    required double easting,
    required double northing,
    double scale = 1.0,
    double rotationDeg = 0.0,
    int colorArgb = 0xFF1A1A1A,
    double opacity = 1.0,
    String label = '',
  }) {
    return PlacedPlotSymbol(
      id: id,
      blockId: blockId,
      displayName: displayName,
      defaultSizeFt: defaultSizeFt,
      easting: easting,
      northing: northing,
      scale: scale,
      rotationDeg: rotationDeg,
      colorArgb: colorArgb,
      opacity: opacity,
      label: label,
    );
  }

  final String id;
  final PlotSymbolKind? kind;
  final String? blockId;
  final String displayName;
  final double defaultSizeFt;
  final double easting;
  final double northing;
  final double scale;
  final double rotationDeg;
  final int colorArgb;
  final double opacity;
  final String label;

  bool get isBlock => blockId != null;
  double get sizeFt => defaultSizeFt * scale;
  String get libraryLabel =>
      label.trim().isEmpty ? (displayName.isEmpty ? (kind?.label ?? blockId ?? id) : displayName) : label.trim();

  PlacedPlotSymbol copyWith({
    String? id,
    PlotSymbolKind? kind,
    String? blockId,
    String? displayName,
    double? defaultSizeFt,
    double? easting,
    double? northing,
    double? scale,
    double? rotationDeg,
    int? colorArgb,
    double? opacity,
    String? label,
  }) {
    return PlacedPlotSymbol(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      blockId: blockId ?? this.blockId,
      displayName: displayName ?? this.displayName,
      defaultSizeFt: defaultSizeFt ?? this.defaultSizeFt,
      easting: easting ?? this.easting,
      northing: northing ?? this.northing,
      scale: scale ?? this.scale,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      colorArgb: colorArgb ?? this.colorArgb,
      opacity: opacity ?? this.opacity,
      label: label ?? this.label,
    );
  }
}

/// Catalog helpers for built-in kinds (excludes [PlotSymbolCategory.dwgBlocks]).
List<PlotSymbolKind> symbolsInCategory(PlotSymbolCategory category) {
  if (category == PlotSymbolCategory.dwgBlocks) return const [];
  return PlotSymbolKind.values.where((k) => k.category == category).toList();
}

String newSymbolId() =>
    'sym_${DateTime.now().microsecondsSinceEpoch}';
