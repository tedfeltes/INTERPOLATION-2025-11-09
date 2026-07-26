/// PDF catalog of every StakeDXF plot object (built-in + extracted DWG blocks).
///
/// Run from mobile/stakedxf:
///   dart run tool/generate_symbol_catalog.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:stakedxf/points/block_catalog.dart';
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
    for (final cat in PlotSymbolCategory.values)
      if (cat != PlotSymbolCategory.dwgBlocks) cat: symbolsInCategory(cat),
  };
  final blocks = BlockCatalog.loadFile(
    p.join(root, 'assets/symbol_library/dwg_blocks.json'),
  ).sorted;

  const pageFormat = PdfPageFormat(
    17 * PdfPageFormat.inch,
    11 * PdfPageFormat.inch,
    marginAll: 0,
  );

  final doc = pw.Document(
    title: 'StakeDXF Object Library',
    author: 'StakeDXF',
  );

  // Page 1 — built-in symbols
  doc.addPage(
    pw.Page(
      pageFormat: pageFormat,
      build: (context) {
        final titlePdf = pw.Font.helveticaBold().getFont(context);
        final bodyPdf = pw.Font.helvetica().getFont(context);
        final smallPdf = pw.Font.helveticaOblique().getFont(context);
        return _framedPage(
          headerTitle: 'STAKEDXF OBJECT LIBRARY',
          headerSub:
              'Built-in plan-view symbols from Three Pillars civil details & signage '
              '(C7.00-C7.03, C6.11, C3.0).  ${kinds.length} built-in + ${blocks.length} DWG blocks.',
          headerRight: 'v1.9  -  page 1  -  ${kinds.length} built-in',
          footer:
              'Page 1 of built-in symbols  |  following pages: DWG blocks + folder symbols  |  '
              'Export Points > Plot objects > Add from object library',
          child: pw.LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints?.maxWidth ?? 1100;
              final h = constraints?.maxHeight ?? 650;
              return pw.CustomPaint(
                size: PdfPoint(w, h),
                painter: (canvas, size) => _paintBuiltinCatalog(
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
        );
      },
    ),
  );

  // DWG block pages — dense grid
  const cols = 8;
  const rowsPerPage = 6;
  final perPage = cols * rowsPerPage;
  final pageCount = (blocks.length + perPage - 1) ~/ perPage;
  for (var pageIndex = 0; pageIndex < pageCount; pageIndex++) {
    final slice = blocks.skip(pageIndex * perPage).take(perPage).toList();
    final pageNo = pageIndex + 2;
    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) {
          final titlePdf = pw.Font.helveticaBold().getFont(context);
          final bodyPdf = pw.Font.helvetica().getFont(context);
          final smallPdf = pw.Font.helveticaOblique().getFont(context);
          return _framedPage(
            headerTitle: 'STAKEDXF OBJECT LIBRARY - DWG BLOCKS',
            headerSub:
                'Named BLOCKs from the project DWG plus individual symbol DWGs '
                '(Drive folder 1BpM_…).  ${blocks.length} objects total.',
            headerRight:
                'v1.9  -  page $pageNo  -  ${slice.length} of ${blocks.length}',
            footer:
                'DWG / symbol page ${pageIndex + 1}/$pageCount  |  '
                'Filter/search in app under Plot objects > DWG blocks',
            child: pw.LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints?.maxWidth ?? 1100;
                final h = constraints?.maxHeight ?? 650;
                return pw.CustomPaint(
                  size: PdfPoint(w, h),
                  painter: (canvas, size) => _paintBlockCatalog(
                    canvas,
                    size,
                    slice,
                    titlePdf,
                    bodyPdf,
                    smallPdf,
                    cols: cols,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  final bytes = await doc.save();
  await File(outPath).writeAsBytes(bytes, flush: true);
  stdout.writeln(
    'Wrote $outPath (${bytes.length} bytes, '
    '${kinds.length} built-in + ${blocks.length} DWG blocks, '
    '${1 + pageCount} pages)',
  );

  // Copy JSON next to catalog for distribution
  final jsonSrc = File(p.join(root, 'assets/symbol_library/dwg_blocks.json'));
  final jsonDst = File(
    p.join(root, '../../dist/symbol_library/dwg_blocks.json'),
  );
  jsonDst.writeAsBytesSync(jsonSrc.readAsBytesSync());
  stdout.writeln('Copied ${jsonDst.path}');
}

pw.Widget _framedPage({
  required String headerTitle,
  required String headerSub,
  required String headerRight,
  required String footer,
  required pw.Widget child,
}) {
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
                        headerTitle,
                        style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 16,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        headerSub,
                        style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: 8,
                          color: PdfColors.grey800,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  headerRight,
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
              child: child,
            ),
          ),
          pw.Container(height: 0.8, color: PdfColors.black),
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: pw.Text(
              footer,
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
}

void _paintBuiltinCatalog(
  PdfGraphics canvas,
  PdfPoint size,
  Map<PlotSymbolCategory, List<PlotSymbolKind>> byCategory,
  PdfFont titleFont,
  PdfFont bodyFont,
  PdfFont smallFont,
) {
  const cols = 6;
  final categories = byCategory.keys.toList();
  var symbolRows = 0;
  for (final cat in categories) {
    symbolRows += (byCategory[cat]!.length + cols - 1) ~/ cols;
  }
  const headerH = 16.0;
  final available = size.y - categories.length * headerH - 8;
  final cellH = math.min(72.0, available / symbolRows);
  final cellW = size.x / cols;
  final symbolHalf = math.min(cellW, cellH) * 0.24;
  var y = size.y - 2.0;

  for (final cat in categories) {
    final list = byCategory[cat]!;
    y -= headerH;
    canvas
      ..setFillColor(const PdfColor.fromInt(0xFFE4572E))
      ..drawString(titleFont, 9, cat.label.toUpperCase(), 4, y + 4);
    canvas
      ..setStrokeColor(const PdfColor.fromInt(0xFFCCCCCC))
      ..setLineWidth(0.5)
      ..drawLine(4, y - 1, size.x - 4, y - 1)
      ..strokePath();

    for (var i = 0; i < list.length; i++) {
      final col = i % cols;
      if (col == 0) y -= cellH;
      final kind = list[i];
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
      _drawCentered(
        canvas,
        bodyFont,
        6.5,
        kind.label,
        cx,
        y + 13,
        const PdfColor.fromInt(0xFF222222),
      );
      _drawCentered(
        canvas,
        smallFont,
        5.0,
        kind.source,
        cx,
        y + 5,
        const PdfColor.fromInt(0xFF666666),
      );
    }
    y -= 1;
  }
}

void _paintBlockCatalog(
  PdfGraphics canvas,
  PdfPoint size,
  List<DwgBlockSymbol> blocks,
  PdfFont titleFont,
  PdfFont bodyFont,
  PdfFont smallFont, {
  required int cols,
}) {
  final cellW = size.x / cols;
  final rows = (blocks.length + cols - 1) ~/ cols;
  final cellH = size.y / math.max(rows, 1);
  final symbolHalf = math.min(cellW, cellH) * 0.28;

  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final col = i % cols;
    final row = i ~/ cols;
    final x0 = col * cellW;
    final y0 = size.y - (row + 1) * cellH;
    final cx = x0 + cellW / 2;
    final cy = y0 + cellH * 0.58;

    canvas
      ..setStrokeColor(const PdfColor.fromInt(0xFFDDDDDD))
      ..setLineWidth(0.4)
      ..drawRect(x0 + 2, y0 + 2, cellW - 4, cellH - 4)
      ..strokePath();

    canvas.saveContext();
    canvas.setTransform(Matrix4.identity()..translate(cx, cy));
    drawBlockSymbol(
      canvas,
      block,
      symbolHalf,
      const PdfColor.fromInt(0xFF1A1A1A),
    );
    canvas.restoreContext();

    _drawCentered(
      canvas,
      bodyFont,
      6.0,
      block.name,
      cx,
      y0 + 12,
      const PdfColor.fromInt(0xFF222222),
    );
    _drawCentered(
      canvas,
      smallFont,
      4.5,
      '${block.pathCount} paths',
      cx,
      y0 + 5,
      const PdfColor.fromInt(0xFF666666),
    );
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
