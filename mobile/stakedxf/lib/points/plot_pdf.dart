import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'block_catalog.dart';
import 'dxf_linework.dart';
import 'ctb_plot_style.dart';
import 'label_placement.dart';
import 'leader_geometry.dart';
import 'linetype_catalog.dart';
import 'linework_draw.dart';
import 'plot_annotations.dart';
import 'plot_options.dart';
import 'plot_symbols.dart';
import 'plot_templates.dart';
import 'survey_point.dart';
import 'symbol_draw.dart';
import 'text_style_catalog.dart';

/// Legacy alias — ANSI B landscape full-bleed sheet (11"×17" landscape).
final PdfPageFormat stakingSheet = kDefaultPlotTemplate.pageFormat;

/// Default point/label color from CTB ACI 10 (reddish object color).
PdfColor _pointLabelColor(CtbPlotStyleTable? ctb, {int? overrideArgb}) {
  if (overrideArgb != null) return PdfColor.fromInt(overrideArgb);
  final argb = (ctb ?? CtbPlotStyleTable.builtin())
      .resolve(kCtbPointLabelAci)
      .colorArgb;
  return PdfColor.fromInt(argb);
}

/// Build a staking plot PDF with user [options] (including sheet template).
Future<Uint8List> buildStakingPlotPdf({
  required List<SurveyPoint> points,
  required String jobName,
  DateTime? date,
  String title = 'STAKING PLOT',
  PlotOptions options = const PlotOptions(),
  List<LineworkEntity> linework = const [],
  List<PlacedPlotSymbol> symbols = const [],
  List<PlotTextObject> textObjects = const [],
  BlockCatalog? blockCatalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  LinetypeCatalog? linetypeCatalog,
  CtbPlotStyleTable? ctbPlotStyle,
  TextStyleCatalog? textStyleCatalog,
}) async {
  final textStyles = textStyleCatalog ?? TextStyleCatalog.builtin();
  if (points.isEmpty) {
    throw ArgumentError('Select at least one point');
  }

  final template = options.template;
  // NOTE: `date` is accepted for backward compatibility with older callers;
  // nothing on the sheet references it any longer (plot rework, v1.24.1).
  final scaleFtPerInch = chooseEngineeringScale(
    points,
    linework: linework,
    symbols: symbols,
    template: template,
    overrideFtPerInch: options.scaleFtPerInch,
  );
  final doc = pw.Document(
    title: '$title — ${jobName.isEmpty ? "FIELD" : jobName}',
    author: 'StakeDXF',
  );

  final drawnLinework = options.includeLinework ? linework : const <LineworkEntity>[];
  final catalog = linetypeCatalog ?? LinetypeCatalog.builtin();
  final ctb = ctbPlotStyle ?? CtbPlotStyleTable.builtin();

  doc.addPage(
    pw.Page(
      pageFormat: template.pageFormat,
      build: (context) => _buildFullBleedPage(
        template: template,
        title: title,
        jobName: jobName,
        points: points,
        scaleFtPerInch: scaleFtPerInch,
        options: options,
        linework: drawnLinework,
        symbols: symbols,
        blockCatalog: blockCatalog,
        layerStyles: layerStyles,
        linetypeCatalog: catalog,
        ctbPlotStyle: ctb,
        textObjects: textObjects,
        textStyleCatalog: textStyles,
      ),
    ),
  );

  return doc.save();
}

/// Draw a single ANSI-size full-bleed staking sheet.
///
/// The sheet is literally just the plan — no bounding box, no scale text,
/// no north arrow, no sheet-size callout. When the user enables it, an
/// optional draggable **plot title** is drawn on top of the plan; it
/// lives in paper space (its fractional position tracks the sheet).
pw.Widget _buildFullBleedPage({
  required PlotTemplate template,
  required String title,
  required String jobName,
  required List<SurveyPoint> points,
  required double scaleFtPerInch,
  required PlotOptions options,
  required List<LineworkEntity> linework,
  required List<PlacedPlotSymbol> symbols,
  required BlockCatalog? blockCatalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  LinetypeCatalog? linetypeCatalog,
  CtbPlotStyleTable? ctbPlotStyle,
  List<PlotTextObject> textObjects = const [],
  TextStyleCatalog? textStyleCatalog,
}) {
  final tb = options.titleBlock;
  final plan = _PlanPanel(
    points: points,
    scaleFtPerInch: scaleFtPerInch,
    options: options,
    linework: linework,
    symbols: symbols,
    blockCatalog: blockCatalog,
    layerStyles: layerStyles,
    linetypeCatalog: linetypeCatalog,
    ctbPlotStyle: ctbPlotStyle,
    textObjects: textObjects,
    textStyleCatalog: textStyleCatalog,
  );

  if (!tb.enabled || tb.name.trim().isEmpty) {
    return plan;
  }

  return pw.Stack(
    fit: pw.StackFit.expand,
    children: [
      pw.Positioned.fill(child: plan),
      _PlotTitle(title: tb),
    ],
  );
}

