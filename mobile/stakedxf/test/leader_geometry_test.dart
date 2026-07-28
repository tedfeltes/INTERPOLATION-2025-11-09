import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/leader_geometry.dart';

/// Regression tests for the label-strikethrough bug reproduced in
/// `OLDE_HIGHLANDER_STAKE-STM-OH_2023-12-14_staking_plot.pdf`. Whenever a
/// point sits vertically level with its label the leader used to run its
/// horizontal shoulder along the label's mid-Y line, which struck through
/// the description text ("STRUC", "FES", ...). The corrected geometry
/// hooks around the label edge instead.
void main() {
  group('buildLeader — 2-line label, point level with label', () {
    test('does not draw the shoulder inside the label rect', () {
      // Label centre is roughly at (100, 20). Point is level with the
      // label at Y = 20, well to the right.
      final g = buildLeader(
        point: const Offset(300, 20),
        labelAnchor: const Offset(100, 20),
        labelWidth: 90,
        labelHeight: 24,
        landingLength: 10,
      );

      final rect = g.labelRect;
      // Landing must sit on the label edge FACING the point (point is to
      // the right, so the landing is on the label's right edge).
      expect(g.landing.dx, rect.right);
      // Landing must snap to whichever horizontal edge is closer to the
      // point Y (top edge in this tie-break because we use `<`).
      final onEdge = g.landing.dy == rect.top || g.landing.dy == rect.bottom;
      expect(
        onEdge,
        isTrue,
        reason: 'When the point is level with the label the shoulder must '
            'hook along a top/bottom edge, never through midY.',
      );

      // The shoulder (elbow → landing) shares Y with the landing and sits
      // outside the label's X range on the point-facing side. It must
      // therefore not intersect the label rect except at the landing edge.
      expect(g.elbow.dy, g.landing.dy);
      expect(g.elbow.dx < rect.left || g.elbow.dx > rect.right, isTrue);

      // The hinge is on the elbow's X but at the point's Y so the "arrow"
      // leaves the point horizontally, then jogs vertically to the
      // shoulder — never cutting through the text.
      expect(g.hinge.dx, g.elbow.dx);
      expect(g.hinge.dy, 20);
    });
  });

  group('buildLeader — point clearly above the label', () {
    test('collapses to the classic 2-segment shoulder at midY', () {
      final g = buildLeader(
        point: const Offset(300, 200),
        labelAnchor: const Offset(100, 20),
        labelWidth: 90,
        labelHeight: 24,
        landingLength: 10,
      );

      final rect = g.labelRect;
      // Landing at label centre for the "clear vertical separation" case.
      expect(g.landing.dy, rect.center.dy);
      // With point clearly outside the label Y range the hinge collapses
      // onto the elbow so we draw a 2-segment leader.
      expect(g.hinge, g.elbow);
    });
  });

  group('buildLeaderPdf', () {
    test('level with label routes the arrow tail via a hinge', () {
      final g = buildLeaderPdf(
        pointX: 300,
        pointY: 20,
        anchorX: 60, // label left edge
        anchorY: 20,
        labelWidth: 90,
        labelHeight: 24,
        landingLength: 10,
      );

      // The point Y sits inside the label Y range so the shoulder must
      // land on a horizontal edge (min-y or max-y), not the label centre.
      final top = 20.0 - 12; // anchorY - h/2
      final bottom = 20.0 + 12;
      expect(g.ly == top || g.ly == bottom, isTrue);
      // The renderer treats a matching hinge/elbow as the classic
      // 2-segment leader; a distinct hinge marks the "wrap around" case.
      expect(g.hy, 20.0);
      expect(g.hx, g.ex);
    });
  });
}
