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

/// Optional draggable plot title drawn on the ANSI full-bleed sheet.
///
/// This is the **only** thing StakeDXF now draws on top of the plan — no
/// bounding box, no scale text, no north arrow, no sheet-size callout.
/// The title is off by default; when the user enables it they get a
/// draggable, resizable text label anchored in **paper space** (its
/// position tracks the sheet, not the survey coordinates).
class TitleBlockData {
  const TitleBlockData({
    this.enabled = false,
    this.name = '',
    this.paperFracX = 0.5,
    this.paperFracY = 0.06,
    this.fontSizePt = 22,
  });

  /// When false the title is not drawn (and does not affect layout).
  final bool enabled;

  /// The title text (blank ⇒ nothing drawn).
  final String name;

  /// Paper-space X anchor as a fraction of sheet width (0 = left,
  /// 0.5 = center, 1 = right). Anchor point of the text baseline is
  /// horizontally centred on this value.
  final double paperFracX;

  /// Paper-space Y anchor as a fraction of sheet height, measured from the
  /// top of the sheet (0 = top edge, 1 = bottom edge). The text sits just
  /// below this point.
  final double paperFracY;

  /// Font size in PDF points (paper space). Scales the on-screen preview
  /// proportionally so what you see is what prints.
  final double fontSizePt;

  TitleBlockData copyWith({
    bool? enabled,
    String? name,
    double? paperFracX,
    double? paperFracY,
    double? fontSizePt,
  }) {
    return TitleBlockData(
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      paperFracX: paperFracX ?? this.paperFracX,
      paperFracY: paperFracY ?? this.paperFracY,
      fontSizePt: fontSizePt ?? this.fontSizePt,
    );
  }
}