/// Optional draggable plot title — the only overlay StakeDXF draws on the
/// ANSI full-bleed sheet. No background, no border; just centred bold text.
class _PlotTitle extends pw.StatelessWidget {
  _PlotTitle({required this.title});

  final TitleBlockData title;

  @override
  pw.Widget build(pw.Context context) {
    final fx = title.paperFracX.clamp(0.0, 1.0);
    final fy = title.paperFracY.clamp(0.0, 1.0);
    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints?.maxWidth ?? 0;
        final h = constraints?.maxHeight ?? 0;
        if (w <= 0 || h <= 0) return pw.SizedBox.shrink();
        final fs = title.fontSizePt.clamp(6.0, 96.0);
        // Estimate text width so we can horizontally centre on (fx*w).
        // 0.55 is a fair average character width for bold helvetica.
        final approxTextW = fs * title.name.trim().length * 0.55;
        final left = (fx * w - approxTextW / 2).clamp(4.0, w - approxTextW - 4);
        final top = (fy * h - fs * 0.5).clamp(4.0, h - fs - 4);
        return pw.Positioned(
          left: left,
          top: top,
          child: pw.Text(
            title.name.trim().toUpperCase(),
            style: pw.TextStyle(
              fontSize: fs,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: fs * 0.03,
              font: pw.Font.helveticaBold(),
              color: PdfColors.black,
            ),
          ),
        );
      },
    );
  }
}

/// Axis-aligned plan bounds used for auto-scale and `_paintPlan` framing.
class PlanViewBounds {
  const PlanViewBounds({
    required this.minE,
    required this.maxE,
    required this.minN,
    required this.maxN,
  });

  final double minE;
  final double maxE;
  final double minN;
  final double maxN;

  double get midE => (minE + maxE) / 2;
  double get midN => (minN + maxN) / 2;
  double get rangeE => math.max(maxE - minE, 1.0);
  double get rangeN => math.max(maxN - minN, 1.0);
}

/// Frame the plan on stake points, admitting only nearby linework.
///
/// Library objects are ignored by default so dragging them does not zoom the
/// sheet out. Distant DXF leftovers must not expand the view either.
PlanViewBounds computePlanViewBounds(
  List<SurveyPoint> points, {
  List<LineworkEntity> linework = const [],
  List<PlacedPlotSymbol> symbols = const [],
  bool includeSymbols = false,
}) {
  if (points.isEmpty) {
    throw ArgumentError('Select at least one point');
  }

  var minE = points.first.easting;
  var maxE = points.first.easting;
  var minN = points.first.northing;
  var maxN = points.first.northing;
  for (final p in points) {
    if (!_finite2(p.easting, p.northing)) continue;
    minE = math.min(minE, p.easting);
    maxE = math.max(maxE, p.easting);
    minN = math.min(minN, p.northing);
    maxN = math.max(maxN, p.northing);
  }
  if (includeSymbols) {
    for (final s in symbols) {
      if (!_finite2(s.easting, s.northing)) continue;
      final half = s.sizeFt / 2;
      minE = math.min(minE, s.easting - half);
      maxE = math.max(maxE, s.easting + half);
      minN = math.min(minN, s.northing - half);
      maxN = math.max(maxN, s.northing + half);
    }
  }

  // Gate: linework only affects framing when it sits near the stake cluster.
  final seedRangeE = math.max(maxE - minE, 1.0);
  final seedRangeN = math.max(maxN - minN, 1.0);
  final padE = math.max(200.0, seedRangeE * 0.75);
  final padN = math.max(200.0, seedRangeN * 0.75);
  final gateMinE = minE - padE;
  final gateMaxE = maxE + padE;
  final gateMinN = minN - padN;
  final gateMaxN = maxN + padN;

  for (final e in linework) {
    for (final p in e.samplePoints) {
      final x = p[0];
      final y = p[1];
      if (!_finite2(x, y)) continue;
      if (x < gateMinE || x > gateMaxE || y < gateMinN || y > gateMaxN) {
        continue;
      }
      minE = math.min(minE, x);
      maxE = math.max(maxE, x);
      minN = math.min(minN, y);
      maxN = math.max(maxN, y);
    }
  }

  return PlanViewBounds(minE: minE, maxE: maxE, minN: minN, maxN: maxN);
}

