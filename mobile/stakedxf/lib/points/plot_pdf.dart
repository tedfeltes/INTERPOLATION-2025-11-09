import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'block_catalog.dart';
import 'dxf_linework.dart';
import 'label_placement.dart';
import 'leader_geometry.dart';
import 'linetype_catalog.dart';
import 'linework_draw.dart';
import 'plot_options.dart';
import 'plot_symbols.dart';
import 'plot_templates.dart';
import 'survey_point.dart';
import 'symbol_draw.dart';

/// Legacy alias — ANSI B landscape control-note sheet.
final PdfPageFormat stakingSheet = kDefaultPlotTemplate.pageFormat;

const _noteText =
    'NOTE: Points shown were established for construction staking. '
    'It is the responsibility of the end user to verify points and '
    'use good survey practices before relying on this plot in the field.';

const _trioAddress =
    'TRIO Engineering, LLC\n'
    '4100 N. Calhoun Rd., Suite 300\n'
    'Brookfield, WI 53005\n'
    '262.790.1480';

/// ACI 10 — stake points and labels.
const _markerRed = PdfColor.fromInt(0xFFFF0000);

/// Build a staking plot PDF with user [options] (including sheet template).
Future<Uint8List> buildStakingPlotPdf({
  required List<SurveyPoint> points,
  required String jobName,
  DateTime? date,
  String title = 'STAKING PLOT',
  PlotOptions options = const PlotOptions(),
  List<LineworkEntity> linework = const [],
  List<PlacedPlotSymbol> symbols = const [],
  BlockCatalog? blockCatalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  LinetypeCatalog? linetypeCatalog,
}) async {
  if (points.isEmpty) {
    throw ArgumentError('Select at least one point');
  }

  final template = options.template;
  final when = date ?? DateTime.now();
  final dateStr =
      '${when.month.toString().padLeft(2, '0')}/${when.day.toString().padLeft(2, '0')}/${(when.year % 100).toString().padLeft(2, '0')}';
  final scaleFtPerInch = chooseEngineeringScale(
    points,
    linework: linework,
    symbols: symbols,
    template: template,
    showPointList: options.showPointList,
  );
  final doc = pw.Document(
    title: '$title — ${jobName.isEmpty ? "FIELD" : jobName}',
    author: 'StakeDXF',
  );

  final drawnLinework = options.includeLinework ? linework : const <LineworkEntity>[];
  final catalog = linetypeCatalog ?? LinetypeCatalog.builtin();

  doc.addPage(
    pw.Page(
      pageFormat: template.pageFormat,
      build: (context) {
        switch (template.layout) {
          case PlotTemplateLayout.sidePanel:
            return _buildSidePanelPage(
              template: template,
              title: title,
              jobName: jobName,
              points: points,
              scaleFtPerInch: scaleFtPerInch,
              dateStr: dateStr,
              options: options,
              linework: drawnLinework,
              symbols: symbols,
              blockCatalog: blockCatalog,
              layerStyles: layerStyles,
              linetypeCatalog: catalog,
            );
          case PlotTemplateLayout.fieldMap:
            return _buildFieldMapPage(
              template: template,
              title: title,
              jobName: jobName,
              points: points,
              scaleFtPerInch: scaleFtPerInch,
              dateStr: dateStr,
              options: options,
              linework: drawnLinework,
              symbols: symbols,
              blockCatalog: blockCatalog,
              showTitleHeader: false,
              layerStyles: layerStyles,
              linetypeCatalog: catalog,
            );
          case PlotTemplateLayout.fieldHeader:
            return _buildFieldMapPage(
              template: template,
              title: title,
              jobName: jobName,
              points: points,
              scaleFtPerInch: scaleFtPerInch,
              dateStr: dateStr,
              options: options,
              linework: drawnLinework,
              symbols: symbols,
              blockCatalog: blockCatalog,
              showTitleHeader: true,
              layerStyles: layerStyles,
              linetypeCatalog: catalog,
            );
        }
      },
    ),
  );

  return doc.save();
}

