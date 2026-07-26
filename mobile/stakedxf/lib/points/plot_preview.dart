import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'block_catalog.dart';
import 'dxf_linework.dart';
import 'label_placement.dart';
import 'leader_geometry.dart';
import 'linetype_catalog.dart';
import 'linework_draw.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_symbols.dart';
import 'plot_templates.dart';
import 'survey_point.dart';
import 'symbol_preview.dart';

/// ACI 10 — stake points and labels.
const kPointLabelColor = Color(0xFFFF0000);

/// Live interactive plan preview framed to the selected sheet template.
///
/// - Drag **labels** locally (smooth) — point markers stay fixed
/// - Dogleg leaders attach to label edges (never through text)
/// - Sheet boundary shows the real plot size
/// - Library objects do not change framing extents
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
    this.lineEditMode = false,
    this.onSelectSymbol,
    this.onSelectLabelPoint,
    this.onSelectLinework,
    this.onSelectNode,
    this.onSelectSegment,
    this.onMoveSymbol,
    this.onMoveLabel,
    this.height,
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
  final bool lineEditMode;
  final ValueChanged<String?>? onSelectSymbol;
  final ValueChanged<String?>? onSelectLabelPoint;
  final ValueChanged<String?>? onSelectLinework;
  final ValueChanged<int?>? onSelectNode;
  final ValueChanged<int?>? onSelectSegment;
  final void Function(String id, double easting, double northing)? onMoveSymbol;
  final void Function(String pointId, double offsetE, double offsetN)?
      onMoveLabel;
  /// When null, height follows the selected sheet aspect ratio.
  final double? height;

  @override
  State<PlotPreview> createState() => _PlotPreviewState();
}

enum _DragKind { none, symbol, label }

class _PlotPreviewState extends State<PlotPreview> {
  _DragKind _dragKind = _DragKind.none;
  String? _draggingId;
  _PlanMap? _map;

  /// Local drag overlay — avoids rebuilding the whole Export screen each frame.
  final Map<String, LabelDragState> _liveLabelDrags = {};
  double? _liveSymE;
  double? _liveSymN;

  Map<String, LabelDragState>? _cachedDrags;
  Object? _dragCacheKey;

  Map<String, LabelDragState> get _baseDrags {
    final key = Object.hash(
      widget.points.length,
      widget.options.labelFormat,
      widget.options.autoSpreadLabels,
      widget.options.annotationScale,
      widget.options.template.id,
      widget.options.showPointList,
      widget.options.labelDrags,
      widget.linework.length,
    );
    if (_cachedDrags != null && _dragCacheKey == key) {
      return _cachedDrags!;
    }
    _dragCacheKey = key;
    if (!widget.options.autoSpreadLabels ||
        widget.options.labelFormat == PointLabelFormat.none) {
      _cachedDrags = widget.options.labelDrags;
      return _cachedDrags!;
    }
    final scale = chooseEngineeringScale(
      widget.points,
      linework: widget.linework,
      template: widget.options.template,
      showPointList: widget.options.showPointList,
    );
    _cachedDrags = autoSpreadLabels(
      points: widget.points,
      format: widget.options.labelFormat,
      scaleFtPerInch: scale,
      existing: widget.options.labelDrags,
      annotationScale: widget.options.annotationScale,
    );
    return _cachedDrags!;
  }

  Map<String, LabelDragState> get _drags {
    if (_liveLabelDrags.isEmpty) return _baseDrags;
    return {..._baseDrags, ..._liveLabelDrags};
  }

