import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'dxf_linework.dart';
import 'plot_options.dart';
import 'survey_point.dart';

/// ANSI B landscape (17" × 11") — same sheet size as the TRIO control note.
final PdfPageFormat stakingSheet = const PdfPageFormat(
  17 * PdfPageFormat.inch,
  11 * PdfPageFormat.inch,
  marginAll: 0,
);

const _noteText =
    'NOTE: Points shown were established for construction staking. '
    'It is the responsibility of the end user to verify points and '
    'use good survey practices before relying on this plot in the field.';

const _trioAddress =
    'TRIO Engineering, LLC\n'
    '4100 N. Calhoun Rd., Suite 300\n'
    'Brookfield, WI 53005\n'
    '262.790.1480';

const _markerRed = PdfColor.fromInt(0xFFE10600);
const _lineworkColor = PdfColor.fromInt(0xFF1A1A1A);

/// Build a staking plot PDF with user [options].
Future<Uint8List> buildStakingPlotPdf({
  required List<SurveyPoint> points,
  required String jobName,
  DateTime? date,
  String title = 'STAKING PLOT',
  PlotOptions options = const PlotOptions(),
  List<LineworkEntity> linework = const [],
}) async {
  if (points.isEmpty) {
    throw ArgumentError('Select at least one point');
  }

  final when = date ?? DateTime.now();
  final dateStr =
      '${when.month.toString().padLeft(2, '0')}/${when.day.toString().padLeft(2, '0')}/${(when.year % 100).toString().padLeft(2, '0')}';
  final scaleFtPerInch = chooseEngineeringScale(points, linework: linework);
  final doc = pw.Document(
    title: '$title — ${jobName.isEmpty ? "FIELD" : jobName}',
    author: 'StakeDXF',
  );

  final showTable = options.showPointList;
  final plotFlex = showTable ? 58 : 78;
  final sideFlex = showTable ? 42 : 22;

  doc.addPage(
    pw.Page(
      pageFormat: stakingSheet,
      build: (context) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(28),
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
                      linework: options.includeLinework ? linework : const [],
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  return doc.save();
}

/// Pick a standard engineering scale (feet per inch) that fits the content.
double chooseEngineeringScale(
  List<SurveyPoint> points, {
  List<LineworkEntity> linework = const [],
}) {
  var minE = points.first.easting;
  var maxE = points.first.easting;
  var minN = points.first.northing;
  var maxN = points.first.northing;
  for (final p in points) {
    minE = math.min(minE, p.easting);
    maxE = math.max(maxE, p.easting);
    minN = math.min(minN, p.northing);
    maxN = math.max(maxN, p.northing);
  }
  for (final e in linework) {
    for (final p in e.samplePoints) {
      minE = math.min(minE, p[0]);
      maxE = math.max(maxE, p[0]);
      minN = math.min(minN, p[1]);
      maxN = math.max(maxN, p[1]);
    }
  }

  // Wider plot when the point table is omitted (~12" usable width).
  const usableW = 11.5;
  const usableH = 9.6;
  final rangeE = math.max(maxE - minE, 1.0);
  final rangeN = math.max(maxN - minN, 1.0);
  final need = math.max(rangeE / usableW, rangeN / usableH) * 1.12;
  const standards = <double>[
    10, 20, 30, 40, 50, 60, 80, 100, 200, 300, 400, 500, 600, 800, 1000,
    1200, 1500, 2000, 2500, 3000, 4000, 5000, 6000, 8000, 10000,
  ];
  for (final s in standards) {
    if (s >= need) return s;
  }
  return standards.last;
}

List<String> labelLinesFor(SurveyPoint p, PointLabelFormat format) {
  switch (format) {
    case PointLabelFormat.none:
      return const [];
    case PointLabelFormat.numberOnly:
      return [p.id];
    case PointLabelFormat.numberDescription:
      return [
        p.id,
        if (p.description.trim().isNotEmpty) p.description.trim().toUpperCase(),
      ];
    case PointLabelFormat.numberElevation:
      return [p.id, p.elevText];
    case PointLabelFormat.numberDescriptionElevation:
      return [
        p.id,
        if (p.description.trim().isNotEmpty) p.description.trim().toUpperCase(),
        p.elevText,
      ];
  }
}

class _PlanPanel extends pw.StatelessWidget {
  _PlanPanel({
    required this.points,
    required this.scaleFtPerInch,
    required this.options,
    required this.linework,
  });

  final List<SurveyPoint> points;
  final double scaleFtPerInch;
  final PlotOptions options;
  final List<LineworkEntity> linework;

  @override
  pw.Widget build(pw.Context context) {
    final labelFont = pw.Font.helveticaBoldOblique().getFont(context);
    return pw.LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints?.maxWidth ?? 500;
        final h = constraints?.maxHeight ?? 600;
        return pw.Container(
          width: w,
          height: h,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 0.8, color: PdfColors.grey700),
            color: const PdfColor.fromInt(0xFFF7F4EE),
          ),
          child: pw.CustomPaint(
            size: PdfPoint(w, h),
            painter: (canvas, size) => _paintPlan(
              canvas,
              size,
              points,
              scaleFtPerInch,
              labelFont,
              options,
              linework,
            ),
          ),
        );
      },
    );
  }
}

