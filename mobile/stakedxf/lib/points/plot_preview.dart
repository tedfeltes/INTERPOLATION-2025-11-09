import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'block_catalog.dart';
import 'dxf_linework.dart';
import 'label_placement.dart';
import 'linetype_catalog.dart';
import 'linework_draw.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_symbols.dart';
import 'survey_point.dart';
import 'symbol_preview.dart';

/// Live interactive plan preview — same framing as the exported PDF.
///
/// - Drag **labels** (Civil 3D drag state) — point markers stay fixed
/// - Drag **library objects** to set survey N/E
/// - Tap **linework** to select; nodes/segments for editing
/// - Point markers themselves cannot be moved
class PlotPreview extends StatefulWidget {
  const PlotPreview({
    super.key,
    required this.points,
    required this.options,
    this.linework = const [],
    this.symbols = const [],
    this.blockCatalog,
    this.linetypeCatalog,
    this.layerStyles = const {},
    this.selectedSymbolId,
    this.selectedLabelPointId,
    this.selectedLineworkId,
    this.selectedNodeIndex,
    this.selectedSegmentIndex,
    this.onSelectSymbol,
    this.onSelectLabelPoint,
    this.onSelectLinework,
    this.onSelectNode,
    this.onSelectSegment,
    this.onMoveSymbol,
    this.onMoveLabel,
    this.height = 280,
  });

  final List<SurveyPoint> points;
  final PlotOptions options;
  final List<LineworkEntity> linework;
  final List<PlacedPlotSymbol> symbols;
  final BlockCatalog? blockCatalog;
  final LinetypeCatalog? linetypeCatalog;
  final Map<String, DxfLayerStyle> layerStyles;
  final String? selectedSymbolId;
  final String? selectedLabelPointId;
  final String? selectedLineworkId;
  final int? selectedNodeIndex;
  final int? selectedSegmentIndex;
  final ValueChanged<String?>? onSelectSymbol;
  final ValueChanged<String?>? onSelectLabelPoint;
  final ValueChanged<String?>? onSelectLinework;
  final ValueChanged<int?>? onSelectNode;
  final ValueChanged<int?>? onSelectSegment;
  final void Function(String id, double easting, double northing)? onMoveSymbol;
  final void Function(String pointId, double offsetE, double offsetN)?
      onMoveLabel;
  final double height;

  @override
  State<PlotPreview> createState() => _PlotPreviewState();
}

enum _DragKind { none, symbol, label }

class _PlotPreviewState extends State<PlotPreview> {
  _DragKind _dragKind = _DragKind.none;
  String? _draggingId;
  _PlanMap? _map;

  Map<String, LabelDragState> get _drags {
    if (!widget.options.autoSpreadLabels ||
        widget.options.labelFormat == PointLabelFormat.none) {
      return widget.options.labelDrags;
    }
    final scale = chooseEngineeringScale(
      widget.points,
      linework: widget.linework,
      symbols: widget.symbols,
      template: widget.options.template,
      showPointList: widget.options.showPointList,
    );
    return autoSpreadLabels(
      points: widget.points,
      format: widget.options.labelFormat,
      scaleFtPerInch: scale,
      existing: widget.options.labelDrags,
      annotationScale: widget.options.annotationScale,
    );
  }

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

