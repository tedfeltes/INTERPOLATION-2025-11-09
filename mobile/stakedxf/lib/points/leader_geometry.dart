import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Civil 3D–style leader: point → elbow → label landing (never through text).
class LeaderGeometry {
  const LeaderGeometry({
    required this.point,
    required this.elbow,
    required this.landing,
    required this.labelOrigin,
    required this.labelRect,
  });

  final Offset point;
  final Offset elbow;
  final Offset landing;
  /// Top-left of the label text box in the same coordinate space.
  final Offset labelOrigin;
  final Rect labelRect;
}

/// Build a dogleg leader that attaches to the label edge facing [point].
///
/// [labelAnchor] is the desired label center (from drag offset). The label
/// box is placed so its center sits at that anchor; the leader lands on the
/// left or right edge mid-height and never crosses the text.
LeaderGeometry buildLeader({
  required Offset point,
  required Offset labelAnchor,
  required double labelWidth,
  required double labelHeight,
  double landingLength = 10,
}) {
  final w = math.max(labelWidth, 8.0);
  final h = math.max(labelHeight, 8.0);
  final left = labelAnchor.dx - w / 2;
  final top = labelAnchor.dy - h / 2;
  final rect = Rect.fromLTWH(left, top, w, h);

  final labelRightOfPoint = labelAnchor.dx >= point.dx;
  final landing = Offset(
    labelRightOfPoint ? rect.left : rect.right,
    rect.center.dy,
  );

  // Elbow sits outside the label, aligned with landing Y (horizontal hook).
  final elbow = Offset(
    labelRightOfPoint
        ? landing.dx - landingLength
        : landing.dx + landingLength,
    landing.dy,
  );

  return LeaderGeometry(
    point: point,
    elbow: elbow,
    landing: landing,
    labelOrigin: Offset(rect.left, rect.top),
    labelRect: rect,
  );
}

/// Paper-space leader for PDF (Y-up). Same geometry, PDF points.
({double lx, double ly, double ex, double ey, double ax, double ay, double ox, double oy})
    buildLeaderPdf({
  required double pointX,
  required double pointY,
  required double anchorX,
  required double anchorY,
  required double labelWidth,
  required double labelHeight,
  double landingLength = 10,
}) {
  final w = math.max(labelWidth, 8.0);
  final h = math.max(labelHeight, 8.0);
  final left = anchorX; // PDF labels drawn from left; anchor is left-center-ish
  // Treat anchor as left-center of text block (matches prior drawString x).
  final top = anchorY - h / 2;
  final right = left + w;
  final midY = anchorY;

  final labelRightOfPoint = (left + w / 2) >= pointX;
  final landingX = labelRightOfPoint ? left : right;
  final landingY = midY;
  final elbowX =
      labelRightOfPoint ? landingX - landingLength : landingX + landingLength;
  final elbowY = landingY;

  return (
    lx: landingX,
    ly: landingY,
    ex: elbowX,
    ey: elbowY,
    ax: pointX,
    ay: pointY,
    ox: left,
    oy: top,
  );
}
