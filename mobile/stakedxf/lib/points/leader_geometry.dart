import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Civil 3D–style leader: point → elbow → label landing (never through text).
///
/// The renderer draws `point → hinge → elbow → landing`. When the point is
/// clearly above/below the label the hinge collapses to the elbow, producing
/// the traditional 2-segment leader (diagonal + horizontal shoulder). When
/// the point sits level with the label — which is where the classic
/// "strikethrough" bug used to appear — the hinge becomes an actual 3rd
/// vertex so the arrow leaves the point horizontally, wraps around the
/// label's nearest corner, and lands cleanly on the side edge.
class LeaderGeometry {
  const LeaderGeometry({
    required this.point,
    required this.hinge,
    required this.elbow,
    required this.landing,
    required this.labelOrigin,
    required this.labelRect,
  });

  final Offset point;
  final Offset hinge;
  final Offset elbow;
  final Offset landing;
  /// Top-left of the label text box in the same coordinate space.
  final Offset labelOrigin;
  final Rect labelRect;
}

/// Build a dogleg leader that attaches to the label edge facing [point].
///
/// [labelAnchor] is the desired label center (from drag offset). The label
/// box is placed so its center sits at that anchor. The leader is routed so
/// it **never crosses the label rectangle** — the landing sits on the label
/// edge closest to [point], and the elbow is positioned outside the label so
/// the diagonal from [point] to elbow cannot pass through the text.
///
/// The old implementation always landed on the left/right edge at the label
/// vertical centre, which — for 2-line labels — put the horizontal shoulder
/// smack through the second line's ascent zone. That produced the visible
/// "strikethrough" on outputs like
/// `OLDE_HIGHLANDER_STAKE-STM-OH_2023-12-14_staking_plot.pdf`.
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
  final landingX = labelRightOfPoint ? rect.left : rect.right;

  // The point is "level with" the label when its Y sits inside the label
  // rect's vertical extent. That's the case where the naïve landing-at-midY
  // ends up striking through the second line of text on the printed PDF.
  final levelWithLabel = point.dy >= rect.top && point.dy <= rect.bottom;

  final double landingY;
  if (!levelWithLabel) {
    // Standard Civil 3D shoulder: land on the side edge at the label centre.
    landingY = rect.center.dy;
  } else if (point.dy - rect.top < rect.bottom - point.dy) {
    // Point is closer to the label's top edge — hook along that edge.
    landingY = rect.top;
  } else {
    landingY = rect.bottom;
  }

  final landing = Offset(landingX, landingY);
  final elbow = Offset(
    labelRightOfPoint
        ? landing.dx - landingLength
        : landing.dx + landingLength,
    landing.dy,
  );
  // Hinge lets us wrap around the label without the diagonal cutting
  // through the text. When point.dy is outside the label rect the hinge
  // collapses onto the elbow (2-segment leader). When it's inside, the
  // hinge sits at the point's Y directly under/over the elbow so the arrow
  // leaves the point horizontally, jogs vertically to the shoulder Y, then
  // runs into the label along the shoulder.
  final hinge = levelWithLabel ? Offset(elbow.dx, point.dy) : elbow;

  return LeaderGeometry(
    point: point,
    hinge: hinge,
    elbow: elbow,
    landing: landing,
    labelOrigin: Offset(rect.left, rect.top),
    labelRect: rect,
  );
}

/// Paper-space leader for PDF. Same geometry as [buildLeader] with an
/// explicit hinge (``hx``, ``hy``) between the arrow tail and the elbow so
/// the renderer can draw a 3-segment leader when the point is level with
/// the label. When the hinge equals the elbow the leader collapses back to
/// the classic 2-segment style.
({
  double lx,
  double ly,
  double ex,
  double ey,
  double hx,
  double hy,
  double ax,
  double ay,
  double ox,
  double oy,
})
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
  // NB: In PDF y-up, "top" of the rect below is the MIN y edge (label
  // visually bottom). We keep the variable names top/bottom purely for
  // symmetry with the Flutter version — the y arithmetic is the same either
  // way because we always compare against min-y and max-y.
  final top = anchorY - h / 2;
  final bottom = anchorY + h / 2;
  final right = left + w;
  final midY = anchorY;

  final labelRightOfPoint = (left + w / 2) >= pointX;
  final landingX = labelRightOfPoint ? left : right;

  final levelWithLabel = pointY >= top && pointY <= bottom;
  final double landingY;
  if (!levelWithLabel) {
    landingY = midY;
  } else if (pointY - top < bottom - pointY) {
    landingY = top;
  } else {
    landingY = bottom;
  }

  final elbowX =
      labelRightOfPoint ? landingX - landingLength : landingX + landingLength;
  final elbowY = landingY;
  final hingeX = elbowX;
  final hingeY = levelWithLabel ? pointY : elbowY;

  return (
    lx: landingX,
    ly: landingY,
    ex: elbowX,
    ey: elbowY,
    hx: hingeX,
    hy: hingeY,
    ax: pointX,
    ay: pointY,
    ox: left,
    oy: top,
  );
}
