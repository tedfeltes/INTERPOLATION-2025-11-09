import 'dart:math' as math;

import 'package:pdf/pdf.dart';
import 'package:vector_math/vector_math_64.dart';

import 'block_catalog.dart';
import 'plot_symbols.dart';

/// Draw all placed symbols (after linework; typically before stake markers).
///
/// Size is **paper-based** (inches × object scale only) — independent of
/// annotation scale. Object name labels draw when [showLabels] is true.
void drawPlacedSymbols(
  PdfGraphics canvas,
  PdfPoint Function(double e, double n) toPage,
  double ppt,
  List<PlacedPlotSymbol> symbols,
  PdfFont labelFont, {
  BlockCatalog? blocks,
  bool showLabels = false,
  double symbolPaperInches = 0.28,
  double annotationScale = 1.0,
}) {
  for (final sym in symbols) {
    final c = toPage(sym.easting, sym.northing);
    // Independent of annotationScale — each object has its own scale.
    final half = math.max(
      5.0,
      (symbolPaperInches * 72.0 / 2.0) * sym.scale,
    );
    final color = PdfColor.fromInt(sym.colorArgb | 0xFF000000);

    canvas.saveContext();
    canvas.setGraphicState(
      PdfGraphicState(opacity: sym.opacity.clamp(0.05, 1.0)),
    );
    final rad = sym.rotationDeg * math.pi / 180;
    final matrix = Matrix4.identity()
      ..translate(c.x, c.y)
      ..rotateZ(rad);
    canvas.setTransform(matrix);
    if (sym.kind != null) {
      drawSymbolKind(canvas, sym.kind!, half, color);
    } else if (sym.blockId != null && blocks != null) {
      final def = blocks[sym.blockId!];
      if (def != null) {
        drawBlockSymbol(canvas, def, half, color);
      }
    }
    canvas.restoreContext();

    if (showLabels) {
      final text = sym.libraryLabel;
      // Label size tracks object scale, not annotation scale.
      final fontSize = (7.0 * sym.scale).clamp(6.0, 14.0);
      canvas
        ..setFillColor(color)
        ..drawString(labelFont, fontSize, text, c.x + half + 2, c.y - 2);
    }
  }
}

/// Draw an extracted DWG block (paths normalized to unit square).
void drawBlockSymbol(
  PdfGraphics canvas,
  DwgBlockSymbol block,
  double half,
  PdfColor color,
) {
  canvas
    ..setStrokeColor(color)
    ..setFillColor(color)
    ..setLineWidth(0.8);
  final s = half * 2; // unit square → diameter 2*half
  for (final path in block.paths) {
    if (path.points.length < 2) continue;
    final first = path.points.first;
    canvas.moveTo(first[0] * s, first[1] * s);
    for (var i = 1; i < path.points.length; i++) {
      final p = path.points[i];
      canvas.lineTo(p[0] * s, p[1] * s);
    }
    if (path.closed) {
      canvas.closePath();
    }
    canvas.strokePath();
  }
}

/// Draw one library symbol centered at the current transform origin.
void drawSymbolKind(
  PdfGraphics canvas,
  PlotSymbolKind kind,
  double half,
  PdfColor color,
) {
  _drawKind(canvas, kind, half, color);
}

