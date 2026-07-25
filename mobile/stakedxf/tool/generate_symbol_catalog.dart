/// Single-page PDF catalog of every StakeDXF plot object library symbol.
///
/// Run from mobile/stakedxf:
///   dart run tool/generate_symbol_catalog.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:stakedxf/points/plot_symbols.dart';
import 'package:stakedxf/points/symbol_draw.dart';
import 'package:vector_math/vector_math_64.dart';

Future<void> main() async {
  final root = Directory.current.path;
  final outPath = p.normalize(
    p.join(root, '../../dist/symbol_library/StakeDXF_Object_Library.pdf'),
  );
  Directory(p.dirname(outPath)).createSync(recursive: true);

  final kinds = PlotSymbolKind.values;
  final byCategory = <PlotSymbolCategory, List<PlotSymbolKind>>{
    for (final cat in PlotSymbolCategory.values) cat: symbolsInCategory(cat),
  };

  // ANSI B landscape — one sheet, all symbols.
  final pageFormat = const PdfPageFormat(
    17 * PdfPageFormat.inch,
    11 * PdfPageFormat.inch,
    marginAll: 0,
  );

  final doc = pw.Document(
    title: 'StakeDXF Object Library',
    author: 'StakeDXF',
  );

  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) {
        final titlePdf = pw.Font.helveticaBold().getFont(context);
        final bodyPdf = pw.Font.helvetica().getFont(context);
        final smallPdf = pw.Font.helveticaOblique().getFont(context);

        return pw.Padding(
          padding: const pw.EdgeInsets.all(28),
          child: pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.2, color: PdfColors.black),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'STAKEDXF OBJECT LIBRARY',
                              style: pw.TextStyle(
                                font: pw.Font.helveticaBold(),
                                fontSize: 18,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Plan-view symbols extracted from Three Pillars Phase 1C '
                              'civil details & signage (C7.00-C7.03, C6.11, C3.0).  '
                              '${kinds.length} objects - place / move / scale / rotate / recolor on staking plots.',
                              style: pw.TextStyle(
                                font: pw.Font.helvetica(),
                                fontSize: 8.5,
                                color: PdfColors.grey800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.Text(
                        'v1.7  -  ${kinds.length} symbols',
                        style: pw.TextStyle(
                          font: pw.Font.helveticaOblique(),
                          fontSize: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(height: 1, color: PdfColors.black),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: pw.LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints?.maxWidth ?? 1100;
                        final h = constraints?.maxHeight ?? 650;
                        return pw.CustomPaint(
                          size: PdfPoint(w, h),
                          painter: (canvas, size) => _paintCatalog(
                            canvas,
                            size,
                            byCategory,
                            titlePdf,
                            bodyPdf,
                            smallPdf,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                pw.Container(height: 0.8, color: PdfColors.black),
                pw.Padding(
                  padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: pw.Text(
                    'Source sheets: C7.00-C7.03 DETAILS | C6.11 SIGNAGE PLAN | C3.0 EROSION CONTROL  |  '
                    'In app: Export Points > Plot objects > Add from object library',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaOblique(),
                      fontSize: 7.5,
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

  final bytes = await doc.save();
  await File(outPath).writeAsBytes(bytes, flush: true);
  stdout.writeln(
    'Wrote $outPath (${bytes.length} bytes, ${kinds.length} symbols)',
  );
}

void _paintCatalog(
  PdfGraphics canvas,
  PdfPoint size,
  Map<PlotSymbolCategory, List<PlotSymbolKind>> byCategory,
  PdfFont titleFont,
  PdfFont bodyFont,
  PdfFont smallFont,
) {
  const cols = 6;
  final categories = PlotSymbolCategory.values;

  // Layout budget: header rows are shorter than symbol rows.
  var symbolRows = 0;
  for (final cat in categories) {
    final n = byCategory[cat]!.length;
    symbolRows += (n + cols - 1) ~/ cols;
  }
  const headerH = 16.0;
  final available = size.y - categories.length * headerH - 8;
  final cellH = math.min(72.0, available / symbolRows);
  final cellW = size.x / cols;
  final symbolHalf = math.min(cellW, cellH) * 0.24;

  var y = size.y - 2.0;

  for (final cat in categories) {
    final kinds = byCategory[cat]!;
    y -= headerH;
    canvas
      ..setFillColor(const PdfColor.fromInt(0xFFE4572E))
      ..drawString(titleFont, 9, cat.label.toUpperCase(), 4, y + 4);
    canvas
      ..setStrokeColor(const PdfColor.fromInt(0xFFCCCCCC))
      ..setLineWidth(0.5)
      ..drawLine(4, y - 1, size.x - 4, y - 1)
      ..strokePath();

    for (var i = 0; i < kinds.length; i++) {
      final col = i % cols;
      if (col == 0) {
        y -= cellH;
      }
      final kind = kinds[i];
      final cx = col * cellW + cellW / 2;
      final cy = y + cellH * 0.58;

      canvas
        ..setStrokeColor(const PdfColor.fromInt(0xFFDDDDDD))
        ..setLineWidth(0.4)
        ..drawRect(col * cellW + 3, y + 3, cellW - 6, cellH - 5)
        ..strokePath();

      canvas.saveContext();
      canvas.setTransform(Matrix4.identity()..translate(cx, cy));
      drawSymbolKind(
        canvas,
        kind,
        symbolHalf,
        const PdfColor.fromInt(0xFF1A1A1A),
      );
      canvas.restoreContext();

      final labelY = y + 13;
      _drawCentered(
        canvas,
        bodyFont,
        6.5,
        kind.label,
        cx,
        labelY,
        const PdfColor.fromInt(0xFF222222),
      );
      _drawCentered(
        canvas,
        smallFont,
        5.0,
        kind.source,
        cx,
        labelY - 8,
        const PdfColor.fromInt(0xFF666666),
      );
    }
    y -= 1;
  }
}

void _drawCentered(
  PdfGraphics canvas,
  PdfFont font,
  double size,
  String text,
  double cx,
  double y,
  PdfColor color,
) {
  // Helvetica built-in fonts are WinAnsi — strip non-ASCII.
  final safe = text
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('·', '-')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  final approxW = safe.length * size * 0.42;
  canvas
    ..setFillColor(color)
    ..drawString(font, size, safe, cx - approxW / 2, y);
}