pw.Widget _buildSidePanelPage({
  required PlotTemplate template,
  required String title,
  required String jobName,
  required List<SurveyPoint> points,
  required double scaleFtPerInch,
  required String dateStr,
  required PlotOptions options,
  required List<LineworkEntity> linework,
  required List<PlacedPlotSymbol> symbols,
  required BlockCatalog? blockCatalog,
  Map<String, DxfLayerStyle> layerStyles = const {},
  LinetypeCatalog? linetypeCatalog,
}) {
  final showTable = options.showPointList;
  final plotFlex = showTable ? 58 : 78;
  final sideFlex = showTable ? 42 : 22;
  final pad = template.outerPaddingPt;
  return pw.Padding(
    padding: pw.EdgeInsets.all(pad),
    child: pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 1.2, color: PdfColors.black),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            flex: plotFlex,
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(10),
              child: _PlanPanel(
                points: points,
                scaleFtPerInch: scaleFtPerInch,
                options: options,
                linework: linework,
                symbols: symbols,
                blockCatalog: blockCatalog,
                layerStyles: layerStyles,
                linetypeCatalog: linetypeCatalog,
              ),
            ),
          ),
          pw.Container(width: 1.2, color: PdfColors.black),
          pw.Expanded(
            flex: sideFlex,
            child: pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _SidePanel(
                title: title,
                jobName: jobName,
                points: points,
                scaleFtPerInch: scaleFtPerInch,
                dateStr: dateStr,
                showPointList: showTable,
                compact: !showTable,
                sheetCallout: template.sizeCallout,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

pw.Widget _buildFieldMapPage({
  required PlotTemplate template,
  required String title,
  required String jobName,
  required List<SurveyPoint> points,
  required double scaleFtPerInch,
  required String dateStr,
  required PlotOptions options,
  required List<LineworkEntity> linework,
  required List<PlacedPlotSymbol> symbols,
  required BlockCatalog? blockCatalog,
  required bool showTitleHeader,
  Map<String, DxfLayerStyle> layerStyles = const {},
  LinetypeCatalog? linetypeCatalog,
}) {
  final pad = template.outerPaddingPt;
  final footer = _FieldLegendStrip(
    title: title,
    jobName: jobName,
    scaleFtPerInch: scaleFtPerInch,
    dateStr: dateStr,
    sheetCallout: template.sizeCallout,
    pointCount: points.length,
    showTitleHeader: showTitleHeader,
    corner: template.legendCorner,
  );

  final plan = _PlanPanel(
    points: points,
    scaleFtPerInch: scaleFtPerInch,
    options: options,
    linework: linework,
    symbols: symbols,
    blockCatalog: blockCatalog,
    layerStyles: layerStyles,
    linetypeCatalog: linetypeCatalog,
  );

  // Explicit plan height — pdf Expanded can collapse to 0 on some sheets,
  // which produced border-only / empty field maps.
  final pageH = template.heightIn * PdfPageFormat.inch;
  final footerH = showTitleHeader ? 78.0 : 58.0;
  final planH = math.max(120.0, pageH - 2 * pad - footerH - 8);

  final children = showTitleHeader
      ? <pw.Widget>[
          footer,
          pw.SizedBox(height: 6),
          pw.SizedBox(height: planH, child: plan),
        ]
      : <pw.Widget>[
          pw.SizedBox(height: planH, child: plan),
          pw.SizedBox(height: 6),
          footer,
        ];

  return pw.Padding(
    padding: pw.EdgeInsets.all(pad),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: children,
    ),
  );
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

/// Pick a standard engineering scale (feet per inch) that fits the content.
double chooseEngineeringScale(
  List<SurveyPoint> points, {
  List<LineworkEntity> linework = const [],
  List<PlacedPlotSymbol> symbols = const [],
  PlotTemplate template = kDefaultPlotTemplate,
  bool showPointList = false,
}) {
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
  const standards = <double>[
    10, 20, 30, 40, 50, 60, 80, 100, 200, 300, 400, 500, 600, 800, 1000,
    1200, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 8000, 10000,
  ];
  for (final s in standards) {
    if (s >= need) return s;
  }
  return standards.last;
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
  });

  final List<SurveyPoint> points;
  final double scaleFtPerInch;
  final PlotOptions options;
  final List<PlacedPlotSymbol> symbols;
  final List<LineworkEntity> linework;
  final BlockCatalog? blockCatalog;
  final Map<String, DxfLayerStyle> layerStyles;
  final LinetypeCatalog? linetypeCatalog;

  @override
  pw.Widget build(pw.Context context) {
    final labelFont = pw.Font.helveticaBoldOblique().getFont(context);
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
        return pw.Container(
          width: w,
          height: h,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.8, color: PdfColors.grey700),
            color: const PdfColor.fromInt(0xFFF7F4EE),
          ),
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
}) {
  if (size.x < 8 || size.y < 8 || !size.x.isFinite || !size.y.isFinite) {
    return;
  }

  final bounds = computePlanViewBounds(
    points,
    linework: linework,
    symbols: symbols,
  );
  final midE = bounds.midE;
  final midN = bounds.midN;
  final minE = bounds.minE;
  final maxE = bounds.maxE;
  final minN = bounds.minN;
  final maxN = bounds.maxN;
  final ppt = 72.0 / scaleFtPerInch;

  PdfPoint toPage(double e, double n) {
    final x = size.x / 2 + (e - midE) * ppt;
    final y = size.y / 2 + (n - midN) * ppt;
    return PdfPoint(x, y);
  }

  // Clip so distant capped linework cannot paint outside the cream panel.
  canvas
    ..saveContext()
    ..drawRect(0, 0, size.x, size.y)
    ..clipPath();

  final gridFt = scaleFtPerInch;
  final startE = (minE / gridFt).floor() * gridFt - gridFt;
  final endE = (maxE / gridFt).ceil() * gridFt + gridFt;
  final startN = (minN / gridFt).floor() * gridFt - gridFt;
  final endN = (maxN / gridFt).ceil() * gridFt + gridFt;

  canvas
    ..setStrokeColor(const PdfColor.fromInt(0xFFD9D2C5))
    ..setLineWidth(0.4);
  for (var e = startE; e <= endE + 0.001; e += gridFt) {
    final a = toPage(e, startN);
    final b = toPage(e, endN);
    canvas.drawLine(a.x, a.y, b.x, b.y);
  }
  for (var n = startN; n <= endN + 0.001; n += gridFt) {
    final a = toPage(startE, n);
    final b = toPage(endE, n);
    canvas.drawLine(a.x, a.y, b.x, b.y);
  }
  canvas.strokePath();

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
  );

  // Library objects — paper-sized; labels off unless requested.
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
      annotationScale: options.annotationScale,
    );
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
    final c = toPage(p.easting, p.northing);
    _drawMarker(canvas, c, options.markerStyle, sizeScale: ann);
  }

  // Labels with Civil-style dogleg leaders (never through text).
  for (final p in points) {
    if (!_finite2(p.easting, p.northing)) continue;
    final drag = drags[p.id];
    final lines = resolvedLabelLines(p, options.labelFormat, drag);
    if (lines.isEmpty) continue;
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
        ..setStrokeColor(_markerRed)
        ..setLineWidth(0.65)
        ..drawLine(g.ax, g.ay, g.ex, g.ey)
        ..drawLine(g.ex, g.ey, g.lx, g.ly)
        ..strokePath();
    }

    canvas.setFillColor(_markerRed);
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
}) {
  final k = sizeScale.clamp(0.6, 3.0);
  canvas
    ..setStrokeColor(_markerRed)
    ..setFillColor(_markerRed)
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

class _FieldLegendStrip extends pw.StatelessWidget {
  _FieldLegendStrip({
    required this.title,
    required this.jobName,
    required this.scaleFtPerInch,
    required this.dateStr,
    required this.sheetCallout,
    required this.pointCount,
    required this.showTitleHeader,
    required this.corner,
  });

  final String title;
  final String jobName;
  final double scaleFtPerInch;
  final String dateStr;
  final String sheetCallout;
  final int pointCount;
  final bool showTitleHeader;
  final FieldLegendCorner corner;

  @override
  pw.Widget build(pw.Context context) {
    final scaleInt = scaleFtPerInch.round();
    final scaleLine = 'SCALE: 1" = $scaleInt\'  ($sheetCallout)';
    final titleBlock = pw.Column(
      crossAxisAlignment: showTitleHeader
          ? pw.CrossAxisAlignment.start
          : pw.CrossAxisAlignment.start,
      children: [
        if (showTitleHeader || jobName.trim().isNotEmpty) ...[
          pw.Text(
            (jobName.trim().isEmpty ? title : jobName).toUpperCase(),
            style: pw.TextStyle(
              fontSize: showTitleHeader ? 13 : 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (showTitleHeader &&
              jobName.trim().isNotEmpty &&
              title.trim().isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(
              title.toUpperCase(),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
          pw.SizedBox(height: 4),
        ],
        pw.Text(
          'DATE: $dateStr   ·   $pointCount pt${pointCount == 1 ? "" : "s"}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );

    final legend = pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.SizedBox(width: 44, height: 48, child: _NorthArrow()),
        pw.SizedBox(width: 8),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 160,
              height: 28,
              child: _GraphicScale(scaleFtPerInch: scaleFtPerInch),
            ),
            pw.Text(
              scaleLine,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                font: pw.Font.timesBold(),
              ),
            ),
          ],
        ),
      ],
    );

    final alignStart = corner == FieldLegendCorner.bottomLeft ||
        corner == FieldLegendCorner.topLeft;

    if (showTitleHeader) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: titleBlock),
          legend,
        ],
      );
    }

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: alignStart
          ? [legend, pw.Spacer(), titleBlock]
          : [titleBlock, pw.Spacer(), legend],
    );
  }
}