void _drawKind(
  PdfGraphics canvas,
  PlotSymbolKind kind,
  double half,
  PdfColor color,
) {
  canvas
    ..setStrokeColor(color)
    ..setFillColor(color)
    ..setLineWidth(1.0);

  switch (kind) {
    case PlotSymbolKind.fireHydrant:
      _hydrant(canvas, half, color);
    case PlotSymbolKind.waterValve:
    case PlotSymbolKind.gateValve:
      _valve(canvas, half);
    case PlotSymbolKind.sanitaryManhole:
      _manhole(canvas, half);
    case PlotSymbolKind.stormManhole:
      _manhole(canvas, half);
    case PlotSymbolKind.cleanout:
      _cleanout(canvas, half);
    case PlotSymbolKind.catchBasin:
      _squareGrate(canvas, half);
    case PlotSymbolKind.curbInlet:
      _rectInlet(canvas, half);
    case PlotSymbolKind.fieldInlet:
      _circleGrate(canvas, half);
    case PlotSymbolKind.flaredEnd:
      _flaredEnd(canvas, half);
    case PlotSymbolKind.ripRap:
      _ripRap(canvas, half);
    case PlotSymbolKind.inlineDrain:
      _inlineDrain(canvas, half);
    case PlotSymbolKind.stopSign:
      _octagon(canvas, half, color, hatch: true);
    case PlotSymbolKind.yieldSign:
      _yield(canvas, half);
    case PlotSymbolKind.doNotEnter:
      _doNotEnter(canvas, half, color);
    case PlotSymbolKind.oneWay:
      _oneWay(canvas, half);
    case PlotSymbolKind.speedLimit:
      _rectSign(canvas, half);
    case PlotSymbolKind.noOutlet:
    case PlotSymbolKind.pedCrossing:
    case PlotSymbolKind.bikeCrossing:
      _diamond(canvas, half);
    case PlotSymbolKind.handicapSign:
      _handicap(canvas, half);
    case PlotSymbolKind.bollard:
      _bollard(canvas, half, color);
    case PlotSymbolKind.lightPole:
      _lightPole(canvas, half, color);
    case PlotSymbolKind.tree:
      _tree(canvas, half, color);
    case PlotSymbolKind.ironPipe:
      _ironPipe(canvas, half);
    case PlotSymbolKind.benchmark:
      _benchmark(canvas, half, color);
    case PlotSymbolKind.hub:
      _hub(canvas, half);
    case PlotSymbolKind.siltFence:
      _siltFence(canvas, half);
    case PlotSymbolKind.inletProtection:
      _inletProtection(canvas, half);
    case PlotSymbolKind.wattle:
      _wattle(canvas, half);
    case PlotSymbolKind.dewateringBag:
      _dewateringBag(canvas, half);
    case PlotSymbolKind.callout:
      _callout(canvas, half);
    case PlotSymbolKind.detailRef:
      _detailRef(canvas, half);
    case PlotSymbolKind.noteBox:
      _noteBox(canvas, half);
  }
}

void _strokeCircle(PdfGraphics c, double r) {
  c
    ..drawEllipse(0, 0, r, r)
    ..strokePath();
}

void _hydrant(PdfGraphics c, double h, PdfColor color) {
  _strokeCircle(c, h * 0.55);
  c
    ..moveTo(-h * 0.9, 0)
    ..lineTo(-h * 0.55, 0)
    ..moveTo(h * 0.55, 0)
    ..lineTo(h * 0.9, 0)
    ..moveTo(0, h * 0.55)
    ..lineTo(0, h * 0.95)
    ..strokePath();
  // Solid centre dot (small filled circle) — no hatch.
  c
    ..setFillColor(color)
    ..drawEllipse(0, 0, h * 0.16, h * 0.16)
    ..fillPath();
}

void _valve(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.7);
  c
    ..moveTo(-h * 0.45, -h * 0.45)
    ..lineTo(h * 0.45, h * 0.45)
    ..moveTo(h * 0.45, -h * 0.45)
    ..lineTo(-h * 0.45, h * 0.45)
    ..strokePath();
}

void _manhole(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.75);
  _strokeCircle(c, h * 0.45);
  c
    ..moveTo(-h * 0.2, 0)
    ..lineTo(h * 0.2, 0)
    ..moveTo(0, -h * 0.2)
    ..lineTo(0, h * 0.2)
    ..strokePath();
}

void _cleanout(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.55);
  c
    ..moveTo(0, -h * 0.55)
    ..lineTo(0, h * 0.55)
    ..strokePath();
}

void _squareGrate(PdfGraphics c, double h) {
  final s = h * 0.75;
  c
    ..drawRect(-s, -s, s * 2, s * 2)
    ..strokePath();
  for (var i = -2; i <= 2; i++) {
    final x = i * s / 2.5;
    c
      ..moveTo(x, -s)
      ..lineTo(x, s);
  }
  c.strokePath();
}

void _rectInlet(PdfGraphics c, double h) {
  c
    ..drawRect(-h * 0.9, -h * 0.45, h * 1.8, h * 0.9)
    ..strokePath();
  for (var i = -2; i <= 2; i++) {
    final x = i * h * 0.3;
    c
      ..moveTo(x, -h * 0.45)
      ..lineTo(x, h * 0.45);
  }
  c.strokePath();
}

