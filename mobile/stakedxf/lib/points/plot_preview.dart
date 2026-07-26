import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'block_catalog.dart';
import 'dxf_linework.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_symbols.dart';
import 'survey_point.dart';
import 'symbol_preview.dart';

/// Live interactive plan preview — same framing as the exported PDF.
///
/// Drag placed library objects to set survey N/E visually.
class PlotPreview extends StatefulWidget {
  const PlotPreview({
    super.key,
    required this.points,
    required this.options,
    this.linework = const [],
    this.symbols = const [],
    this.blockCatalog,
    this.selectedSymbolId,
    this.onSelectSymbol,
    this.onMoveSymbol,
    this.height = 280,
  });

  final List<SurveyPoint> points;
  final PlotOptions options;
  final List<LineworkEntity> linework;
  final List<PlacedPlotSymbol> symbols;
  final BlockCatalog? blockCatalog;
  final String? selectedSymbolId;
  final ValueChanged<String?>? onSelectSymbol;
  final void Function(String id, double easting, double northing)? onMoveSymbol;
  final double height;

  @override
  State<PlotPreview> createState() => _PlotPreviewState();
}

class _PlotPreviewState extends State<PlotPreview> {
  String? _draggingId;
  _PlanMap? _map;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.points.isEmpty) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF7F4EE),
          border: Border.all(color: cs.outline.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Select points to preview the staking plot',
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.55)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Live plot preview',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: cs.primary,
              ),
            ),
            const Spacer(),
            Text(
              'Drag objects to place · tap to select',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              _map = _PlanMap.fromContent(
                size: size,
                points: widget.points,
                linework: widget.linework,
                symbols: widget.symbols,
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F4EE),
                    border: Border.all(color: const Color(0xFF8A8478)),
                  ),
                  child: GestureDetector(
                    onTapUp: (d) => _handleTap(d.localPosition),
                    onPanStart: (d) => _handlePanStart(d.localPosition),
                    onPanUpdate: (d) => _handlePanUpdate(d.localPosition),
                    onPanEnd: (_) => _draggingId = null,
                    child: CustomPaint(
                      size: size,
                      painter: _PlotPreviewPainter(
                        map: _map!,
                        points: widget.points,
                        linework: widget.linework,
                        symbols: widget.symbols,
                        options: widget.options,
                        blockCatalog: widget.blockCatalog,
                        selectedSymbolId: widget.selectedSymbolId,
                        draggingId: _draggingId,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleTap(Offset local) {
    final map = _map;
    if (map == null) return;
    final hit = _hitSymbol(local, map);
    widget.onSelectSymbol?.call(hit?.id);
  }

  void _handlePanStart(Offset local) {
    final map = _map;
    if (map == null) return;
    final hit = _hitSymbol(local, map);
    _draggingId = hit?.id;
    if (hit != null) {
      widget.onSelectSymbol?.call(hit.id);
    }
  }

  void _handlePanUpdate(Offset local) {
    final map = _map;
    final id = _draggingId;
    if (map == null || id == null) return;
    final en = map.toSurvey(local);
    widget.onMoveSymbol?.call(id, en.$1, en.$2);
  }

  PlacedPlotSymbol? _hitSymbol(Offset local, _PlanMap map) {
    PlacedPlotSymbol? best;
    var bestDist = 28.0; // px hit radius
    for (final s in widget.symbols) {
      final c = map.toPixel(s.easting, s.northing);
      final d = (c - local).distance;
      final half = math.max(12.0, map.feetToPixels(s.sizeFt) / 2);
      if (d <= math.max(bestDist, half) && d < bestDist + half) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
}

class _PlanMap {
  _PlanMap({
    required this.size,
    required this.midE,
    required this.midN,
    required this.ftPerPx,
  });

  final Size size;
  final double midE;
  final double midN;
  final double ftPerPx;

  factory _PlanMap.fromContent({
    required Size size,
    required List<SurveyPoint> points,
    required List<LineworkEntity> linework,
    required List<PlacedPlotSymbol> symbols,
  }) {
    final bounds = computePlanViewBounds(
      points,
      linework: linework,
      symbols: symbols,
    );
    final pad = 1.12;
    final ftPerPx = math.max(
      bounds.rangeE * pad / math.max(size.width, 1),
      bounds.rangeN * pad / math.max(size.height, 1),
    );
    return _PlanMap(
      size: size,
      midE: bounds.midE,
      midN: bounds.midN,
      ftPerPx: math.max(ftPerPx, 0.01),
    );
  }

  Offset toPixel(double e, double n) {
    // Flutter Y grows downward; survey north is up.
    final x = size.width / 2 + (e - midE) / ftPerPx;
    final y = size.height / 2 - (n - midN) / ftPerPx;
    return Offset(x, y);
  }

  (double, double) toSurvey(Offset p) {
    final e = midE + (p.dx - size.width / 2) * ftPerPx;
    final n = midN - (p.dy - size.height / 2) * ftPerPx;
    return (e, n);
  }

  double feetToPixels(double ft) => ft / ftPerPx;
}

class _PlotPreviewPainter extends CustomPainter {
  _PlotPreviewPainter({
    required this.map,
    required this.points,
    required this.linework,
    required this.symbols,
    required this.options,
    required this.blockCatalog,
    required this.selectedSymbolId,
    required this.draggingId,
  });

  final _PlanMap map;
  final List<SurveyPoint> points;
  final List<LineworkEntity> linework;
  final List<PlacedPlotSymbol> symbols;
  final PlotOptions options;
  final BlockCatalog? blockCatalog;
  final String? selectedSymbolId;
  final String? draggingId;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas);
    _paintLinework(canvas);
    _paintSymbols(canvas);
    _paintPoints(canvas);
  }

  void _paintGrid(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFD9D2C5)
      ..strokeWidth = 0.8;
    final gridFt = math.max(map.ftPerPx * 40, 10.0);
    final bounds = computePlanViewBounds(
      points,
      linework: linework,
      symbols: symbols,
    );
    final startE = (bounds.minE / gridFt).floor() * gridFt - gridFt;
    final endE = (bounds.maxE / gridFt).ceil() * gridFt + gridFt;
    final startN = (bounds.minN / gridFt).floor() * gridFt - gridFt;
    final endN = (bounds.maxN / gridFt).ceil() * gridFt + gridFt;
    for (var e = startE; e <= endE + 0.001; e += gridFt) {
      final a = map.toPixel(e, startN);
      final b = map.toPixel(e, endN);
      canvas.drawLine(a, b, paint);
    }
    for (var n = startN; n <= endN + 0.001; n += gridFt) {
      final a = map.toPixel(startE, n);
      final b = map.toPixel(endE, n);
      canvas.drawLine(a, b, paint);
    }
  }

  void _paintLinework(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    for (final ent in linework) {
      final samples = [
        for (final p in ent.samplePoints)
          if (p[0].isFinite && p[1].isFinite) p,
      ];
      if (samples.length < 2) continue;
      final path = Path()
        ..moveTo(
          map.toPixel(samples.first[0], samples.first[1]).dx,
          map.toPixel(samples.first[0], samples.first[1]).dy,
        );
      for (var i = 1; i < samples.length; i++) {
        final o = map.toPixel(samples[i][0], samples[i][1]);
        path.lineTo(o.dx, o.dy);
      }
      if (ent.closed || ent.type == 'CIRCLE') path.close();
      canvas.drawPath(path, paint);
    }
  }

  void _paintPoints(Canvas canvas) {
    final color = const Color(0xFFE10600);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final p in points) {
      final c = map.toPixel(p.easting, p.northing);
      _drawMarker(canvas, c, options.markerStyle, fill, stroke);
      final lines = labelLinesFor(p, options.labelFormat);
      if (lines.isEmpty) continue;
      final tp = TextPainter(
        text: TextSpan(
          children: [
            for (var i = 0; i < lines.length; i++)
              TextSpan(
                text: '${lines[i]}${i == lines.length - 1 ? '' : '\n'}',
                style: const TextStyle(
                  color: Color(0xFFE10600),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
          ],
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx + 6, c.dy - tp.height / 2));
    }
  }

  void _drawMarker(
    Canvas canvas,
    Offset c,
    PointMarkerStyle style,
    Paint fill,
    Paint stroke,
  ) {
    switch (style) {
      case PointMarkerStyle.triangleFilled:
      case PointMarkerStyle.triangleOutline:
        final path = Path()
          ..moveTo(c.dx, c.dy - 6)
          ..lineTo(c.dx - 5, c.dy + 4)
          ..lineTo(c.dx + 5, c.dy + 4)
          ..close();
        if (style == PointMarkerStyle.triangleFilled) {
          canvas.drawPath(path, fill);
        }
        canvas.drawPath(path, stroke);
      case PointMarkerStyle.cross:
        canvas
          ..drawLine(Offset(c.dx - 5, c.dy), Offset(c.dx + 5, c.dy), stroke)
          ..drawLine(Offset(c.dx, c.dy - 5), Offset(c.dx, c.dy + 5), stroke);
      case PointMarkerStyle.x:
      case PointMarkerStyle.largeX:
        final s = style == PointMarkerStyle.largeX ? 7.0 : 4.5;
        canvas
          ..drawLine(Offset(c.dx - s, c.dy - s), Offset(c.dx + s, c.dy + s), stroke)
          ..drawLine(Offset(c.dx - s, c.dy + s), Offset(c.dx + s, c.dy - s), stroke);
      case PointMarkerStyle.circle:
        canvas.drawCircle(c, 4.2, stroke);
      case PointMarkerStyle.dot:
        canvas.drawCircle(c, 2.2, fill);
      case PointMarkerStyle.largeDot:
        canvas.drawCircle(c, 4.0, fill);
    }
  }

  void _paintSymbols(Canvas canvas) {
    for (final s in symbols) {
      final c = map.toPixel(s.easting, s.northing);
      final half = math.max(8.0, map.feetToPixels(s.sizeFt) / 2);
      final selected = s.id == selectedSymbolId || s.id == draggingId;
      final color = Color(s.colorArgb);

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(s.rotationDeg * math.pi / 180);
      canvas.translate(-half, -half);

      if (s.kind != null) {
        SymbolPreviewPainter(s.kind!, color: color)
            .paint(canvas, Size(half * 2, half * 2));
      } else if (s.blockId != null && blockCatalog != null) {
        final def = blockCatalog![s.blockId!];
        if (def != null) {
          BlockPreviewPainter(def, color: color)
              .paint(canvas, Size(half * 2, half * 2));
        } else {
          canvas.drawCircle(
            Offset(half, half),
            half * 0.6,
            Paint()..color = color,
          );
        }
      } else {
        canvas.drawCircle(
          Offset(half, half),
          half * 0.6,
          Paint()..color = color,
        );
      }
      canvas.restore();

      if (selected) {
        canvas.drawCircle(
          c,
          half + 4,
          Paint()
            ..color = const Color(0xFFE4572E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      final label = s.libraryLabel;
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx + half + 2, c.dy - 5));
    }
  }

  @override
  bool shouldRepaint(covariant _PlotPreviewPainter old) {
    return old.points != points ||
        old.linework != linework ||
        old.symbols != symbols ||
        old.options != options ||
        old.selectedSymbolId != selectedSymbolId ||
        old.draggingId != draggingId ||
        old.map.ftPerPx != map.ftPerPx;
  }
}
