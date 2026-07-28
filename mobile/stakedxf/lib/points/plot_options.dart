import 'label_placement.dart';
import 'linework_style.dart';
import 'plot_annotations.dart';
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

/// Text drawn next to each stake point (abbreviated Civil-style names).
enum PointLabelFormat {
  numberOnly('PT NO'),
  numberDescription('PT NO DESC'),
  numberElevation('PT NO ELV'),
  numberDescriptionElevation('PT NO DESC ELV'),
  descriptionElevation('DESC ELV'),
  descriptionOnly('DESC'),
  elevationOnly('ELV'),
  none('NONE');

  const PointLabelFormat(this.label);
  final String label;
}

/// Per-point paint / label overrides (tap a point to edit).
class PointStyleOverride {
  const PointStyleOverride({
    this.colorArgb,
    this.labelFormat,
    this.markerStyle,
  });

  final int? colorArgb;
  final PointLabelFormat? labelFormat;
  final PointMarkerStyle? markerStyle;

  bool get isEmpty =>
      colorArgb == null && labelFormat == null && markerStyle == null;

  PointStyleOverride copyWith({
    int? colorArgb,
    PointLabelFormat? labelFormat,
    PointMarkerStyle? markerStyle,
    bool clearColor = false,
    bool clearLabelFormat = false,
    bool clearMarkerStyle = false,
  }) {
    return PointStyleOverride(
      colorArgb: clearColor ? null : (colorArgb ?? this.colorArgb),
      labelFormat:
          clearLabelFormat ? null : (labelFormat ?? this.labelFormat),
      markerStyle:
          clearMarkerStyle ? null : (markerStyle ?? this.markerStyle),
    );
  }
}

/// User choices for staking plot PDF generation.
class PlotOptions {
  const PlotOptions({
    this.markerStyle = PointMarkerStyle.triangleFilled,
    this.labelFormat = PointLabelFormat.numberDescriptionElevation,
    // Legacy: side-panel point list has been retired in favour of the
    // ANSI full-bleed layout. Accepted here so old callers still compile.
    // ignore: avoid_unused_constructor_parameters
    bool showPointList = false,
    this.includeLinework = true,
    this.template = kDefaultPlotTemplate,
    this.labelDrags = const {},
    this.annotationScale = 1.0,
    this.showObjectLabels = true,
    this.symbolPaperInches = 0.28,
    this.autoSpreadLabels = true,
    this.globalLinetypeScale = 1.0,
    this.layerStyleOverrides = const {},
    this.entityStyleOverrides = const {},
    this.pointStyleOverrides = const {},
    this.titleBlock = const TitleBlockData(),
    this.defaultPointColorArgb,
    this.textStyleId = 'ROMANS_SHX',
    this.scaleFtPerInch,
    this.lockedLayers = const {},
  });

  final PointMarkerStyle markerStyle;
  final PointLabelFormat labelFormat;

  /// Legacy flag retained for tests / callers migrated from the old
  /// side-panel layout. Ignored by the ANSI full-bleed layout.
  bool get showPointList => false;

  /// When true and DXF linework is linked, draw selected layers.
  final bool includeLinework;

  /// Sheet size / orientation / layout template.
  final PlotTemplate template;

  /// Civil 3D–style dragged label offsets keyed by point id.
  final Map<String, LabelDragState> labelDrags;

  /// Multiplier for paper-space point labels / markers only.
  /// Library objects and free text use their own scale.
  final double annotationScale;

  /// When true, draw text next to library objects.
  final bool showObjectLabels;

  /// Base paper diameter (inches) for a library object at scale 1.0.
  final double symbolPaperInches;

  /// When true, auto-spread undragged labels before paint/export.
  final bool autoSpreadLabels;

  /// Global multiplier applied on top of per-entity/layer linetype scale.
  final double globalLinetypeScale;

  /// Per-layer paint overrides (color / weight / linetype / opacity / scale).
  final Map<String, LineworkStyleOverride> layerStyleOverrides;

  /// Per-entity paint overrides (geometry trim / rare overrides).
  final Map<String, LineworkStyleOverride> entityStyleOverrides;

  /// Per-point color / label format / marker overrides.
  final Map<String, PointStyleOverride> pointStyleOverrides;

  /// Sheet title-block fields.
  final TitleBlockData titleBlock;

  /// Optional global point/label color override (ARGB). Null → CTB ACI 10.
  final int? defaultPointColorArgb;

  /// Civil DWG text style id for plot labels / text objects.
  final String textStyleId;

  /// Engineering scale override (feet per inch). Null = auto-fit.
  final double? scaleFtPerInch;

  /// Layers that cannot be selected / hit-tested on the preview.
  final Set<String> lockedLayers;

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
    Map<String, PointStyleOverride>? pointStyleOverrides,
    TitleBlockData? titleBlock,
    int? defaultPointColorArgb,
    String? textStyleId,
    double? scaleFtPerInch,
    Set<String>? lockedLayers,
    bool clearDefaultPointColor = false,
    bool clearScaleFtPerInch = false,
  }) {
    // `showPointList` is accepted but ignored (ANSI full bleed has no
    // point-list panel). Keeping the parameter avoids churn in callers.
    return PlotOptions(
      markerStyle: markerStyle ?? this.markerStyle,
      labelFormat: labelFormat ?? this.labelFormat,
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
      pointStyleOverrides: pointStyleOverrides ?? this.pointStyleOverrides,
      titleBlock: titleBlock ?? this.titleBlock,
      defaultPointColorArgb: clearDefaultPointColor
          ? null
          : (defaultPointColorArgb ?? this.defaultPointColorArgb),
      textStyleId: textStyleId ?? this.textStyleId,
      scaleFtPerInch: clearScaleFtPerInch
          ? null
          : (scaleFtPerInch ?? this.scaleFtPerInch),
      lockedLayers: lockedLayers ?? this.lockedLayers,
    );
  }
}