bool _finite2(double a, double b) => a.isFinite && b.isFinite;

/// Standard engineering scales (feet per inch), including common field values.
const kEngineeringScaleStandards = <double>[
  10, 20, 30, 40, 50, 60, 80, 100, 150, 200, 300, 400, 500, 600, 800, 1000,
  1200, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 8000, 10000,
];

/// Pick a standard engineering scale (feet per inch) that fits the content.
///
/// When [overrideFtPerInch] is set, that value is used as-is.
double chooseEngineeringScale(
  List<SurveyPoint> points, {
  List<LineworkEntity> linework = const [],
  List<PlacedPlotSymbol> symbols = const [],
  PlotTemplate template = kDefaultPlotTemplate,
  bool showPointList = false,
  double? overrideFtPerInch,
}) {
  if (overrideFtPerInch != null && overrideFtPerInch > 0) {
    return overrideFtPerInch;
  }
  final bounds = computePlanViewBounds(
    points,
    linework: linework,
    symbols: symbols,
    includeSymbols: false,
  );
  final usable = template.usablePlanInchesFor(showPointList: showPointList);
  final need = math.max(
        bounds.rangeE / usable.widthIn,
        bounds.rangeN / usable.heightIn,
      ) *
      1.12;
  for (final s in kEngineeringScaleStandards) {
    if (s >= need) return s;
  }
  return kEngineeringScaleStandards.last;
}

class _PlanPanel extends pw.StatelessWidget {
  _PlanPanel({
    required this.points,
    required this.scaleFtPerInch,
    required this.options,
    required this.linework,
    required this.symbols,
    this.blockCatalog,
    this.layerStyles = const {},
    this.linetypeCatalog,
    this.ctbPlotStyle,
    this.textObjects = const [],
    this.textStyleCatalog,
  });

  final List<SurveyPoint> points;
  final double scaleFtPerInch;
  final PlotOptions options;
  final List<PlacedPlotSymbol> symbols;
  final List<LineworkEntity> linework;
  final BlockCatalog? blockCatalog;
  final Map<String, DxfLayerStyle> layerStyles;
  final LinetypeCatalog? linetypeCatalog;
  final CtbPlotStyleTable? ctbPlotStyle;
  final List<PlotTextObject> textObjects;
  final TextStyleCatalog? textStyleCatalog;

  @override
  pw.Widget build(pw.Context context) {
    final catalog = textStyleCatalog ?? TextStyleCatalog.builtin();
    final style = catalog.resolve(options.textStyleId);
    final labelFont = catalog.pdfFont(style).getFont(context);
    return pw.LayoutBuilder(
      builder: (context, constraints) {
        // pdf LayoutBuilder can hand infinity/0 when flex constraints are loose;
        // never size CustomPaint to a non-drawable area (border-only sheets).
        final maxW = constraints?.maxWidth ?? 0;
        final maxH = constraints?.maxHeight ?? 0;
        final minW = constraints?.minWidth ?? 0;
        final minH = constraints?.minHeight ?? 0;
        final w = (maxW.isFinite && maxW >= 8)
            ? maxW
            : (minW.isFinite && minW >= 8 ? minW : 500.0);
        final h = (maxH.isFinite && maxH >= 8)
            ? maxH
            : (minH.isFinite && minH >= 8 ? minH : 600.0);
        // Full-bleed: no border, no cream fill — the sheet IS the plan.
        return pw.SizedBox(
          width: w,
          height: h,
          child: pw.CustomPaint(
            size: PdfPoint(w, h),
            painter: (canvas, size) => paintStakingPlan(
              canvas,
              size,
              points,
              scaleFtPerInch,
              labelFont,
              options,
              linework,
              symbols,
              blockCatalog,
              layerStyles: layerStyles,
              linetypeCatalog: linetypeCatalog,
              ctbPlotStyle: ctbPlotStyle,
              textObjects: textObjects,
            ),
          ),
        );
      },
    );
  }
}