    final drags = _drags;

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
            Flexible(
              child: Text(
                'Drag labels · objects · tap linework to edit',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.55),
                ),
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
                    onTapUp: (d) => _handleTap(d.localPosition, drags),
                    onPanStart: (d) => _handlePanStart(d.localPosition, drags),
                    onPanUpdate: (d) => _handlePanUpdate(d.localPosition),
                    onPanEnd: (_) {
                      _dragKind = _DragKind.none;
                      _draggingId = null;
                    },
                    child: CustomPaint(
                      size: size,
                      painter: _PlotPreviewPainter(
                        map: _map!,
                        points: widget.points,
                        linework: widget.linework,
                        symbols: widget.symbols,
                        options: widget.options,
                        blockCatalog: widget.blockCatalog,
                        linetypeCatalog:
                            widget.linetypeCatalog ?? LinetypeCatalog.builtin(),
                        layerStyles: widget.layerStyles,
                        selectedSymbolId: widget.selectedSymbolId,
                        selectedLabelPointId: widget.selectedLabelPointId,
                        selectedLineworkId: widget.selectedLineworkId,
                        selectedNodeIndex: widget.selectedNodeIndex,
                        selectedSegmentIndex: widget.selectedSegmentIndex,
                        draggingId: _draggingId,
                        dragKind: _dragKind,
                        labelDrags: drags,
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

  void _handleTap(Offset local, Map<String, LabelDragState> drags) {
    final map = _map;
    if (map == null) return;
    final labelHit = _hitLabel(local, map, drags);
    if (labelHit != null) {
      widget.onSelectLabelPoint?.call(labelHit);
      widget.onSelectSymbol?.call(null);
      widget.onSelectLinework?.call(null);
      return;
    }
    final sym = _hitSymbol(local, map);
    if (sym != null) {
      widget.onSelectSymbol?.call(sym.id);
      widget.onSelectLabelPoint?.call(null);
      widget.onSelectLinework?.call(null);
      return;
    }

    // Prefer node/segment hits on the currently selected entity.
    final selId = widget.selectedLineworkId;
    if (selId != null) {
      LineworkEntity? sel;
      for (final e in widget.linework) {
        if (e.id == selId) {
          sel = e;
          break;
        }
      }
      if (sel != null) {
        final node = hitTestNode(local, sel, map.toPixel);
        if (node != null) {
          widget.onSelectNode?.call(node);
          widget.onSelectSegment?.call(null);
          return;
        }
        final seg = hitTestSegment(local, sel, map.toPixel);
        if (seg != null) {
          widget.onSelectSegment?.call(seg);
          widget.onSelectNode?.call(null);
          return;
        }
      }
    }

    final lw = hitTestLinework(local, widget.linework, map.toPixel);
    widget.onSelectLinework?.call(lw);
    widget.onSelectSymbol?.call(null);
    widget.onSelectLabelPoint?.call(null);
    if (lw == null) {
      widget.onSelectNode?.call(null);
      widget.onSelectSegment?.call(null);
    }
  }

  void _handlePanStart(Offset local, Map<String, LabelDragState> drags) {
    final map = _map;
    if (map == null) return;
    final labelHit = _hitLabel(local, map, drags);
    if (labelHit != null) {
      _dragKind = _DragKind.label;
      _draggingId = labelHit;
      widget.onSelectLabelPoint?.call(labelHit);
      widget.onSelectSymbol?.call(null);
      return;
    }
    final sym = _hitSymbol(local, map);
    if (sym != null) {
      _dragKind = _DragKind.symbol;
      _draggingId = sym.id;
      widget.onSelectSymbol?.call(sym.id);
      widget.onSelectLabelPoint?.call(null);
      return;
    }
    _dragKind = _DragKind.none;
    _draggingId = null;
  }

  void _handlePanUpdate(Offset local) {
    final map = _map;
    final id = _draggingId;
    if (map == null || id == null) return;
    if (_dragKind == _DragKind.symbol) {
      final en = map.toSurvey(local);
      widget.onMoveSymbol?.call(id, en.$1, en.$2);
      return;
    }
    if (_dragKind == _DragKind.label) {
      SurveyPoint? pt;
      for (final p in widget.points) {
        if (p.id == id) {
          pt = p;
          break;
        }
      }
      if (pt == null) return;
      final en = map.toSurvey(local);
      widget.onMoveLabel?.call(id, en.$1 - pt.easting, en.$2 - pt.northing);
    }
  }

  String? _hitLabel(
    Offset local,
    _PlanMap map,
    Map<String, LabelDragState> drags,
  ) {
    if (widget.options.labelFormat == PointLabelFormat.none) return null;
    String? best;
    var bestDist = 36.0;
    for (final p in widget.points) {
      final drag = drags[p.id];
      final lines = resolvedLabelLines(p, widget.options.labelFormat, drag);
      if (lines.isEmpty) continue;
      final oE = drag?.offsetE ?? 14.0;
      final oN = drag?.offsetN ?? 10.0;
      final c = map.toPixel(p.easting + oE, p.northing + oN);
      final d = (c - local).distance;
      if (d < bestDist) {
        bestDist = d;
        best = p.id;
      }
    }
    return best;
  }

  PlacedPlotSymbol? _hitSymbol(Offset local, _PlanMap map) {
    PlacedPlotSymbol? best;
    var bestDist = 28.0;
    final ann = widget.options.annotationScale.clamp(0.6, 3.0);
    for (final s in widget.symbols) {
      final c = map.toPixel(s.easting, s.northing);
      final d = (c - local).distance;
      final half = math.max(12.0, 22.0 * s.scale * ann);
      if (d <= half + 8 && d < bestDist + half) {
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
    final x = size.width / 2 + (e - midE) / ftPerPx;
    final y = size.height / 2 - (n - midN) / ftPerPx;
    return Offset(x, y);
  }

  (double, double) toSurvey(Offset p) {
    final e = midE + (p.dx - size.width / 2) * ftPerPx;
    final n = midN - (p.dy - size.height / 2) * ftPerPx;
    return (e, n);
  }
}

class _PlotPreviewPainter extends CustomPainter {
  _PlotPreviewPainter({
    required this.map,
    required this.points,
    required this.linework,
    required this.symbols,
    required this.options,
    required this.blockCatalog,
    required this.linetypeCatalog,
    required this.layerStyles,
    required this.selectedSymbolId,
    required this.selectedLabelPointId,
    required this.selectedLineworkId,
    required this.selectedNodeIndex,
    required this.selectedSegmentIndex,
    required this.draggingId,
    required this.dragKind,
    required this.labelDrags,
  });

  final _PlanMap map;
  final List<SurveyPoint> points;
  final List<LineworkEntity> linework;
  final List<PlacedPlotSymbol> symbols;
  final PlotOptions options;
  final BlockCatalog? blockCatalog;
  final LinetypeCatalog linetypeCatalog;
  final Map<String, DxfLayerStyle> layerStyles;
  final String? selectedSymbolId;
  final String? selectedLabelPointId;
  final String? selectedLineworkId;
  final int? selectedNodeIndex;
  final int? selectedSegmentIndex;
  final String? draggingId;
  final _DragKind dragKind;
  final Map<String, LabelDragState> labelDrags;

  @override
  void paint(Canvas canvas, Size size) {
    _paintGrid(canvas);
    _paintLinework(canvas);
    _paintSymbols(canvas);
    _paintPointsAndLabels(canvas);
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
      canvas.drawLine(
        map.toPixel(e, startN),
        map.toPixel(e, endN),
        paint,
      );
    }
    for (var n = startN; n <= endN + 0.001; n += gridFt) {
      canvas.drawLine(
        map.toPixel(startE, n),
        map.toPixel(endE, n),
        paint,
      );
    }
  }

  void _paintLinework(Canvas canvas) {
    paintLineworkFlutter(
      canvas: canvas,
      linework: linework,
      toPixel: map.toPixel,
      catalog: linetypeCatalog,
      layerStyles: layerStyles,
      layerOverrides: options.layerStyleOverrides,
      entityOverrides: options.entityStyleOverrides,
      globalLinetypeScale: options.globalLinetypeScale,
      selectedId: selectedLineworkId,
      selectedSegmentIndex: selectedSegmentIndex,
      selectedNodeIndex: selectedNodeIndex,
    );
  }

  void _paintPointsAndLabels(Canvas canvas) {
    final color = const Color(0xFFE10600);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * options.annotationScale.clamp(0.6, 3.0);
    final leader = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final ann = options.annotationScale.clamp(0.6, 3.0);
    final fontSize = (10.0 * ann).clamp(8.0, 16.0);

    for (final p in points) {
      final c = map.toPixel(p.easting, p.northing);
      _drawMarker(canvas, c, options.markerStyle, fill, stroke, ann);

      final drag = labelDrags[p.id];
      final lines = resolvedLabelLines(p, options.labelFormat, drag);
      if (lines.isEmpty) continue;
      final oE = drag?.offsetE ?? 14.0;
      final oN = drag?.offsetN ?? 10.0;
      final labelPos = map.toPixel(p.easting + oE, p.northing + oN);
      final dragged = (drag?.isDragged ?? false) ||
          math.sqrt(oE * oE + oN * oN) > 8;
      if (dragged) {
        canvas.drawLine(c, labelPos, leader);
      }

      final selected = p.id == selectedLabelPointId ||
          (dragKind == _DragKind.label && p.id == draggingId);
      final tp = TextPainter(
        text: TextSpan(
          text: lines.join('\n'),
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.15,
            backgroundColor: selected
                ? const Color(0x66FFE082)
                : const Color(0x88F7F4EE),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(labelPos.dx, labelPos.dy - tp.height / 2));
      if (selected) {
        canvas.drawRect(
          Rect.fromLTWH(
            labelPos.dx - 2,
            labelPos.dy - tp.height / 2 - 2,
            tp.width + 4,
            tp.height + 4,
          ),
          Paint()
            ..color = const Color(0xFFE4572E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _drawMarker(
    Canvas canvas,
    Offset c,
    PointMarkerStyle style,
    Paint fill,
    Paint stroke,
    double k,
  ) {
    switch (style) {
      case PointMarkerStyle.triangleFilled:
      case PointMarkerStyle.triangleOutline:
        final path = Path()
          ..moveTo(c.dx, c.dy - 6 * k)
          ..lineTo(c.dx - 5 * k, c.dy + 4 * k)
          ..lineTo(c.dx + 5 * k, c.dy + 4 * k)
          ..close();
        if (style == PointMarkerStyle.triangleFilled) {
          canvas.drawPath(path, fill);
        }
        canvas.drawPath(path, stroke);
      case PointMarkerStyle.cross:
        canvas
          ..drawLine(
            Offset(c.dx - 5 * k, c.dy),
            Offset(c.dx + 5 * k, c.dy),
            stroke,
          )
          ..drawLine(
            Offset(c.dx, c.dy - 5 * k),
            Offset(c.dx, c.dy + 5 * k),
            stroke,
          );
      case PointMarkerStyle.x:
      case PointMarkerStyle.largeX:
        final arm = (style == PointMarkerStyle.largeX ? 7.0 : 4.5) * k;
        canvas
          ..drawLine(
            Offset(c.dx - arm, c.dy - arm),
            Offset(c.dx + arm, c.dy + arm),
            stroke,
          )
          ..drawLine(
            Offset(c.dx - arm, c.dy + arm),
            Offset(c.dx + arm, c.dy - arm),
            stroke,
          );
      case PointMarkerStyle.circle:
        canvas.drawCircle(c, 4.2 * k, stroke);
      case PointMarkerStyle.dot:
        canvas.drawCircle(c, 2.2 * k, fill);
      case PointMarkerStyle.largeDot:
        canvas.drawCircle(c, 4.0 * k, fill);
    }
  }

  void _paintSymbols(Canvas canvas) {
    final ann = options.annotationScale.clamp(0.6, 3.0);
    for (final s in symbols) {
      final c = map.toPixel(s.easting, s.northing);
      // Paper-based size on preview (not ground feet × scale).
      final half = math.max(10.0, 22.0 * s.scale * ann);
      final selected = s.id == selectedSymbolId ||
          (dragKind == _DragKind.symbol && s.id == draggingId);
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
            half * 0.55,
            Paint()..color = color,
          );
        }
      } else {
        canvas.drawCircle(
          Offset(half, half),
          half * 0.55,
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

      if (options.showObjectLabels) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.libraryLabel,
            style: TextStyle(
              color: color,
              fontSize: 9 * ann,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c.dx + half + 2, c.dy - 5));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PlotPreviewPainter old) {
    return old.points != points ||
        old.linework != linework ||
        old.symbols != symbols ||
        old.options != options ||
        old.selectedSymbolId != selectedSymbolId ||
        old.selectedLabelPointId != selectedLabelPointId ||
        old.selectedLineworkId != selectedLineworkId ||
        old.selectedNodeIndex != selectedNodeIndex ||
        old.selectedSegmentIndex != selectedSegmentIndex ||
        old.draggingId != draggingId ||
        old.dragKind != dragKind ||
        old.labelDrags != labelDrags ||
        old.layerStyles != layerStyles;
  }
}
