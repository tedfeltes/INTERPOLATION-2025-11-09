import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'linetype_catalog.dart';
import 'linework_style.dart';

/// Draw styled linework onto a Flutter canvas (live preview).
void paintLineworkFlutter({
  required Canvas canvas,
  required List<LineworkEntity> linework,
  required Offset Function(double e, double n) toPixel,
  required LinetypeCatalog catalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  Map<String, LineworkStyleOverride> layerOverrides = const {},
  Map<String, LineworkStyleOverride> entityOverrides = const {},
  double globalLinetypeScale = 1.0,
  CtbPlotStyleTable? ctb,
  String? selectedId,
  int? selectedSegmentIndex,
  int? selectedNodeIndex,
  bool showNodesForSelected = true,
}) {
  for (final ent in linework) {
    final style = resolveLineworkStyle(
      entity: ent,
      catalog: catalog,
      layerStyles: layerStyles,
      layerOverrides: layerOverrides,
      entityOverrides: entityOverrides,
      globalLinetypeScale: globalLinetypeScale,
      ctb: ctb,
      defaultStrokePt: 1.2,
    );
    final samples = [
      for (final p in ent.samplePoints)
        if (p[0].isFinite && p[1].isFinite) toPixel(p[0], p[1]),
    ];
    if (samples.length < 2) continue;

    final paint = Paint()
      ..color = Color(style.colorWithOpacity)
      ..strokeWidth = style.strokeWidthPt
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dash = style.dashPatternPoints();
    if (dash.isEmpty) {
      final path = Path()..moveTo(samples.first.dx, samples.first.dy);
      for (var i = 1; i < samples.length; i++) {
        path.lineTo(samples[i].dx, samples[i].dy);
      }
      if (ent.closed || ent.type == 'CIRCLE') path.close();
      canvas.drawPath(path, paint);
    } else {
      _strokeDashed(canvas, samples, dash, paint, closed: ent.closed);
    }

    if (ent.id == selectedId) {
      final hi = Paint()
        ..color = const Color(0xFFE4572E)
        ..strokeWidth = style.strokeWidthPt + 1.5
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(samples.first.dx, samples.first.dy);
      for (var i = 1; i < samples.length; i++) {
        path.lineTo(samples[i].dx, samples[i].dy);
      }
      canvas.drawPath(path, hi);

      if (showNodesForSelected) {
        final verts = [
          for (final v in ent.vertices)
            if (v.length >= 2) toPixel(v[0], v[1]),
        ];
        for (var i = 0; i < verts.length; i++) {
          final selected = i == selectedNodeIndex;
          canvas.drawCircle(
            verts[i],
            selected ? 6 : 4.5,
            Paint()
              ..color = selected
                  ? const Color(0xFFE4572E)
                  : const Color(0xFF1565C0),
          );
          canvas.drawCircle(
            verts[i],
            selected ? 6 : 4.5,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
        // Segment midpoints as selectable handles.
        final edgeCount = ent.closed ? verts.length : verts.length - 1;
        for (var i = 0; i < edgeCount && verts.length >= 2; i++) {
          final a = verts[i];
          final b = verts[(i + 1) % verts.length];
          final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
          final sel = i == selectedSegmentIndex;
          canvas.drawRect(
            Rect.fromCenter(center: mid, width: sel ? 10 : 8, height: sel ? 10 : 8),
            Paint()
              ..color = sel
                  ? const Color(0xFFE4572E)
                  : const Color(0xFF2E7D32),
          );
        }
      }
    }
  }
}

void _strokeDashed(
  Canvas canvas,
  List<Offset> pts,
  List<double> pattern,
  Paint paint, {
  bool closed = false,
}) {
  if (pts.length < 2 || pattern.isEmpty) return;
  final pathPts = [...pts];
  if (closed) pathPts.add(pts.first);

  var dist = 0.0;
  var drawing = true;
  var patIdx = 0;
  var patLeft = pattern[0];

  for (var i = 0; i < pathPts.length - 1; i++) {
    var a = pathPts[i];
    final b = pathPts[i + 1];
    var segLen = (b - a).distance;
    if (segLen < 1e-9) continue;
    final dir = Offset((b.dx - a.dx) / segLen, (b.dy - a.dy) / segLen);

    while (segLen > 1e-9) {
      final step = patLeft < segLen ? patLeft : segLen;
      final next = Offset(a.dx + dir.dx * step, a.dy + dir.dy * step);
      if (drawing) {
        canvas.drawLine(a, next, paint);
      }
      a = next;
      segLen -= step;
      patLeft -= step;
      dist += step;
      if (patLeft <= 1e-9) {
        patIdx = (patIdx + 1) % pattern.length;
        patLeft = pattern[patIdx];
        drawing = !drawing;
      }
    }
  }
  // silence unused
  assert(dist >= 0);
}

/// Draw styled linework onto a PDF canvas.
void paintLineworkPdf({
  required PdfGraphics canvas,
  required List<LineworkEntity> linework,
  required PdfPoint Function(double e, double n) toPage,
  required LinetypeCatalog catalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  Map<String, LineworkStyleOverride> layerOverrides = const {},
  Map<String, LineworkStyleOverride> entityOverrides = const {},
  double globalLinetypeScale = 1.0,
  CtbPlotStyleTable? ctb,
}) {
  for (final ent in linework) {
    final style = resolveLineworkStyle(
      entity: ent,
      catalog: catalog,
      layerStyles: layerStyles,
      layerOverrides: layerOverrides,
      entityOverrides: entityOverrides,
      globalLinetypeScale: globalLinetypeScale,
      ctb: ctb,
    );
    final samples = <PdfPoint>[
      for (final p in ent.samplePoints)
        if (p[0].isFinite && p[1].isFinite) toPage(p[0], p[1]),
    ];
    if (samples.length < 2) continue;

    final argb = style.colorWithOpacity;
    canvas
      ..setStrokeColor(PdfColor.fromInt(argb))
      ..setLineWidth(style.strokeWidthPt);

    final dash = style.dashPatternPoints();
    if (dash.isEmpty) {
      canvas.setLineDashPattern();
    } else {
      // pdf package wants List<num> pattern in points.
      canvas.setLineDashPattern(
        [for (final d in dash) d.round().clamp(1, 200)],
      );
    }

    canvas.moveTo(samples.first.x, samples.first.y);
    for (var i = 1; i < samples.length; i++) {
      canvas.lineTo(samples[i].x, samples[i].y);
    }
    if (ent.closed || ent.type == 'CIRCLE') {
      canvas.closePath();
    }
    canvas.strokePath();
  }
  canvas.setLineDashPattern();
}

/// Hit-test helpers (preview).
String? hitTestLinework(
  Offset local,
  List<LineworkEntity> linework,
  Offset Function(double e, double n) toPixel, {
  double threshold = 14,
}) {
  String? best;
  var bestDist = threshold;
  for (final ent in linework) {
    final samples = [
      for (final p in ent.samplePoints)
        if (p[0].isFinite && p[1].isFinite) toPixel(p[0], p[1]),
    ];
    for (var i = 0; i < samples.length - 1; i++) {
      final d = _distToSegment(local, samples[i], samples[i + 1]);
      if (d < bestDist) {
        bestDist = d;
        best = ent.id;
      }
    }
  }
  return best;
}

int? hitTestNode(
  Offset local,
  LineworkEntity ent,
  Offset Function(double e, double n) toPixel, {
  double threshold = 16,
}) {
  var best = -1;
  var bestDist = threshold;
  for (var i = 0; i < ent.vertices.length; i++) {
    final v = ent.vertices[i];
    if (v.length < 2) continue;
    final d = (toPixel(v[0], v[1]) - local).distance;
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best >= 0 ? best : null;
}

int? hitTestSegment(
  Offset local,
  LineworkEntity ent,
  Offset Function(double e, double n) toPixel, {
  double threshold = 16,
}) {
  final verts = [
    for (final v in ent.vertices)
      if (v.length >= 2) toPixel(v[0], v[1]),
  ];
  if (verts.length < 2) return null;
  final edgeCount = ent.closed ? verts.length : verts.length - 1;
  var best = -1;
  var bestDist = threshold;
  for (var i = 0; i < edgeCount; i++) {
    final a = verts[i];
    final b = verts[(i + 1) % verts.length];
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final d = (mid - local).distance;
    if (d < bestDist) {
      bestDist = d;
      best = i;
    }
  }
  return best >= 0 ? best : null;
}

double _distToSegment(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
  if (len2 < 1e-9) return (p - a).distance;
  var t = ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  t = t.clamp(0.0, 1.0);
  final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
  return (p - proj).distance;
}