void _circleGrate(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.7);
  for (var i = 0; i < 4; i++) {
    final a = i * math.pi / 4;
    c
      ..moveTo(math.cos(a) * -h * 0.7, math.sin(a) * -h * 0.7)
      ..lineTo(math.cos(a) * h * 0.7, math.sin(a) * h * 0.7);
  }
  c.strokePath();
}

void _flaredEnd(PdfGraphics c, double h) {
  c
    ..moveTo(-h, -h * 0.35)
    ..lineTo(h * 0.2, -h * 0.2)
    ..lineTo(h * 0.2, h * 0.2)
    ..lineTo(-h, h * 0.35)
    ..closePath()
    ..strokePath();
  _strokeCircle(c, h * 0.22);
}

void _ripRap(PdfGraphics c, double h) {
  c
    ..drawRect(-h, -h * 0.7, h * 2, h * 1.4)
    ..strokePath();
  final pts = [
    [-0.5, -0.2],
    [0.1, 0.25],
    [0.55, -0.15],
    [-0.2, 0.35],
    [0.35, 0.4],
    [-0.6, 0.15],
  ];
  for (final p in pts) {
    c.drawEllipse(p[0] * h, p[1] * h, 1.8, 1.4);
  }
  c.strokePath();
}

void _inlineDrain(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.55);
  c
    ..drawRect(-h * 0.95, -h * 0.2, h * 1.9, h * 0.4)
    ..strokePath();
}

void _octagon(
  PdfGraphics c,
  double h,
  PdfColor color, {
  // ignore: avoid_unused_constructor_parameters
  bool hatch = false,
}) {
  // Outline only — the field plot never hatch-fills solid signage shapes.
  final r = h * 0.85;
  final pts = <PdfPoint>[];
  for (var i = 0; i < 8; i++) {
    final a = -math.pi / 8 + i * math.pi / 4;
    pts.add(PdfPoint(math.cos(a) * r, math.sin(a) * r));
  }
  c.moveTo(pts.first.x, pts.first.y);
  for (var i = 1; i < pts.length; i++) {
    c.lineTo(pts[i].x, pts[i].y);
  }
  c
    ..closePath()
    ..strokePath();
}

void _yield(PdfGraphics c, double h) {
  c
    ..moveTo(0, h * 0.85)
    ..lineTo(-h * 0.85, -h * 0.7)
    ..lineTo(h * 0.85, -h * 0.7)
    ..closePath()
    ..strokePath();
  c
    ..moveTo(0, h * 0.45)
    ..lineTo(-h * 0.5, -h * 0.4)
    ..lineTo(h * 0.5, -h * 0.4)
    ..closePath()
    ..strokePath();
}

void _doNotEnter(PdfGraphics c, double h, PdfColor color) {
  _strokeCircle(c, h * 0.8);
  // Solid outline bar — no hatch fill.
  c
    ..drawRect(-h * 0.5, -h * 0.18, h, h * 0.36)
    ..strokePath();
}

void _oneWay(PdfGraphics c, double h) {
  c
    ..drawRect(-h * 0.7, -h * 0.45, h * 1.4, h * 0.9)
    ..strokePath();
  c
    ..moveTo(-h * 0.35, 0)
    ..lineTo(h * 0.15, 0)
    ..lineTo(h * 0.15, -h * 0.22)
    ..lineTo(h * 0.5, 0)
    ..lineTo(h * 0.15, h * 0.22)
    ..lineTo(h * 0.15, 0)
    ..strokePath();
}

void _rectSign(PdfGraphics c, double h) {
  c
    ..drawRect(-h * 0.55, -h * 0.75, h * 1.1, h * 1.5)
    ..strokePath();
  c
    ..moveTo(-h * 0.35, h * 0.15)
    ..lineTo(h * 0.35, h * 0.15)
    ..moveTo(-h * 0.25, -h * 0.15)
    ..lineTo(h * 0.25, -h * 0.15)
    ..strokePath();
}

void _diamond(PdfGraphics c, double h) {
  c
    ..moveTo(0, h * 0.9)
    ..lineTo(h * 0.9, 0)
    ..lineTo(0, -h * 0.9)
    ..lineTo(-h * 0.9, 0)
    ..closePath()
    ..strokePath();
}

void _handicap(PdfGraphics c, double h) {
  _rectSign(c, h * 0.85);
  _strokeCircle(c, h * 0.22);
  c
    ..moveTo(0, -h * 0.15)
    ..lineTo(0, -h * 0.45)
    ..lineTo(h * 0.25, -h * 0.55)
    ..strokePath();
}

