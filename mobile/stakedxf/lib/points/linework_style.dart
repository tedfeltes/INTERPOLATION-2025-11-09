import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'linetype_catalog.dart';

/// Resolved paint style for one linework entity.
class ResolvedLineworkStyle {
  const ResolvedLineworkStyle({
    required this.colorArgb,
    required this.opacity,
    required this.strokeWidthPt,
    required this.linetype,
    required this.linetypeScale,
  });

  final int colorArgb;
  final double opacity;
  final double strokeWidthPt;
  final LinetypeDef linetype;
  final double linetypeScale;

  int get colorWithOpacity {
    final a = (opacity.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
    return (a << 24) | (colorArgb & 0x00FFFFFF);
  }

  List<double> dashPatternPoints() =>
      linetype.dashPatternPoints(linetypeScale);
}

/// User override applied to a layer or a single entity.
class LineworkStyleOverride {
  const LineworkStyleOverride({
    this.colorArgb,
    this.opacity,
    this.strokeWidthPt,
    this.linetypeName,
    this.linetypeScale,
  });

  final int? colorArgb;
  final double? opacity;
  final double? strokeWidthPt;
  final String? linetypeName;
  final double? linetypeScale;

  bool get isEmpty =>
      colorArgb == null &&
      opacity == null &&
      strokeWidthPt == null &&
      linetypeName == null &&
      linetypeScale == null;

  LineworkStyleOverride copyWith({
    int? colorArgb,
    double? opacity,
    double? strokeWidthPt,
    String? linetypeName,
    double? linetypeScale,
    bool clearColor = false,
    bool clearOpacity = false,
    bool clearStroke = false,
    bool clearLinetype = false,
    bool clearLinetypeScale = false,
  }) {
    return LineworkStyleOverride(
      colorArgb: clearColor ? null : (colorArgb ?? this.colorArgb),
      opacity: clearOpacity ? null : (opacity ?? this.opacity),
      strokeWidthPt: clearStroke ? null : (strokeWidthPt ?? this.strokeWidthPt),
      linetypeName:
          clearLinetype ? null : (linetypeName ?? this.linetypeName),
      linetypeScale: clearLinetypeScale
          ? null
          : (linetypeScale ?? this.linetypeScale),
    );
  }
}

/// Resolve entity → user override → CTB(ACI) → app defaults.
ResolvedLineworkStyle resolveLineworkStyle({
  required LineworkEntity entity,
  required LinetypeCatalog catalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  Map<String, LineworkStyleOverride> layerOverrides = const {},
  Map<String, LineworkStyleOverride> entityOverrides = const {},
  double globalLinetypeScale = 1.0,
  CtbPlotStyleTable? ctb,
  double defaultStrokePt = 0.7,
}) {
  final table = ctb ?? CtbPlotStyleTable.builtin();
  final layer = layerStyles[entity.layer];
  final layerOv = layerOverrides[entity.layer];
  final entOv = entityOverrides[entity.id];

  // Effective ACI: entity → layer → CTB default linework grey (252).
  final aci = entity.colorAci?.abs() ??
      ((layer != null && layer.colorAci.abs() != 7) ? layer.colorAci.abs() : null) ??
      kCtbDefaultLineworkAci;

  final ctbResolved = table.resolve(aci);

  final color = entOv?.colorArgb ??
      layerOv?.colorArgb ??
      ctbResolved.colorArgb;

  final opacity = (entOv?.opacity ??
          entity.opacity ??
          layerOv?.opacity ??
          1.0)
      .clamp(0.0, 1.0);

  // Stroke: user override → DXF lineweight → CTB lineweight for ACI.
  final stroke = entOv?.strokeWidthPt ??
      layerOv?.strokeWidthPt ??
      (entity.lineweight370 != null
          ? lineweightToPoints(
              entity.lineweight370!,
              fallback: ctbResolved.strokeWidthPt,
            )
          : null) ??
      (layer != null && layer.lineweight370 >= 0
          ? lineweightToPoints(
              layer.lineweight370,
              fallback: ctbResolved.strokeWidthPt,
            )
          : null) ??
      ctbResolved.strokeWidthPt;

  final ltName = entOv?.linetypeName ??
      entity.linetypeName ??
      layerOv?.linetypeName ??
      layer?.linetypeName ??
      'Continuous';

  final ltScale = (entOv?.linetypeScale ??
          entity.linetypeScale ??
          layerOv?.linetypeScale ??
          1.0) *
      globalLinetypeScale;

  return ResolvedLineworkStyle(
    colorArgb: color,
    opacity: opacity,
    strokeWidthPt: stroke.clamp(0.15, 8.0),
    linetype: catalog.resolve(ltName),
    linetypeScale: ltScale.clamp(0.05, 50.0),
  );
}
