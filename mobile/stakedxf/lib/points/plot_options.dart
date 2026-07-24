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
  });

  final PointMarkerStyle markerStyle;
  final PointLabelFormat labelFormat;

  /// When false, omit the CONTROL POINTS table (more plot space).
  final bool showPointList;

  /// When true and DXF linework is linked, draw selected layers.
  final bool includeLinework;

  PlotOptions copyWith({
    PointMarkerStyle? markerStyle,
    PointLabelFormat? labelFormat,
    bool? showPointList,
    bool? includeLinework,
  }) {
    return PlotOptions(
      markerStyle: markerStyle ?? this.markerStyle,
      labelFormat: labelFormat ?? this.labelFormat,
      showPointList: showPointList ?? this.showPointList,
      includeLinework: includeLinework ?? this.includeLinework,
    );
  }
}
