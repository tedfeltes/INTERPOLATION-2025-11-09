import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'block_catalog.dart';
import 'ctb_plot_style.dart';
import 'dxf_linework.dart';
import 'label_placement.dart';
import 'leader_geometry.dart';
import 'linetype_catalog.dart';
import 'linework_draw.dart';
import 'hatch_paint.dart';
import 'plot_annotations.dart';
import 'plot_options.dart';
import 'plot_pdf.dart';
import 'plot_symbols.dart';
import 'plot_templates.dart';
import 'plot_ui_theme.dart';
import 'survey_point.dart';
import 'symbol_preview.dart';
import 'text_style_catalog.dart';

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
    this.ctbPlotStyle,
    this.layerStyles = const {},
    this.selectedSymbolId,
    this.selectedLabelPointId,
    this.selectedLineworkId,
    this.selectedLineworkLayer,
    this.selectedTextId,
    this.selectedNodeIndex,
    this.selectedSegmentIndex,
    this.lineEditMode = false,
    this.textObjects = const [],
    this.textStyleCatalog,
    this.onSelectSymbol,
    this.onSelectLabelPoint,
    this.onSelectLinework,
    this.onSelectText,
    this.onSelectNode,
    this.onSelectSegment,
    this.onMoveSymbol,
    this.onMoveLabel,
    this.onMoveText,
    this.height,
  });

  final List<SurveyPoint> points;
  final PlotOptions options;
  final List<LineworkEntity> linework;
  final List<PlacedPlotSymbol> symbols;
  final BlockCatalog? blockCatalog;
  final LinetypeCatalog? linetypeCatalog;
  final CtbPlotStyleTable? ctbPlotStyle;
  final Map<String, DxfLayerStyle> layerStyles;
  final String? selectedSymbolId;
  final String? selectedLabelPointId;
  final String? selectedLineworkId;
  final String? selectedLineworkLayer;
  final String? selectedTextId;
  final int? selectedNodeIndex;
  final int? selectedSegmentIndex;
  final bool lineEditMode;
  final List<PlotTextObject> textObjects;
  final TextStyleCatalog? textStyleCatalog;
  final ValueChanged<String?>? onSelectSymbol;
  final ValueChanged<String?>? onSelectLabelPoint;
  final ValueChanged<String?>? onSelectLinework;
  final ValueChanged<String?>? onSelectText;
  final ValueChanged<int?>? onSelectNode;
  final ValueChanged<int?>? onSelectSegment;
  final void Function(String id, double easting, double northing)? onMoveSymbol;
  final void Function(String pointId, double offsetE, double offsetN)?
      onMoveLabel;
  final void Function(String id, double easting, double northing)? onMoveText;
  /// When null, height follows the selected sheet aspect ratio.
  final double? height;

  @override
  State<PlotPreview> createState() => _PlotPreviewState();
}

enum _DragKind { none, symbol, label, text }

class _PlotPreviewState extends State<PlotPreview> {
  _DragKind _dragKind = _DragKind.none;
  String? _draggingId;
  _PlanMap? _map;

