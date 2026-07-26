import 'dart:math' as math;

import 'plot_options.dart';
import 'survey_point.dart';

/// Civil 3D–style dragged label state for one stake point.
///
/// The point marker stays fixed; only the label anchor moves by
/// [offsetE] / [offsetN] (survey feet from the point).
class LabelDragState {
  const LabelDragState({
    this.offsetE = 0,
    this.offsetN = 0,
    this.customText,
  });

  /// Easting offset of the label anchor from the point (feet).
  final double offsetE;

  /// Northing offset of the label anchor from the point (feet).
  final double offsetN;

  /// When set, replaces the format-derived label lines (newline-separated).
  final String? customText;

  bool get isDragged => offsetE.abs() > 0.05 || offsetN.abs() > 0.05;

  List<String>? get customLines {
    final t = customText?.trim();
    if (t == null || t.isEmpty) return null;
    return t.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  LabelDragState copyWith({
    double? offsetE,
    double? offsetN,
    String? customText,
    bool clearCustomText = false,
  }) {
    return LabelDragState(
      offsetE: offsetE ?? this.offsetE,
      offsetN: offsetN ?? this.offsetN,
      customText: clearCustomText ? null : (customText ?? this.customText),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LabelDragState &&
        other.offsetE == offsetE &&
        other.offsetN == offsetN &&
        other.customText == customText;
  }

  @override
  int get hashCode => Object.hash(offsetE, offsetN, customText);
}

/// Text drawn next to each stake point (shared by PDF + preview).
List<String> labelLinesFor(SurveyPoint p, PointLabelFormat format) {
  switch (format) {
    case PointLabelFormat.none:
      return const [];
    case PointLabelFormat.numberOnly:
      return [p.id];
    case PointLabelFormat.numberDescription:
      return [
        p.id,
        if (p.description.trim().isNotEmpty) p.description.trim().toUpperCase(),
      ];
    case PointLabelFormat.numberElevation:
      return [p.id, p.elevText];
    case PointLabelFormat.numberDescriptionElevation:
      return [
        p.id,
        if (p.description.trim().isNotEmpty) p.description.trim().toUpperCase(),
        p.elevText,
      ];
  }
}

/// Resolve label text lines for a point (custom override or format).
List<String> resolvedLabelLines(
  SurveyPoint p,
  PointLabelFormat format,
  LabelDragState? drag,
) {
  final custom = drag?.customLines;
  if (custom != null && custom.isNotEmpty) return custom;
  return labelLinesFor(p, format);
}

/// Auto-spread undragged labels so dense clusters stay readable.
///
/// Collision is computed in absolute survey feet so labels on distant points
/// do not falsely collide. Existing dragged labels in [existing] are preserved.
Map<String, LabelDragState> autoSpreadLabels({
  required List<SurveyPoint> points,
  required PointLabelFormat format,
  required double scaleFtPerInch,
  Map<String, LabelDragState> existing = const {},
  double annotationScale = 1.0,
}) {
  if (format == PointLabelFormat.none || points.isEmpty) {
    return Map<String, LabelDragState>.from(existing);
  }

  final ppt = 72.0 / math.max(scaleFtPerInch, 1.0); // paper points per foot
  final fontPt = (8.5 * annotationScale).clamp(7.0, 14.0);
  final result = <String, LabelDragState>{...existing};
  // Occupied boxes in absolute survey feet: [minE, minN, maxE, maxN]
  final occupied = <List<double>>[];

  List<double> boxAt(double e, double n, double wFt, double hFt) {
    return [e, n - hFt / 2, e + wFt, n + hFt / 2];
  }

  // Seed occupied with already-dragged labels (absolute ground position).
  for (final p in points) {
    final drag = existing[p.id];
    if (drag == null || !drag.isDragged) continue;
    final lines = resolvedLabelLines(p, format, drag);
    if (lines.isEmpty) continue;
    final labelWFt = _labelWidthPt(lines, fontPt) / ppt;
    final labelHFt = (fontPt * 1.2 * lines.length) / ppt;
    occupied.add(
      boxAt(p.easting + drag.offsetE, p.northing + drag.offsetN, labelWFt, labelHFt),
    );
  }

  // Spiral candidate offsets in feet (Civil-style drag distances).
  final distances = <double>[
    12, 18, 26, 36, 48, 64, 80, 100, 130, 160, 200, 260,
  ];
  final angles = <double>[
    30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330, 0,
    45, 135, 225, 315,
  ];

  for (final p in points) {
    final prev = existing[p.id];
    if (prev != null && prev.isDragged) continue;
    final lines = resolvedLabelLines(p, format, prev);
    if (lines.isEmpty) continue;
    final labelWFt = _labelWidthPt(lines, fontPt) / ppt;
    final labelHFt = (fontPt * 1.2 * lines.length) / ppt;

    LabelDragState? chosen;
    for (final dist in distances) {
      for (final deg in angles) {
        final rad = deg * math.pi / 180;
        final oE = dist * math.cos(rad);
        final oN = dist * math.sin(rad);
        final box = boxAt(
          p.easting + oE,
          p.northing + oN,
          labelWFt,
          labelHFt,
        );
        if (occupied.any((o) => _overlap(box, o))) continue;
        chosen = LabelDragState(
          offsetE: oE,
          offsetN: oN,
          customText: prev?.customText,
        );
        occupied.add(box);
        break;
      }
      if (chosen != null) break;
    }
    result[p.id] = chosen ??
        LabelDragState(
          offsetE: 18,
          offsetN: 12,
          customText: prev?.customText,
        );
    if (chosen == null) {
      final fallback = result[p.id]!;
      occupied.add(
        boxAt(
          p.easting + fallback.offsetE,
          p.northing + fallback.offsetN,
          labelWFt,
          labelHFt,
        ),
      );
    }
  }
  return result;
}

double _labelWidthPt(List<String> lines, double fontPt) {
  var maxChars = 1;
  for (final l in lines) {
    if (l.length > maxChars) maxChars = l.length;
  }
  return math.max(36.0, maxChars * fontPt * 0.55 + 6);
}

bool _overlap(List<double> a, List<double> b) {
  return !(a[2] <= b[0] || b[2] <= a[0] || a[3] <= b[1] || b[3] <= a[1]);
}