  double _previewHeight(double maxWidth) {
    if (widget.height != null) return widget.height!;
    final t = widget.options.template;
    final aspect = t.heightIn / math.max(t.widthIn, 0.1);
    // Large usable preview; clamp for small phones / tall sheets.
    return (maxWidth * aspect).clamp(280.0, 520.0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (widget.points.isEmpty) {
      return Container(
        height: widget.height ?? 320,
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
    final tpl = widget.options.template;
    final scale = chooseEngineeringScale(
      widget.points,
      linework: widget.linework,
      template: tpl,
      showPointList: widget.options.showPointList,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = _previewHeight(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Plot preview',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${tpl.sizeCallout} · 1"=${scale.round()}\' · '
                    '${widget.lineEditMode ? 'Line edit ON — tap segment/node' : 'Drag labels (points fixed)'}',
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
              height: h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: ColoredBox(
                  color: const Color(0xFFE8E4DC),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final size = Size(c.maxWidth, c.maxHeight);
                      _map = _PlanMap.fromSheet(
                        size: size,
                        points: widget.points,
                        linework: widget.linework,
                        template: tpl,
                        showPointList: widget.options.showPointList,
                        scaleFtPerInch: scale,
                      );
                      return GestureDetector(
                        onTapUp: (d) => _handleTap(d.localPosition, drags),
                        onPanStart: (d) =>
                            _handlePanStart(d.localPosition, drags),
                        onPanUpdate: (d) => _handlePanUpdate(d.localPosition),
                        onPanEnd: (_) => _commitDrag(),
                        onPanCancel: _commitDrag,
                        child: RepaintBoundary(
                          child: CustomPaint(
                            size: size,
                            painter: _PlotPreviewPainter(
                              map: _map!,
                              points: widget.points,
                              linework: widget.linework,
                              symbols: _symbolsForPaint(),
                              options: widget.options,
                              blockCatalog: widget.blockCatalog,
                              linetypeCatalog: widget.linetypeCatalog ??
                                  LinetypeCatalog.builtin(),
                              layerStyles: widget.layerStyles,
                              selectedSymbolId: widget.selectedSymbolId,
                              selectedLabelPointId:
                                  widget.selectedLabelPointId,
                              selectedLineworkId: widget.selectedLineworkId,
                              selectedNodeIndex: widget.selectedNodeIndex,
                              selectedSegmentIndex:
                                  widget.selectedSegmentIndex,
                              draggingId: _draggingId,
                              dragKind: _dragKind,
                              labelDrags: drags,
                              sheetLabel:
                                  '${tpl.name} · ${tpl.sizeCallout}',
                              lineEditMode: widget.lineEditMode,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<PlacedPlotSymbol> _symbolsForPaint() {
    if (_dragKind != _DragKind.symbol ||
        _draggingId == null ||
        _liveSymE == null ||
        _liveSymN == null) {
      return widget.symbols;
    }
    return [
      for (final s in widget.symbols)
        if (s.id == _draggingId)
          s.copyWith(easting: _liveSymE, northing: _liveSymN)
        else
          s,
    ];
  }

  void _commitDrag() {
    final id = _draggingId;
    final kind = _dragKind;
    if (kind == _DragKind.label && id != null) {
      final d = _liveLabelDrags[id];
      if (d != null) {
        widget.onMoveLabel?.call(id, d.offsetE, d.offsetN);
      }
    } else if (kind == _DragKind.symbol &&
        id != null &&
        _liveSymE != null &&
        _liveSymN != null) {
      widget.onMoveSymbol?.call(id, _liveSymE!, _liveSymN!);
    }
    setState(() {
      _dragKind = _DragKind.none;
      _draggingId = null;
      _liveLabelDrags.clear();
      _liveSymE = null;
      _liveSymN = null;
    });
  }

  void _handleTap(Offset local, Map<String, LabelDragState> drags) {
    final map = _map;
    if (map == null) return;

    if (widget.lineEditMode) {
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
          final node = hitTestNode(local, sel, map.toPixel, threshold: 22);
          if (node != null) {
            widget.onSelectNode?.call(node);
            widget.onSelectSegment?.call(null);
            return;
          }
          final seg = hitTestSegment(local, sel, map.toPixel, threshold: 22);
          if (seg != null) {
            widget.onSelectSegment?.call(seg);
            widget.onSelectNode?.call(null);
            return;
          }
        }
      }
      final lw = hitTestLinework(
        local,
        widget.linework,
        map.toPixel,
        threshold: 18,
      );
      widget.onSelectLinework?.call(lw);
      widget.onSelectSymbol?.call(null);
      widget.onSelectLabelPoint?.call(null);
      if (lw == null) {
        widget.onSelectNode?.call(null);
        widget.onSelectSegment?.call(null);
      }
      return;
    }

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
    widget.onSelectLabelPoint?.call(null);
    widget.onSelectSymbol?.call(null);
    widget.onSelectLinework?.call(null);
  }

  void _handlePanStart(Offset local, Map<String, LabelDragState> drags) {
    if (widget.lineEditMode) return;
    final map = _map;
    if (map == null) return;
    final labelHit = _hitLabel(local, map, drags);
    if (labelHit != null) {
      setState(() {
        _dragKind = _DragKind.label;
        _draggingId = labelHit;
      });
      widget.onSelectLabelPoint?.call(labelHit);
      widget.onSelectSymbol?.call(null);
      return;
    }
    final sym = _hitSymbol(local, map);
    if (sym != null) {
      setState(() {
        _dragKind = _DragKind.symbol;
        _draggingId = sym.id;
        _liveSymE = sym.easting;
        _liveSymN = sym.northing;
      });
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
    // Clamp to sheet plan area so objects stay on the plotted sheet.
    final clamped = Offset(
      local.dx.clamp(map.planRect.left, map.planRect.right),
      local.dy.clamp(map.planRect.top, map.planRect.bottom),
    );
    if (_dragKind == _DragKind.symbol) {
      final en = map.toSurvey(clamped);
      setState(() {
        _liveSymE = en.$1;
        _liveSymN = en.$2;
      });
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
      final en = map.toSurvey(clamped);
      final prev = _baseDrags[id];
      setState(() {
        _liveLabelDrags[id] = LabelDragState(
          offsetE: en.$1 - pt!.easting,
          offsetN: en.$2 - pt.northing,
          customText: prev?.customText,
          pinned: true,
        );
      });
    }
  }

  String? _hitLabel(
    Offset local,
    _PlanMap map,
    Map<String, LabelDragState> drags,
  ) {
    if (widget.options.labelFormat == PointLabelFormat.none) return null;
    String? best;
    var bestDist = 40.0;
    final ann = widget.options.annotationScale.clamp(0.6, 3.0);
    final fontSize = (10.0 * ann).clamp(8.0, 16.0);
    for (final p in widget.points) {
      final drag = drags[p.id];
      final lines = resolvedLabelLines(p, widget.options.labelFormat, drag);
      if (lines.isEmpty) continue;
      final oE = drag?.offsetE ?? 14.0;
      final oN = drag?.offsetN ?? 10.0;
      final anchor = map.toPixel(p.easting + oE, p.northing + oN);
      final w = math.max(
        28.0,
        lines.fold<int>(0, (m, l) => math.max(m, l.length)) * fontSize * 0.55,
      );
      final h = fontSize * 1.2 * lines.length;
      final rect = Rect.fromCenter(center: anchor, width: w, height: h);
      if (rect.inflate(6).contains(local)) {
        final d = (anchor - local).distance;
        if (d < bestDist) {
          bestDist = d;
          best = p.id;
        }
      }
    }
    return best;
  }

  PlacedPlotSymbol? _hitSymbol(Offset local, _PlanMap map) {
    PlacedPlotSymbol? best;
    var bestDist = 32.0;
    final ann = widget.options.annotationScale.clamp(0.6, 3.0);
    for (final s in widget.symbols) {
      final c = map.toPixel(s.easting, s.northing);
      final d = (c - local).distance;
      final half = math.max(14.0, 24.0 * s.scale * ann);
      if (d <= half + 10 && d < bestDist + half) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }
}

/// Maps survey ↔ pixel with an explicit sheet / plan viewport.
class _PlanMap {
  _PlanMap({
    required this.size,
    required this.sheetRect,
    required this.planRect,
    required this.midE,
    required this.midN,
    required this.ftPerPx,
  });

  final Size size;
  final Rect sheetRect;
  final Rect planRect;
  final double midE;
  final double midN;
  final double ftPerPx;

  factory _PlanMap.fromSheet({
    required Size size,
    required List<SurveyPoint> points,
    required List<LineworkEntity> linework,
    required PlotTemplate template,
    required bool showPointList,
    required double scaleFtPerInch,
  }) {
    // Fit sheet aspect into the widget with a small margin.
    final sheetAspect = template.widthIn / template.heightIn;
    late Rect sheet;
    if (size.width / size.height > sheetAspect) {
      final h = size.height * 0.96;
      final w = h * sheetAspect;
      sheet = Rect.fromLTWH((size.width - w) / 2, size.height * 0.02, w, h);
    } else {
      final w = size.width * 0.96;
      final h = w / sheetAspect;
      sheet = Rect.fromLTWH(size.width * 0.02, (size.height - h) / 2, w, h);
    }

    // Plan viewport inset (matches field-map margin feeling).
    final inset = math.min(sheet.width, sheet.height) * 0.06;
    final plan = Rect.fromLTRB(
      sheet.left + inset,
      sheet.top + inset,
      sheet.right - inset,
      sheet.bottom - inset * 1.35, // room for sheet callout
    );

    final bounds = computePlanViewBounds(
      points,
      linework: linework,
      includeSymbols: false,
    );
    final pad = 1.15;
    final ftPerPx = math.max(
      bounds.rangeE * pad / math.max(plan.width, 1),
      bounds.rangeN * pad / math.max(plan.height, 1),
    );
    return _PlanMap(
      size: size,
      sheetRect: sheet,
      planRect: plan,
      midE: bounds.midE,
      midN: bounds.midN,
      ftPerPx: math.max(ftPerPx, 0.01),
    );
  }

  Offset toPixel(double e, double n) {
    final x = planRect.center.dx + (e - midE) / ftPerPx;
    final y = planRect.center.dy - (n - midN) / ftPerPx;
    return Offset(x, y);
  }

  (double, double) toSurvey(Offset p) {
    final e = midE + (p.dx - planRect.center.dx) * ftPerPx;
    final n = midN - (p.dy - planRect.center.dy) * ftPerPx;
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
    required this.sheetLabel,
    required this.lineEditMode,
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
  final String sheetLabel;
  final bool lineEditMode;

  @override
  void paint(Canvas canvas, Size size) {
    _paintSheet(canvas);
    canvas.save();
    canvas.clipRect(map.planRect);
    _paintPlanBackground(canvas);
    _paintGrid(canvas);
    _paintLinework(canvas);
    _paintSymbols(canvas);
    _paintPointsAndLabels(canvas);
    canvas.restore();
    _paintSheetFrame(canvas);
  }

  void _paintSheet(Canvas canvas) {
    canvas.drawRect(map.sheetRect, Paint()..color = Colors.white);
  }

  void _paintPlanBackground(Canvas canvas) {
    canvas.drawRect(map.planRect, Paint()..color = const Color(0xFFF7F4EE));
  }

  void _paintSheetFrame(Canvas canvas) {
    canvas.drawRect(
      map.sheetRect,
      Paint()
        ..color = const Color(0xFF333333)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawRect(
      map.planRect,
      Paint()
        ..color = const Color(0xFF8A8478)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: sheetLabel,
        style: const TextStyle(
          color: Color(0xFF444444),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: map.sheetRect.width - 8);
    tp.paint(
      canvas,
      Offset(
        map.sheetRect.left + 6,
        map.sheetRect.bottom - tp.height - 4,
      ),
    );
  }

  void _paintGrid(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFFD9D2C5)
      ..strokeWidth = 0.8;
    final gridFt = math.max(map.ftPerPx * 40, 10.0);
    final bounds = computePlanViewBounds(
      points,
      linework: linework,
      includeSymbols: false,
    );
    final startE = (bounds.minE / gridFt).floor() * gridFt - gridFt;
    final endE = (bounds.maxE / gridFt).ceil() * gridFt + gridFt;
    final startN = (bounds.minN / gridFt).floor() * gridFt - gridFt;
    final endN = (bounds.maxN / gridFt).ceil() * gridFt + gridFt;
    for (var e = startE; e <= endE + 0.001; e += gridFt) {
      canvas.drawLine(map.toPixel(e, startN), map.toPixel(e, endN), paint);
    }
    for (var n = startN; n <= endN + 0.001; n += gridFt) {
      canvas.drawLine(map.toPixel(startE, n), map.toPixel(endE, n), paint);
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
      selectedId: lineEditMode ? selectedLineworkId : null,
      selectedSegmentIndex: lineEditMode ? selectedSegmentIndex : null,
      selectedNodeIndex: lineEditMode ? selectedNodeIndex : null,
      showNodesForSelected: lineEditMode,
    );
  }

  void _paintPointsAndLabels(Canvas canvas) {
    final color = kPointLabelColor;
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * options.annotationScale.clamp(0.6, 3.0);
    final leader = Paint()
      ..color = color
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
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
      final anchor = map.toPixel(p.easting + oE, p.northing + oN);

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
                : const Color(0xCCF7F4EE),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      final g = buildLeader(
        point: c,
        labelAnchor: anchor,
        labelWidth: tp.width + 4,
        labelHeight: tp.height + 2,
        landingLength: math.max(10.0, fontSize),
      );

      final dragged =
          (drag?.isDragged ?? false) || math.sqrt(oE * oE + oN * oN) > 8;
      if (dragged) {
        final path = Path()
          ..moveTo(g.point.dx, g.point.dy)
          ..lineTo(g.elbow.dx, g.elbow.dy)
          ..lineTo(g.landing.dx, g.landing.dy);
        canvas.drawPath(path, leader);
      }

      tp.paint(canvas, g.labelOrigin);
      if (selected) {
        canvas.drawRect(
          g.labelRect.inflate(2),
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
        old.lineEditMode != lineEditMode ||
        old.sheetLabel != sheetLabel;
  }
}