/// Paint stake points / linework / symbols into a plan viewport.
///
/// Shared by PDF export and (optionally) in-app preview so both use the same
/// framing, scale, and draw order.
void paintStakingPlan(
  PdfGraphics canvas,
  PdfPoint size,
  List<SurveyPoint> points,
  double scaleFtPerInch,
  PdfFont labelFont,
  PlotOptions options,
  List<LineworkEntity> linework,
  List<PlacedPlotSymbol> symbols,
  BlockCatalog? blockCatalog, {
  Map<String, DxfLayerStyle> layerStyles = const {},
  LinetypeCatalog? linetypeCatalog,
  CtbPlotStyleTable? ctbPlotStyle,
  List<PlotTextObject> textObjects = const [],
}) {
  if (size.x < 8 || size.y < 8 || !size.x.isFinite || !size.y.isFinite) {
    return;
  }
  final ctb = ctbPlotStyle ?? CtbPlotStyleTable.builtin();

  final bounds = computePlanViewBounds(
    points,
    linework: linework,
    symbols: symbols,
  );
  final midE = bounds.midE;
  final midN = bounds.midN;
  final ppt = 72.0 / scaleFtPerInch;

  PdfPoint toPage(double e, double n) {
    final x = size.x / 2 + (e - midE) * ppt;
    final y = size.y / 2 + (n - midN) * ppt;
    return PdfPoint(x, y);
  }

  // Clip so distant capped linework cannot paint outside the sheet.
  canvas
    ..saveContext()
    ..drawRect(0, 0, size.x, size.y)
    ..clipPath();

  // Linework under markers — styled dashes / colors / weights.
  paintLineworkPdf(
    canvas: canvas,
    linework: linework,
    toPage: toPage,
    catalog: linetypeCatalog ?? LinetypeCatalog.builtin(),
    layerStyles: layerStyles,
    layerOverrides: options.layerStyleOverrides,
    entityOverrides: options.entityStyleOverrides,
    globalLinetypeScale: options.globalLinetypeScale,
    ctb: ctb,
  );

  // Library objects — paper-sized; independent of annotation scale.
  if (symbols.isNotEmpty) {
    drawPlacedSymbols(
      canvas,
      toPage,
      ppt,
      symbols,
      labelFont,
      blocks: blockCatalog,
      showLabels: options.showObjectLabels,
      symbolPaperInches: options.symbolPaperInches,
    );
  }

  // Free text objects — independently scaled.
  for (final t in textObjects) {
    if (!_finite2(t.easting, t.northing) || t.text.trim().isEmpty) continue;
    final c = toPage(t.easting, t.northing);
    final fs = t.effectiveFontSizePt;
    canvas
      ..saveContext()
      ..setGraphicState(
        PdfGraphicState(opacity: t.opacity.clamp(0.05, 1.0)),
      )
      ..setFillColor(PdfColor.fromInt(t.colorArgb | 0xFF000000))
      ..drawString(labelFont, fs, t.text, c.x, c.y)
      ..restoreContext();
  }

  final ann = options.annotationScale.clamp(0.6, 3.0);
  final fontSize = (8.5 * ann).clamp(7.0, 14.0);
  final lineH = fontSize * 1.15;

  // Resolve Civil-style label drag offsets (auto-spread undragged).
  var drags = options.labelDrags;
  if (options.autoSpreadLabels &&
      options.labelFormat != PointLabelFormat.none) {
    drags = autoSpreadLabels(
      points: points,
      format: options.labelFormat,
      scaleFtPerInch: scaleFtPerInch,
      existing: options.labelDrags,
      annotationScale: ann,
    );
  }

  // Point markers (fixed locations — never moved by label drag).
  for (final p in points) {
    if (!_finite2(p.easting, p.northing)) continue;
    final ov = options.pointStyleOverrides[p.id];
    final c = toPage(p.easting, p.northing);
    final color = _pointLabelColor(
      ctb,
      overrideArgb: ov?.colorArgb ?? options.defaultPointColorArgb,
    );
    _drawMarker(
      canvas,
      c,
      ov?.markerStyle ?? options.markerStyle,
      sizeScale: ann,
      color: color,
    );
  }

  // Labels with Civil-style dogleg leaders (never through text).
  for (final p in points) {
    if (!_finite2(p.easting, p.northing)) continue;
    final ov = options.pointStyleOverrides[p.id];
    final format = ov?.labelFormat ?? options.labelFormat;
    final drag = drags[p.id];
    final lines = resolvedLabelLines(p, format, drag);
    if (lines.isEmpty) continue;
    final pointColor = _pointLabelColor(
      ctb,
      overrideArgb: ov?.colorArgb ?? options.defaultPointColorArgb,
    );
    final c = toPage(p.easting, p.northing);
    final oE = drag?.offsetE ?? 14.0;
    final oN = drag?.offsetN ?? 10.0;
    final anchor = toPage(p.easting + oE, p.northing + oN);
    final labelW = math.max(
      28.0,
      lines.fold<int>(0, (m, l) => math.max(m, l.length)) * fontSize * 0.52 + 4,
    );
    final labelH = lineH * lines.length;
    final g = buildLeaderPdf(
      pointX: c.x,
      pointY: c.y,
      anchorX: anchor.x - labelW / 2,
      anchorY: anchor.y,
      labelWidth: labelW,
      labelHeight: labelH,
      landingLength: math.max(8.0, fontSize),
    );

    final dragged = (drag?.isDragged ?? false) ||
        math.sqrt(oE * oE + oN * oN) > 8;
    if (dragged) {
      canvas
        ..setStrokeColor(pointColor)
        ..setLineWidth(0.65)
        ..drawLine(g.ax, g.ay, g.ex, g.ey)
        ..drawLine(g.ex, g.ey, g.lx, g.ly)
        ..strokePath();
    }

    canvas.setFillColor(pointColor);
    var ty = g.oy + labelH - fontSize * 0.2;
    for (final line in lines) {
      canvas.drawString(labelFont, fontSize, line, g.ox, ty);
      ty -= lineH;
    }
  }

  canvas.restoreContext();
}