void _fillDot(PdfGraphics c, double r, PdfColor color) {
  c
    ..setFillColor(color)
    ..drawEllipse(0, 0, r, r)
    ..fillPath();
}

void _bollard(PdfGraphics c, double h, PdfColor color) {
  _fillDot(c, h * 0.28, color);
  _strokeCircle(c, h * 0.55);
}

void _lightPole(PdfGraphics c, double h, PdfColor color) {
  _fillDot(c, h * 0.16, color);
  _strokeCircle(c, h * 0.7);
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4;
    c
      ..moveTo(math.cos(a) * h * 0.25, math.sin(a) * h * 0.25)
      ..lineTo(math.cos(a) * h * 0.7, math.sin(a) * h * 0.7);
  }
  c.strokePath();
}

void _tree(PdfGraphics c, double h, PdfColor color) {
  _strokeCircle(c, h * 0.75);
  _strokeCircle(c, h * 0.45);
  _fillDot(c, h * 0.10, color);
}

void _ironPipe(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.55);
  c
    ..moveTo(0, h * 0.55)
    ..lineTo(0, h * 0.9)
    ..strokePath();
}

void _benchmark(PdfGraphics c, double h, PdfColor color) {
  c
    ..moveTo(0, h * 0.85)
    ..lineTo(h * 0.75, -h * 0.55)
    ..lineTo(-h * 0.75, -h * 0.55)
    ..closePath()
    ..strokePath();
  _fillDot(c, h * 0.10, color);
}

void _hub(PdfGraphics c, double h) {
  c
    ..moveTo(-h * 0.7, -h * 0.7)
    ..lineTo(h * 0.7, h * 0.7)
    ..moveTo(h * 0.7, -h * 0.7)
    ..lineTo(-h * 0.7, h * 0.7)
    ..strokePath();
  _strokeCircle(c, h * 0.25);
}

void _siltFence(PdfGraphics c, double h) {
  c
    ..moveTo(-h, 0)
    ..lineTo(h, 0)
    ..strokePath();
  for (var i = -3; i <= 3; i++) {
    final x = i * h / 3.5;
    c
      ..moveTo(x, 0)
      ..lineTo(x, h * 0.45)
      ..moveTo(x - h * 0.08, h * 0.45)
      ..lineTo(x + h * 0.08, h * 0.45);
  }
  c.strokePath();
}

void _inletProtection(PdfGraphics c, double h) {
  _squareGrate(c, h * 0.7);
  c
    ..drawRect(-h * 0.95, -h * 0.95, h * 1.9, h * 1.9)
    ..strokePath();
}

void _wattle(PdfGraphics c, double h) {
  c
    ..drawEllipse(0, 0, h, h * 0.35)
    ..strokePath();
  for (var i = -2; i <= 2; i++) {
    c
      ..moveTo(i * h * 0.35, -h * 0.2)
      ..lineTo(i * h * 0.35 + h * 0.1, h * 0.2);
  }
  c.strokePath();
}

void _dewateringBag(PdfGraphics c, double h) {
  c
    ..drawRect(-h * 0.9, -h * 0.6, h * 1.8, h * 1.2)
    ..strokePath();
  for (var i = -3; i <= 3; i++) {
    c
      ..moveTo(-h * 0.9, i * h * 0.15)
      ..lineTo(h * 0.9, i * h * 0.15);
  }
  c.strokePath();
}

void _callout(PdfGraphics c, double h) {
  _strokeCircle(c, h * 0.7);
  c
    ..moveTo(h * 0.5, -h * 0.5)
    ..lineTo(h, -h)
    ..strokePath();
}

void _detailRef(PdfGraphics c, double h) {
  c
    ..drawRect(-h, -h * 0.45, h * 2, h * 0.9)
    ..strokePath();
  c
    ..moveTo(-h * 0.7, 0)
    ..lineTo(h * 0.7, 0)
    ..strokePath();
}

void _noteBox(PdfGraphics c, double h) {
  c
    ..drawRect(-h, -h * 0.65, h * 2, h * 1.3)
    ..strokePath();
  for (var i = -2; i <= 2; i++) {
    c
      ..moveTo(-h * 0.8, i * h * 0.18)
      ..lineTo(h * 0.8, i * h * 0.18);
  }
  c.strokePath();
}