void _paintPlan(
  PdfGraphics canvas,
  PdfPoint size,
  List<SurveyPoint> points,
  double scaleFtPerInch,
  PdfFont labelFont,
  PlotOptions options,
  List<LineworkEntity> linework,
) {
  var minE = points.first.easting;
  var maxE = points.first.easting;
  var minN = points.first.northing;
  var maxN = points.first.northing;
  for (final p in points) {
    minE = math.min(minE, p.easting);
    maxE = math.max(maxE, p.easting);
    minN = math.min(minN, p.northing);
    maxN = math.max(maxN, p.northing);
  }
  for (final e in linework) {
    for (final p in e.samplePoints) {
      minE = math.min(minE, p[0]);
      maxE = math.max(maxE, p[0]);
      minN = math.min(minN, p[1]);
      maxN = math.max(maxN, p[1]);
    }
  }

  final midE = (minE + maxE) / 2;
  final midN = (minN + maxN) / 2;
  final ppt = 72.0 / scaleFtPerInch;

  PdfPoint toPage(double e, double n) {
    final x = size.x / 2 + (e - midE) * ppt;
    final y = size.y / 2 + (n - midN) * ppt;
    return PdfPoint(x, y);
  }

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

  // Linework under markers
  canvas
    ..setStrokeColor(_lineworkColor)
    ..setLineWidth(0.7);
  for (final ent in linework) {
    final samples = ent.samplePoints.toList();
    if (samples.length < 2) continue;
    final first = toPage(samples.first[0], samples.first[1]);
    canvas.moveTo(first.x, first.y);
    for (var i = 1; i < samples.length; i++) {
      final pt = toPage(samples[i][0], samples[i][1]);
      canvas.lineTo(pt.x, pt.y);
    }
    if (ent.closed || ent.type == 'CIRCLE') {
      canvas.closePath();
    }
    canvas.strokePath();
  }

  final occupied = <List<double>>[];
  final markerHalf = _markerHalf(options.markerStyle);

  for (final p in points) {
    final c = toPage(p.easting, p.northing);
    _drawMarker(canvas, c, options.markerStyle);
    occupied.add([
      c.x - markerHalf,
      c.y - markerHalf,
      c.x + markerHalf,
      c.y + markerHalf,
    ]);
  }

  for (final p in points) {
    final lines = labelLinesFor(p, options.labelFormat);
    if (lines.isEmpty) continue;
    final c = toPage(p.easting, p.northing);
    final labelW = 62.0;
    final labelH = 10.0 * lines.length;
    final candidates = <PdfPoint>[
      PdfPoint(c.x + markerHalf + 3, c.y - labelH / 2),
      PdfPoint(c.x - markerHalf - 3 - labelW, c.y - labelH / 2),
      PdfPoint(c.x - labelW / 2, c.y + markerHalf + 3),
      PdfPoint(c.x - labelW / 2, c.y - markerHalf - 3 - labelH),
    ];
    PdfPoint chosen = candidates.first;
    for (final cand in candidates) {
      final box = [cand.x, cand.y, cand.x + labelW, cand.y + labelH];
      if (box[0] < 4 ||
          box[1] < 4 ||
          box[2] > size.x - 4 ||
          box[3] > size.y - 4) {
        continue;
      }
      if (occupied.any((o) => _overlap(box, o))) continue;
      chosen = cand;
      occupied.add(box);
      break;
    }

    canvas.setFillColor(_markerRed);
    var ty = chosen.y + labelH - 8;
    for (final line in lines) {
      canvas.drawString(labelFont, 8, line, chosen.x, ty);
      ty -= 9.5;
    }
  }
}

double _markerHalf(PointMarkerStyle style) {
  switch (style) {
    case PointMarkerStyle.largeX:
    case PointMarkerStyle.largeDot:
      return 7.0;
    case PointMarkerStyle.triangleFilled:
    case PointMarkerStyle.triangleOutline:
      return 5.0;
    default:
      return 4.5;
  }
}

void _drawMarker(PdfGraphics canvas, PdfPoint c, PointMarkerStyle style) {
  canvas
    ..setStrokeColor(_markerRed)
    ..setFillColor(_markerRed)
    ..setLineWidth(0.9);

  switch (style) {
    case PointMarkerStyle.triangleFilled:
    case PointMarkerStyle.triangleOutline:
      const triW = 9.0;
      const triH = 8.0;
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
          ..setLineWidth(0.35)
          ..strokePath();
      } else {
        canvas
          ..setLineWidth(0.9)
          ..strokePath();
      }
      break;
    case PointMarkerStyle.cross:
      const s = 5.0;
      canvas
        ..drawLine(c.x - s, c.y, c.x + s, c.y)
        ..drawLine(c.x, c.y - s, c.x, c.y + s)
        ..strokePath();
      break;
    case PointMarkerStyle.x:
      const s = 4.5;
      canvas
        ..drawLine(c.x - s, c.y - s, c.x + s, c.y + s)
        ..drawLine(c.x - s, c.y + s, c.x + s, c.y - s)
        ..strokePath();
      break;
    case PointMarkerStyle.largeX:
      const s = 7.5;
      canvas
        ..setLineWidth(1.4)
        ..drawLine(c.x - s, c.y - s, c.x + s, c.y + s)
        ..drawLine(c.x - s, c.y + s, c.x + s, c.y - s)
        ..strokePath();
      break;
    case PointMarkerStyle.circle:
      canvas
        ..drawEllipse(c.x, c.y, 4.2, 4.2)
        ..strokePath();
      break;
    case PointMarkerStyle.dot:
      canvas
        ..drawEllipse(c.x, c.y, 2.2, 2.2)
        ..fillPath();
      break;
    case PointMarkerStyle.largeDot:
      canvas
        ..drawEllipse(c.x, c.y, 4.0, 4.0)
        ..fillPath();
      break;
  }
}

bool _overlap(List<double> a, List<double> b) {
  return !(a[2] <= b[0] || b[2] <= a[0] || a[3] <= b[1] || b[3] <= a[1]);
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
  });

  final String title;
  final String jobName;
  final List<SurveyPoint> points;
  final double scaleFtPerInch;
  final String dateStr;
  final bool showPointList;
  final bool compact;

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