void _drawMarker(
  PdfGraphics canvas,
  PdfPoint c,
  PointMarkerStyle style, {
  double sizeScale = 1.0,
  PdfColor color = const PdfColor.fromInt(0xFF000000),
}) {
  final k = sizeScale.clamp(0.6, 3.0);
  canvas
    ..setStrokeColor(color)
    ..setFillColor(color)
    ..setLineWidth(0.9 * k);

  switch (style) {
    case PointMarkerStyle.triangleFilled:
    case PointMarkerStyle.triangleOutline:
      final triW = 9.0 * k;
      final triH = 8.0 * k;
      final apex = PdfPoint(c.x, c.y + triH * 2 / 3);
      final bl = PdfPoint(c.x - triW / 2, c.y - triH / 3);
      final br = PdfPoint(c.x + triW / 2, c.y - triH / 3);
      canvas
        ..moveTo(apex.x, apex.y)
        ..lineTo(bl.x, bl.y)
        ..lineTo(br.x, br.y)
        ..closePath();
      if (style == PointMarkerStyle.triangleFilled) {
        canvas.fillPath();
        canvas
          ..moveTo(apex.x, apex.y)
          ..lineTo(bl.x, bl.y)
          ..lineTo(br.x, br.y)
          ..closePath()
          ..setLineWidth(0.35 * k)
          ..strokePath();
      } else {
        canvas
          ..setLineWidth(0.9 * k)
          ..strokePath();
      }
      break;
    case PointMarkerStyle.cross:
      final arm = 5.0 * k;
      canvas
        ..drawLine(c.x - arm, c.y, c.x + arm, c.y)
        ..drawLine(c.x, c.y - arm, c.x, c.y + arm)
        ..strokePath();
      break;
    case PointMarkerStyle.x:
      final arm = 4.5 * k;
      canvas
        ..drawLine(c.x - arm, c.y - arm, c.x + arm, c.y + arm)
        ..drawLine(c.x - arm, c.y + arm, c.x + arm, c.y - arm)
        ..strokePath();
      break;
    case PointMarkerStyle.largeX:
      final arm = 7.5 * k;
      canvas
        ..setLineWidth(1.4 * k)
        ..drawLine(c.x - arm, c.y - arm, c.x + arm, c.y + arm)
        ..drawLine(c.x - arm, c.y + arm, c.x + arm, c.y - arm)
        ..strokePath();
      break;
    case PointMarkerStyle.circle:
      canvas
        ..drawEllipse(c.x, c.y, 4.2 * k, 4.2 * k)
        ..strokePath();
      break;
    case PointMarkerStyle.dot:
      canvas
        ..drawEllipse(c.x, c.y, 2.2 * k, 2.2 * k)
        ..fillPath();
      break;
    case PointMarkerStyle.largeDot:
      canvas
        ..drawEllipse(c.x, c.y, 4.0 * k, 4.0 * k)
        ..fillPath();
      break;
  }
}

