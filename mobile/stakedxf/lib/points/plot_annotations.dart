/// One independently scaled text object in survey coordinates.
class PlotTextObject {
  const PlotTextObject({
    required this.id,
    required this.text,
    required this.easting,
    required this.northing,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    this.colorArgb = 0xFF1A1A1A,
    this.fontSizePt = 10.0,
    this.opacity = 1.0,
    this.textStyleId,
  });

  final String id;
  final String text;
  final double easting;
  final double northing;

  /// Independent paper-space scale (does not follow annotation scale).
  final double scale;
  final double rotationDeg;
  final int colorArgb;

  /// Base font size in PDF points at [scale] 1.0.
  final double fontSizePt;

  /// 0–1 display opacity.
  final double opacity;

  /// Optional override of the plot-wide text style id.
  final String? textStyleId;

  double get effectiveFontSizePt =>
      (fontSizePt * scale).clamp(4.0, 72.0);

  PlotTextObject copyWith({
    String? id,
    String? text,
    double? easting,
    double? northing,
    double? scale,
    double? rotationDeg,
    int? colorArgb,
    double? fontSizePt,
    double? opacity,
    String? textStyleId,
    bool clearTextStyleId = false,
  }) {
    return PlotTextObject(
      id: id ?? this.id,
      text: text ?? this.text,
      easting: easting ?? this.easting,
      northing: northing ?? this.northing,
      scale: scale ?? this.scale,
      rotationDeg: rotationDeg ?? this.rotationDeg,
      colorArgb: colorArgb ?? this.colorArgb,
      fontSizePt: fontSizePt ?? this.fontSizePt,
      opacity: opacity ?? this.opacity,
      textStyleId:
          clearTextStyleId ? null : (textStyleId ?? this.textStyleId),
    );
  }
}

/// Corner-block fields drawn on the ANSI full-bleed sheet.
///
/// StakeDXF ships a single, compact staking-plot layout: a full-sheet
/// plan plus a corner block that carries the plot **name** and **date**
/// (the scale line and north arrow are drawn automatically). No side
/// panels, no title blocks, no point-list tables.
class TitleBlockData {
  const TitleBlockData({
    this.name = '',
    this.date = '',
  });

  /// The plot's display name — appears in the corner block as the top line.
  ///
  /// Empty by default; the export screen prompts the user to enter a name
  /// before creating the PDF.
  final String name;

  /// Optional date string. Empty → today's date at PDF-build time.
  final String date;

  TitleBlockData copyWith({
    String? name,
    String? date,
  }) {
    return TitleBlockData(
      name: name ?? this.name,
      date: date ?? this.date,
    );
  }
}