class _SidePanel extends pw.StatelessWidget {
  _SidePanel({
    required this.title,
    required this.jobName,
    required this.points,
    required this.scaleFtPerInch,
    required this.dateStr,
    required this.showPointList,
    required this.compact,
    this.sheetCallout = '17"×11"',
  });

  final String title;
  final String jobName;
  final List<SurveyPoint> points;
  final double scaleFtPerInch;
  final String dateStr;
  final bool showPointList;
  final bool compact;
  final String sheetCallout;

  @override
  pw.Widget build(pw.Context context) {
    final scaleInt = scaleFtPerInch.round();
    final titleSize = compact ? 14.0 : 22.0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: compact ? 4 : 8),
        pw.Text(
          title.toUpperCase(),
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: titleSize,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        if (jobName.trim().isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            jobName.trim().toUpperCase(),
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: compact ? 9 : 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
        if (showPointList) ...[
          pw.SizedBox(height: 14),
          _PointsTable(points: points),
        ],
        pw.SizedBox(height: showPointList ? 16 : 18),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 48, height: 52, child: _NorthArrow()),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.Column(
                children: [
                  _GraphicScale(scaleFtPerInch: scaleFtPerInch),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'GRAPHIC SCALE: 1" = $scaleInt\'',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: compact ? 8 : 10,
                      fontWeight: pw.FontWeight.bold,
                      font: pw.Font.timesBold(),
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    '($sheetCallout)',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(fontSize: compact ? 7 : 8),
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '${points.length} point${points.length == 1 ? "" : "s"}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: compact ? 8 : 9),
        ),
        pw.Spacer(),
        pw.Text(
          _noteText,
          style: pw.TextStyle(
            fontSize: compact ? 6.2 : 7.2,
            lineSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          _trioAddress,
          style: pw.TextStyle(
            fontSize: compact ? 7 : 8,
            lineSpacing: 1.3,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'DATE:  $dateStr',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(
            fontSize: compact ? 9 : 11,
            fontWeight: pw.FontWeight.bold,
            font: pw.Font.courierBold(),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'PAGE 1 OF 1',
          textAlign: pw.TextAlign.right,
          style: pw.TextStyle(fontSize: compact ? 8 : 9),
        ),
      ],
    );
  }
}

class _PointsTable extends pw.StatelessWidget {
  _PointsTable({required this.points});

  final List<SurveyPoint> points;

  @override
  pw.Widget build(pw.Context context) {
    final n = points.length;
    final fs = n > 18 ? 6.5 : (n > 12 ? 7.5 : 8.5);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          alignment: pw.Alignment.center,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.9, color: PdfColors.black),
          ),
          child: pw.Text(
            'CONTROL POINTS',
            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(width: 0.9, color: PdfColors.black),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.1),
            1: pw.FlexColumnWidth(1.6),
            2: pw.FlexColumnWidth(1.2),
            3: pw.FlexColumnWidth(1.6),
            4: pw.FlexColumnWidth(1.6),
          },
          children: [
            pw.TableRow(
              children: [
                for (final h in [
                  'Point #',
                  'Description',
                  'Elevation',
                  'Northing',
                  'Easting',
                ])
                  _cell(h, fs: fs, bold: true),
              ],
            ),
            for (final p in points)
              pw.TableRow(
                children: [
                  _cell(p.id, fs: fs),
                  _cell(p.description.toUpperCase(), fs: fs),
                  _cell(p.elevText, fs: fs),
                  _cell(p.northingText, fs: fs),
                  _cell(p.eastingText, fs: fs),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _cell(String text, {required double fs, bool bold = false}) {
    return pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 2.5),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: fs,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }
}

class _NorthArrow extends pw.StatelessWidget {
  @override
  pw.Widget build(pw.Context context) {
    final font = pw.Font.helveticaBold().getFont(context);
    return pw.CustomPaint(
      size: const PdfPoint(50, 54),
      painter: (canvas, size) {
        final cx = size.x / 2;
        canvas
          ..setFillColor(PdfColors.black)
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(1)
          ..moveTo(cx, size.y - 6)
          ..lineTo(cx - 8, size.y - 30)
          ..lineTo(cx, size.y - 24)
          ..lineTo(cx + 8, size.y - 30)
          ..closePath()
          ..fillPath()
          ..setLineWidth(1.2)
          ..drawLine(cx, size.y - 24, cx, size.y - 44)
          ..strokePath();
        canvas.drawString(font, 9, 'N', cx - 3.5, 6);
      },
    );
  }
}

class _GraphicScale extends pw.StatelessWidget {
  _GraphicScale({required this.scaleFtPerInch});

  final double scaleFtPerInch;

  @override
  pw.Widget build(pw.Context context) {
    final major = scaleFtPerInch;
    final font = pw.Font.helveticaBold().getFont(context);
    return pw.SizedBox(
      height: 36,
      child: pw.CustomPaint(
        size: const PdfPoint(220, 36),
        painter: (canvas, size) {
          final y = size.y - 14;
          final x0 = 8.0;
          final x1 = size.x - 8;
          final mid = (x0 + x1) / 2;
          canvas
            ..setStrokeColor(PdfColors.black)
            ..setLineWidth(1.2)
            ..drawLine(x0, y, x1, y)
            ..drawLine(x0, y - 6, x0, y + 6)
            ..drawLine(mid, y - 5, mid, y + 5)
            ..drawLine(x1, y - 6, x1, y + 6)
            ..strokePath()
            ..drawString(font, 8, '0', x0 - 2, 4)
            ..drawString(font, 8, '${major.round()}', mid - 10, 4)
            ..drawString(font, 8, '${(major * 2).round()}', x1 - 16, 4);
        },
      ),
    );
  }
}
