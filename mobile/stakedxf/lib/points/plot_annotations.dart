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
    );
  }
}

/// Editable title-block fields drawn on the sheet (not plan-space).
class TitleBlockData {
  const TitleBlockData({
    this.enabled = false,
    this.title = 'STAKING PLOT',
    this.project = '',
    this.drawnBy = '',
    this.checkedBy = '',
    this.sheet = '1 of 1',
    this.revision = '',
    this.notes = '',
  });

  final bool enabled;
  final String title;
  final String project;
  final String drawnBy;
  final String checkedBy;
  final String sheet;
  final String revision;
  final String notes;

  TitleBlockData copyWith({
    bool? enabled,
    String? title,
    String? project,
    String? drawnBy,
    String? checkedBy,
    String? sheet,
    String? revision,
    String? notes,
  }) {
    return TitleBlockData(
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      project: project ?? this.project,
      drawnBy: drawnBy ?? this.drawnBy,
      checkedBy: checkedBy ?? this.checkedBy,
      sheet: sheet ?? this.sheet,
      revision: revision ?? this.revision,
      notes: notes ?? this.notes,
    );
  }
}
