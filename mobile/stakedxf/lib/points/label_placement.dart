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
    this.pinned = false,
  });

  /// Easting offset of the label anchor from the point (feet).
  final double offsetE;

  /// Northing offset of the label anchor from the point (feet).
  final double offsetN;

  /// When set, replaces the format-derived label lines (newline-separated).
  final String? customText;

  /// When true, user dragged/edited this label — auto-spread will not move it.
  final bool pinned;

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
    bool? pinned,
    bool clearCustomText = false,
  }) {
    return LabelDragState(
      offsetE: offsetE ?? this.offsetE,
      offsetN: offsetN ?? this.offsetN,
      customText: clearCustomText ? null : (customText ?? this.customText),
      pinned: pinned ?? this.pinned,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LabelDragState &&
        other.offsetE == offsetE &&
        other.offsetN == offsetN &&
        other.customText == customText &&
        other.pinned == pinned;
  }

  @override
  int get hashCode => Object.hash(offsetE, offsetN, customText, pinned);
}

/// Text drawn next to each stake point (shared by PDF + preview).
List<String> labelLinesFor(SurveyPoint p, PointLabelFormat format) {
  final desc = p.description.trim().toUpperCase();
  switch (format) {
    case PointLabelFormat.none:
      return const [];
    case PointLabelFormat.numberOnly:
      return [p.id];
    case PointLabelFormat.numberDescription:
      return [
        p.id,
        if (desc.isNotEmpty) desc,
      ];
    case PointLabelFormat.numberElevation:
      return [p.id, p.elevText];
    case PointLabelFormat.numberDescriptionElevation:
      return [
        p.id,
        if (desc.isNotEmpty) desc,
        p.elevText,
      ];
    case PointLabelFormat.descriptionElevation:
      return [
        if (desc.isNotEmpty) desc,
        p.elevText,
      ];
    case PointLabelFormat.descriptionOnly:
      return desc.isEmpty ? const [] : [desc];
    case PointLabelFormat.elevationOnly:
      return [p.elevText];
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

/// Auto-spread unpinned labels so dense clusters stay readable.
///
/// Offsets are in survey feet. Distances scale with label size and engineering
/// scale so 1"=200' sheets still separate callouts. Pinned (user-dragged)
/// labels are preserved; previous auto placements may be recomputed.
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

  final ppt = 72.0 / math.max(scaleFtPerInch, 1.0);
  final fontPt = (8.5 * annotationScale).clamp(7.0, 14.0);
  final result = <String, LabelDragState>{};
  // Occupied boxes in absolute survey feet: [minE, minN, maxE, maxN]
  final occupied = <List<double>>[];

  List<double> boxAt(double e, double n, double wFt, double hFt) {
    final pad = math.max(4.0, scaleFtPerInch * 0.04);
    return [e - pad, n - hFt / 2 - pad, e + wFt + pad, n + hFt / 2 + pad];
  }

  // Reserve space around each fixed point marker.
  final markerR = math.max(6.0, scaleFtPerInch * 0.06);
  for (final p in points) {
    occupied.add([
      p.easting - markerR,
      p.northing - markerR,
      p.easting + markerR,
      p.northing + markerR,
    ]);
  }

  // Seed pinned labels.
  for (final p in points) {
    final drag = existing[p.id];
    if (drag == null || !drag.pinned) continue;
    final lines = resolvedLabelLines(p, format, drag);
    if (lines.isEmpty) continue;
    final labelWFt = _labelWidthPt(lines, fontPt) / ppt;
    final labelHFt = (fontPt * 1.25 * lines.length) / ppt;
    occupied.add(
      boxAt(p.easting + drag.offsetE, p.northing + drag.offsetN, labelWFt, labelHFt),
    );
    result[p.id] = drag;
  }

  // Candidate distances scale with typical label footprint at this sheet scale.
  final base = math.max(scaleFtPerInch * 0.35, 20.0);
  final distances = <double>[
    for (var i = 1; i <= 18; i++) base * (0.55 + i * 0.35),
  ];
  final angles = <double>[
    25, 45, 65, 90, 115, 135, 155, 180, 205, 225, 245, 270, 295, 315, 335, 0,
    15, 75, 105, 165, 195, 255, 285, 345,
  ];

  for (final p in points) {
    final prev = existing[p.id];
    if (prev != null && prev.pinned) continue;
    final lines = resolvedLabelLines(p, format, prev);
    if (lines.isEmpty) continue;
    final labelWFt = _labelWidthPt(lines, fontPt) / ppt;
    final labelHFt = (fontPt * 1.25 * lines.length) / ppt;

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
          pinned: false,
        );
        occupied.add(box);
        break;
      }
      if (chosen != null) break;
    }
    final fallback = chosen ??
        LabelDragState(
          offsetE: base * 1.2,
          offsetN: base * 0.8,
          customText: prev?.customText,
          pinned: false,
        );
    result[p.id] = fallback;
    if (chosen == null) {
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