  /// Local drag overlay — avoids rebuilding the whole Export screen each frame.
  final Map<String, LabelDragState> _liveLabelDrags = {};
  double? _liveSymE;
  double? _liveSymN;
  double? _liveTextE;
  double? _liveTextN;

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
      overrideFtPerInch: widget.options.scaleFtPerInch,
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
          color: PlotUi.muted,
          border: Border.all(color: cs.outline.withValues(alpha: 0.8)),
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
      overrideFtPerInch: widget.options.scaleFtPerInch,
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
                              ctbPlotStyle: widget.ctbPlotStyle ??
                                  CtbPlotStyleTable.builtin(),
                              textStyleCatalog: widget.textStyleCatalog ??
                                  TextStyleCatalog.builtin(),
                              layerStyles: widget.layerStyles,
                              selectedSymbolId: widget.selectedSymbolId,
                              selectedLabelPointId:
                                  widget.selectedLabelPointId,
                              selectedLineworkId: widget.selectedLineworkId,
                              selectedLineworkLayer:
                                  widget.selectedLineworkLayer,
                              selectedTextId: widget.selectedTextId,
                              selectedNodeIndex: widget.selectedNodeIndex,
                              selectedSegmentIndex:
                                  widget.selectedSegmentIndex,
                              draggingId: _draggingId,
                              dragKind: _dragKind,
                              labelDrags: drags,
                              textObjects: _textObjectsForPaint(),
                              sheetLabel:
                                  '${tpl.size.pickerLabel} · ${tpl.orientation.label}',
                              lineEditMode: widget.lineEditMode,
                            ),
                          ),
                        ),
                      );
                    },
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

  List<PlotTextObject> _textObjectsForPaint() {
    if (_dragKind != _DragKind.text ||
        _draggingId == null ||
        _liveTextE == null ||
        _liveTextN == null) {
      return widget.textObjects;
    }
    return [
      for (final t in widget.textObjects)
        if (t.id == _draggingId)
          t.copyWith(easting: _liveTextE, northing: _liveTextN)
        else
          t,
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
    } else if (kind == _DragKind.text &&
        id != null &&
        _liveTextE != null &&
        _liveTextN != null) {
      widget.onMoveText?.call(id, _liveTextE!, _liveTextN!);
    }
    setState(() {
      _dragKind = _DragKind.none;
      _draggingId = null;
      _liveLabelDrags.clear();
      _liveSymE = null;
      _liveSymN = null;
      _liveTextE = null;
      _liveTextN = null;
    });
  }

  void _handleTap(Offset local, Map<String, LabelDragState> drags) {
    final map = _map;
    if (map == null) return;

    // Geometry trim mode (advanced): nodes / segments.
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
    }

    final labelHit = _hitLabel(local, map, drags);
    if (labelHit != null) {
      widget.onSelectLabelPoint?.call(labelHit);
      widget.onSelectSymbol?.call(null);
      widget.onSelectLinework?.call(null);
      widget.onSelectText?.call(null);
      return;
    }
    final textHit = _hitText(local, map);
    if (textHit != null) {
      widget.onSelectText?.call(textHit.id);
      widget.onSelectLabelPoint?.call(null);
      widget.onSelectSymbol?.call(null);
      widget.onSelectLinework?.call(null);
      return;
    }
    final pointHit = _hitPoint(local, map);
    if (pointHit != null) {
      widget.onSelectLabelPoint?.call(pointHit);
      widget.onSelectSymbol?.call(null);
      widget.onSelectLinework?.call(null);
      widget.onSelectText?.call(null);
      return;
    }
    final sym = _hitSymbol(local, map);
    if (sym != null) {
      widget.onSelectSymbol?.call(sym.id);
      widget.onSelectLabelPoint?.call(null);
      widget.onSelectLinework?.call(null);
      widget.onSelectText?.call(null);
      return;
    }
    // Tap linework → select layer (Civil 3D layer properties workflow).
    final lw = hitTestLinework(
      local,
      widget.linework,
      map.toPixel,
      threshold: 18,
      lockedLayers: widget.options.lockedLayers,
    );
    widget.onSelectLinework?.call(lw);
    if (lw != null) {
      widget.onSelectSymbol?.call(null);
      widget.onSelectLabelPoint?.call(null);
      widget.onSelectText?.call(null);
      return;
    }
    widget.onSelectLabelPoint?.call(null);
    widget.onSelectSymbol?.call(null);
    widget.onSelectLinework?.call(null);
    widget.onSelectText?.call(null);
    widget.onSelectNode?.call(null);
    widget.onSelectSegment?.call(null);
  }

  String? _hitPoint(Offset local, _PlanMap map) {
    const r = 16.0;
    String? best;
    var bestD = r * r;
    for (final p in widget.points) {
      final c = map.toPixel(p.easting, p.northing);
      final dx = local.dx - c.dx;
      final dy = local.dy - c.dy;
      final d = dx * dx + dy * dy;
      if (d <= bestD) {
        bestD = d;
        best = p.id;
      }
    }
    return best;
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
    final textHit = _hitText(local, map);
    if (textHit != null) {
      setState(() {
        _dragKind = _DragKind.text;
        _draggingId = textHit.id;
        _liveTextE = textHit.easting;
        _liveTextN = textHit.northing;
      });
      widget.onSelectText?.call(textHit.id);
      widget.onSelectLabelPoint?.call(null);
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
      widget.onSelectText?.call(null);
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
    if (_dragKind == _DragKind.text) {
      final en = map.toSurvey(clamped);
      setState(() {
        _liveTextE = en.$1;
        _liveTextN = en.$2;
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
    String? best;
    var bestDist = 40.0;
    final ann = widget.options.annotationScale.clamp(0.6, 3.0);
    final fontSize = (10.0 * ann).clamp(8.0, 16.0);
    for (final p in widget.points) {
      final drag = drags[p.id];
      final format = widget.options.pointStyleOverrides[p.id]?.labelFormat ??
          widget.options.labelFormat;
      if (format == PointLabelFormat.none) continue;
      final lines = resolvedLabelLines(p, format, drag);
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
    final paperPx = math.max(14.0, widget.options.symbolPaperInches * 72.0);
    for (final s in widget.symbols) {
      final c = map.toPixel(s.easting, s.northing);
      final d = (c - local).distance;
      final half = math.max(8.0, paperPx * 0.5 * s.scale);
      if (d <= half + 10 && d < bestDist + half) {
        bestDist = d;
        best = s;
      }
    }
    return best;
  }

  PlotTextObject? _hitText(Offset local, _PlanMap map) {
    PlotTextObject? best;
    var bestDist = 36.0;
    final catalog = widget.textStyleCatalog ?? TextStyleCatalog.builtin();
    for (final t in widget.textObjects) {
      if (t.text.trim().isEmpty) continue;
      final c = map.toPixel(t.easting, t.northing);
      final style = catalog.resolve(t.textStyleId ?? widget.options.textStyleId);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            fontSize: t.effectiveFontSizePt,
            fontFamily: style.flutterFamily,
            fontWeight: style.flutterWeight,
            fontStyle: style.flutterStyle,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final rect = Rect.fromLTWH(
        c.dx,
        c.dy - tp.height,
        tp.width,
        tp.height,
      ).inflate(8);
      if (rect.contains(local)) {
        final d = (c - local).distance;
        if (d < bestDist) {
          bestDist = d;
          best = t;
        }
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

class _CornerLine {
  const _CornerLine(this.text, {this.fontSize = 9, this.weight = FontWeight.w500});
  final String text;
  final double fontSize;
  final FontWeight weight;
}

void _drawSymbolPlaceholder(
  Canvas canvas,
  Offset center,
  double radius,
  Color color,
) {
  // Outline-only placeholder for unknown blocks — no hatch fill.
  final stroke = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2;
  canvas.drawCircle(center, radius, stroke);
  canvas.drawLine(
    Offset(center.dx - radius * 0.7, center.dy - radius * 0.7),
    Offset(center.dx + radius * 0.7, center.dy + radius * 0.7),
    stroke,
  );
  canvas.drawLine(
    Offset(center.dx - radius * 0.7, center.dy + radius * 0.7),
    Offset(center.dx + radius * 0.7, center.dy - radius * 0.7),
    stroke,
  );
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
    required this.ctbPlotStyle,
    required this.textStyleCatalog,
    required this.layerStyles,
    required this.selectedSymbolId,
    required this.selectedLabelPointId,
    required this.selectedLineworkId,
    required this.selectedLineworkLayer,
    required this.selectedTextId,
    required this.selectedNodeIndex,
    required this.selectedSegmentIndex,
    required this.draggingId,
    required this.dragKind,
    required this.labelDrags,
    required this.textObjects,
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
  final CtbPlotStyleTable ctbPlotStyle;
  final TextStyleCatalog textStyleCatalog;
  final Map<String, DxfLayerStyle> layerStyles;
  final String? selectedSymbolId;
  final String? selectedLabelPointId;
  final String? selectedLineworkId;
  final String? selectedLineworkLayer;
  final String? selectedTextId;
  final int? selectedNodeIndex;
  final int? selectedSegmentIndex;
  final String? draggingId;
  final _DragKind dragKind;
  final Map<String, LabelDragState> labelDrags;
  final List<PlotTextObject> textObjects;
  final String sheetLabel;
  final bool lineEditMode;

  @override
  void paint(Canvas canvas, Size size) {
    // Full-bleed preview: no cream panel, no bordered viewport, no grid.
    // The paper edge is a hair-thin outline only so the user still knows
    // what will be cropped.
    _paintSheetOutline(canvas);
    canvas.save();
    canvas.clipRect(map.sheetRect);
    _paintLinework(canvas);
    _paintSymbols(canvas);
    _paintPointsAndLabels(canvas);
    canvas.restore();
    _paintCornerBlock(canvas);
  }

  void _paintSheetOutline(Canvas canvas) {
    canvas.drawRect(
      map.sheetRect,
      Paint()
        ..color = const Color(0xFF3A3F44)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
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
      ctb: ctbPlotStyle,
      selectedId: lineEditMode ? selectedLineworkId : null,
      selectedLayer: selectedLineworkLayer,
      selectedSegmentIndex: lineEditMode ? selectedSegmentIndex : null,
      selectedNodeIndex: lineEditMode ? selectedNodeIndex : null,
      showNodesForSelected: lineEditMode,
    );
  }

  void _paintPointsAndLabels(Canvas canvas) {
    final defaultArgb = options.defaultPointColorArgb ??
        ctbPlotStyle.resolve(kCtbPointLabelAci).colorArgb;
    final ann = options.annotationScale.clamp(0.6, 3.0);
    final fontSize = (10.0 * ann).clamp(8.0, 16.0);
    final textStyle = textStyleCatalog.resolve(options.textStyleId);

    for (final p in points) {
      final ov = options.pointStyleOverrides[p.id];
      final color = Color(ov?.colorArgb ?? defaultArgb);
      final fill = Paint()..color = color;
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * ann;
      final leader = Paint()
        ..color = color
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final c = map.toPixel(p.easting, p.northing);
      _drawMarker(
        canvas,
        c,
        ov?.markerStyle ?? options.markerStyle,
        fill,
        stroke,
        ann,
      );

      final drag = labelDrags[p.id];
      final format = ov?.labelFormat ?? options.labelFormat;
      final lines = resolvedLabelLines(p, format, drag);
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
            fontFamily: textStyle.flutterFamily,
            fontWeight: textStyle.flutterWeight,
            fontStyle: textStyle.flutterStyle,
            letterSpacing: textStyle.letterSpacingFor(fontSize),
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
    // Object size uses object scale only (not annotation scale).
    final paperPx = math.max(14.0, options.symbolPaperInches * 72.0);
    final labelStyle = textStyleCatalog.resolve(options.textStyleId);
    for (final s in symbols) {
      final c = map.toPixel(s.easting, s.northing);
      final half = math.max(8.0, paperPx * 0.5 * s.scale);
      final selected = s.id == selectedSymbolId ||
          (dragKind == _DragKind.symbol && s.id == draggingId);
      final color = colorWithOpacityArgb(s.colorArgb, s.opacity);

      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(s.rotationDeg * math.pi / 180);
      canvas.translate(-half, -half);

      if (s.kind != null) {
        SymbolPreviewPainter(s.kind!, color: color, opacity: 1.0)
            .paint(canvas, Size(half * 2, half * 2));
      } else if (s.blockId != null && blockCatalog != null) {
        final def = blockCatalog![s.blockId!];
        if (def != null) {
          BlockPreviewPainter(def, color: color, opacity: 1.0)
              .paint(canvas, Size(half * 2, half * 2));
        } else {
          _drawSymbolPlaceholder(canvas, Offset(half, half), half * 0.55, color);
        }
      } else {
        _drawSymbolPlaceholder(canvas, Offset(half, half), half * 0.55, color);
      }
      canvas.restore();

      if (options.showObjectLabels) {
        final tp = TextPainter(
          text: TextSpan(
            text: s.libraryLabel,
            style: TextStyle(
              color: color,
              fontSize: (9.0 * s.scale).clamp(8.0, 14.0),
              fontFamily: labelStyle.flutterFamily,
              fontWeight: labelStyle.flutterWeight,
              fontStyle: labelStyle.flutterStyle,
              backgroundColor: const Color(0xCCF7F4EE),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(c.dx + half + 2, c.dy - tp.height / 2));
      }

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

    for (final t in textObjects) {
      if (t.text.trim().isEmpty) continue;
      final c = map.toPixel(t.easting, t.northing);
      final style = textStyleCatalog.resolve(
        t.textStyleId ?? options.textStyleId,
      );
      final color = colorWithOpacityArgb(t.colorArgb, t.opacity);
      final selected = t.id == selectedTextId ||
          (dragKind == _DragKind.text && t.id == draggingId);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: color,
            fontSize: t.effectiveFontSizePt,
            fontFamily: style.flutterFamily,
            fontWeight: style.flutterWeight,
            fontStyle: style.flutterStyle,
            letterSpacing: style.letterSpacingFor(t.effectiveFontSizePt),
            backgroundColor: selected
                ? const Color(0x66FFE082)
                : const Color(0xAAF7F4EE),
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(c.dx, c.dy - tp.height));
      if (selected) {
        canvas.drawRect(
          Rect.fromLTWH(c.dx, c.dy - tp.height, tp.width, tp.height)
              .inflate(2),
          Paint()
            ..color = const Color(0xFFE4572E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }
  }

  /// Paint the compact corner block preview (name + date + scale bar + N).
  ///
  /// Mirrors [_CornerLegend] from `plot_pdf.dart` at a smaller preview scale
  /// so what the user sees on-screen matches what the PDF will produce.
  void _paintCornerBlock(Canvas canvas) {
    final tb = options.titleBlock;
    final plotName = tb.name.trim();
    // Sheet callout ("11"×17"") — pulled from the template.
    final sheetCallout = options.template.sizeCallout;
    final scaleInt = _cornerScaleFtPerInch().round();
    final lines = <_CornerLine>[
      if (plotName.isNotEmpty)
        _CornerLine(plotName.toUpperCase(), fontSize: 12, weight: FontWeight.w800),
      if (tb.date.trim().isNotEmpty)
        _CornerLine(tb.date.trim().toUpperCase(), fontSize: 8.5),
    ];
    final scaleLine = 'SCALE: 1" = $scaleInt\'  ($sheetCallout)';

    final textPainters = <TextPainter>[
      for (final l in lines)
        TextPainter(
          text: TextSpan(
            text: l.text,
            style: TextStyle(
              color: const Color(0xFF111418),
              fontSize: l.fontSize,
              fontWeight: l.weight,
              letterSpacing: l.weight.index >= FontWeight.w700.index ? 0.4 : 0,
              height: 1.15,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: map.sheetRect.width * 0.4),
    ];
    final scalePainter = TextPainter(
      text: TextSpan(
        text: scaleLine,
        style: const TextStyle(
          color: Color(0xFF111418),
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: map.sheetRect.width * 0.4);

    const arrowW = 26.0;
    const arrowH = 32.0;
    const barW = 110.0;
    const barH = 20.0;

    final textH =
        textPainters.fold<double>(0, (a, tp) => a + tp.height + 1) +
            (textPainters.isEmpty ? 0 : 4);
    final legendH = math.max(arrowH, barH + scalePainter.height + 2);
    const pad = 6.0;

    final blockW = math.max(
          barW + 8 + arrowW,
          textPainters.fold<double>(0, (a, tp) => math.max(a, tp.width)),
        ) +
        pad * 2;
    final blockH = textH + legendH + pad * 2;

    // Bottom-right corner of the sheet, matching the PDF default.
    final corner = _resolveCorner();
    final left = corner.right
        ? map.sheetRect.right - blockW - 6
        : map.sheetRect.left + 6;
    final top = corner.bottom
        ? map.sheetRect.bottom - blockH - 6
        : map.sheetRect.top + 6;
    final box = Rect.fromLTWH(left, top, blockW, blockH);

    canvas.drawRect(box, Paint()..color = const Color(0xF2FFFFFF));
    canvas.drawRect(
      box,
      Paint()
        ..color = const Color(0xFF111418)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );

    var y = box.top + pad;
    for (final tp in textPainters) {
      tp.paint(canvas, Offset(box.left + pad, y));
      y += tp.height + 1;
    }
    if (textPainters.isNotEmpty) y += 4;

    // North arrow (small filled triangle + tail).
    final arrowRect =
        Rect.fromLTWH(box.left + pad, y, arrowW, arrowH);
    _paintPreviewNorthArrow(canvas, arrowRect);

    // Graphic scale bar + scale text next to arrow.
    final barLeft = arrowRect.right + 8;
    final barRect = Rect.fromLTWH(barLeft, y + 4, barW, barH);
    _paintPreviewScaleBar(canvas, barRect, scaleInt);
    scalePainter.paint(canvas, Offset(barLeft, barRect.bottom + 1));
  }

  double _cornerScaleFtPerInch() {
    if (options.scaleFtPerInch != null && options.scaleFtPerInch! > 0) {
      return options.scaleFtPerInch!;
    }
    return chooseEngineeringScale(
      points,
      linework: linework,
      symbols: symbols,
      template: options.template,
    );
  }

  ({bool right, bool bottom}) _resolveCorner() {
    switch (options.template.legendCorner) {
      case FieldLegendCorner.bottomLeft:
        return (right: false, bottom: true);
      case FieldLegendCorner.topLeft:
        return (right: false, bottom: false);
      case FieldLegendCorner.topRight:
        return (right: true, bottom: false);
      case FieldLegendCorner.bottomRight:
        return (right: true, bottom: true);
    }
  }

  void _paintPreviewNorthArrow(Canvas canvas, Rect r) {
    final cx = r.center.dx;
    final head = Path()
      ..moveTo(cx, r.top + 2)
      ..lineTo(cx - 5, r.top + r.height * 0.55)
      ..lineTo(cx, r.top + r.height * 0.48)
      ..lineTo(cx + 5, r.top + r.height * 0.55)
      ..close();
    final fill = Paint()..color = const Color(0xFF111418);
    canvas.drawPath(head, fill);
    canvas.drawLine(
      Offset(cx, r.top + r.height * 0.55),
      Offset(cx, r.bottom - 8),
      Paint()
        ..color = const Color(0xFF111418)
        ..strokeWidth = 1.1,
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Color(0xFF111418),
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, r.bottom - tp.height));
  }

  void _paintPreviewScaleBar(Canvas canvas, Rect r, int scaleFt) {
    final paint = Paint()
      ..color = const Color(0xFF111418)
      ..strokeWidth = 1.0;
    final y = r.top + r.height / 2;
    canvas.drawLine(Offset(r.left, y), Offset(r.right, y), paint);
    canvas.drawLine(Offset(r.left, y - 4), Offset(r.left, y + 4), paint);
    canvas.drawLine(
      Offset(r.center.dx, y - 3),
      Offset(r.center.dx, y + 3),
      paint,
    );
    canvas.drawLine(
      Offset(r.right, y - 4),
      Offset(r.right, y + 4),
      paint,
    );
    final zero = TextPainter(
      text: const TextSpan(
        text: '0',
        style: TextStyle(
          color: Color(0xFF111418),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final mid = TextPainter(
      text: TextSpan(
        text: '$scaleFt',
        style: const TextStyle(
          color: Color(0xFF111418),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    final end = TextPainter(
      text: TextSpan(
        text: '${scaleFt * 2}',
        style: const TextStyle(
          color: Color(0xFF111418),
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    zero.paint(canvas, Offset(r.left - 2, r.bottom - zero.height));
    mid.paint(
      canvas,
      Offset(r.center.dx - mid.width / 2, r.bottom - mid.height),
    );
    end.paint(canvas, Offset(r.right - end.width, r.bottom - end.height));
  }

  @override
  bool shouldRepaint(covariant _PlotPreviewPainter old) {
    return old.points != points ||
        old.linework != linework ||
        old.symbols != symbols ||
        old.textObjects != textObjects ||
        old.options != options ||
        old.textStyleCatalog != textStyleCatalog ||
        old.selectedSymbolId != selectedSymbolId ||
        old.selectedLabelPointId != selectedLabelPointId ||
        old.selectedLineworkId != selectedLineworkId ||
        old.selectedLineworkLayer != selectedLineworkLayer ||
        old.selectedTextId != selectedTextId ||
        old.selectedNodeIndex != selectedNodeIndex ||
        old.selectedSegmentIndex != selectedSegmentIndex ||
        old.draggingId != draggingId ||
        old.dragKind != dragKind ||
        old.labelDrags != labelDrags ||
        old.lineEditMode != lineEditMode ||
        old.sheetLabel != sheetLabel;
  }
}
