import 'label_placement.dart';
import 'linework_style.dart';
import 'plot_templates.dart';

/// Marker symbol drawn at each stake point.
enum PointMarkerStyle {
  triangleFilled('Filled triangle'),
  triangleOutline('Triangle outline'),
  cross('Cross (+)'),
  x('X'),
  largeX('Large X'),
  circle('Circle'),
  dot('Dot'),
  largeDot('Large dot');

  const PointMarkerStyle(this.label);
  final String label;
}

/// Text drawn next to each stake point.
enum PointLabelFormat {
  numberOnly('Point number'),
  numberDescription('Number + description'),
  numberElevation('Number + elevation'),
  numberDescriptionElevation('Number + description + elevation'),
  none('No labels');

  const PointLabelFormat(this.label);
  final String label;
}

/// User choices for staking plot PDF generation.
class PlotOptions {
  const PlotOptions({
    this.markerStyle = PointMarkerStyle.triangleFilled,
    this.labelFormat = PointLabelFormat.numberDescriptionElevation,
    this.showPointList = false,
    this.includeLinework = true,
    this.template = kDefaultPlotTemplate,
    this.labelDrags = const {},
    this.annotationScale = 1.0,
    this.showObjectLabels = false,
    this.symbolPaperInches = 0.28,
    this.autoSpreadLabels = true,
    this.globalLinetypeScale = 1.0,
    this.layerStyleOverrides = const {},
    this.entityStyleOverrides = const {},
  });

  final PointMarkerStyle markerStyle;
  final PointLabelFormat labelFormat;

  /// When false, omit the CONTROL POINTS table (more plot space).
  final bool showPointList;

  /// When true and DXF linework is linked, draw selected layers.
  final bool includeLinework;

  /// Sheet size / orientation / layout template.
  final PlotTemplate template;

  /// Civil 3D–style dragged label offsets keyed by point id.
  final Map<String, LabelDragState> labelDrags;

  /// Multiplier for paper-space annotation size (labels, markers, symbols).
  /// Keeps callouts readable when the engineering scale is large.
  final double annotationScale;

  /// When true, draw text next to library objects (off by default).
  final bool showObjectLabels;

  /// Base paper diameter (inches) for a library object at scale 1.0.
  final double symbolPaperInches;

  /// When true, auto-spread undragged labels before paint/export.
  final bool autoSpreadLabels;

  /// Global multiplier applied on top of per-entity/layer linetype scale.
  final double globalLinetypeScale;

  /// Per-layer paint overrides (color / weight / linetype / opacity / scale).
  final Map<String, LineworkStyleOverride> layerStyleOverrides;

  /// Per-entity paint overrides (after explode / selection).
  final Map<String, LineworkStyleOverride> entityStyleOverrides;

  PlotOptions copyWith({
    PointMarkerStyle? markerStyle,
    PointLabelFormat? labelFormat,
    bool? showPointList,
    bool? includeLinework,
    PlotTemplate? template,
    Map<String, LabelDragState>? labelDrags,
    double? annotationScale,
    bool? showObjectLabels,
    double? symbolPaperInches,
    bool? autoSpreadLabels,
    double? globalLinetypeScale,
    Map<String, LineworkStyleOverride>? layerStyleOverrides,
    Map<String, LineworkStyleOverride>? entityStyleOverrides,
  }) {
    return PlotOptions(
      markerStyle: markerStyle ?? this.markerStyle,
      labelFormat: labelFormat ?? this.labelFormat,
      showPointList: showPointList ?? this.showPointList,
      includeLinework: includeLinework ?? this.includeLinework,
      template: template ?? this.template,
      labelDrags: labelDrags ?? this.labelDrags,
      annotationScale: annotationScale ?? this.annotationScale,
      showObjectLabels: showObjectLabels ?? this.showObjectLabels,
      symbolPaperInches: symbolPaperInches ?? this.symbolPaperInches,
      autoSpreadLabels: autoSpreadLabels ?? this.autoSpreadLabels,
      globalLinetypeScale: globalLinetypeScale ?? this.globalLinetypeScale,
      layerStyleOverrides: layerStyleOverrides ?? this.layerStyleOverrides,
      entityStyleOverrides: entityStyleOverrides ?? this.entityStyleOverrides,
    );
  }
}
