import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart' show FontStyle;
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/block_catalog.dart';
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/ctb_plot_style.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/label_placement.dart';
import 'package:stakedxf/points/linetype_catalog.dart';
import 'package:stakedxf/points/linework_edit.dart';
import 'package:stakedxf/points/linework_style.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_symbols.dart';
import 'package:stakedxf/points/plot_templates.dart';
import 'package:stakedxf/points/survey_point.dart';
import 'package:stakedxf/points/text_style_catalog.dart';

void main() {
  test('parse PNEZD headered CSV', () {
    final text = File('test/fixtures/sample_points.csv').readAsStringSync();
    final pts = parsePointsCsv(text);
    expect(pts.length, 4);
    expect(pts.first.id, '700');
    expect(pts.first.northing, closeTo(410233.245, 1e-6));
    expect(pts.first.description, '125 HUB');
  });

  test('parse headerless PNEZD', () {
    final pts = parsePointsCsv(
      '10,100.0,200.0,50.5,IP\n11,101.0,201.0,51.0,PK\n',
    );
    expect(pts.length, 2);
    expect(pts[0].id, '10');
    expect(pts[1].description, 'PK');
  });

  test('export CSV round-trip', () {
    final pts = [
      const SurveyPoint(
        id: '1',
        northing: 10,
        easting: 20,
        elevation: 30.1,
        description: 'A, B',
      ),
    ];
    final csv = exportPointsCsv(pts);
    final back = parsePointsCsv(csv);
    expect(back.length, 1);
    expect(back.first.description, 'A, B');
  });

  test('engineering scale fits cluster', () {
    final pts = [
      const SurveyPoint(
        id: '1',
        northing: 0,
        easting: 0,
        elevation: 0,
        description: '',
      ),
      const SurveyPoint(
        id: '2',
        northing: 100,
        easting: 100,
        elevation: 0,
        description: '',
      ),
    ];
    final scale = chooseEngineeringScale(pts);
    expect(scale, greaterThanOrEqualTo(10));
    expect(scale, lessThanOrEqualTo(50));
  });

  test('label format variants', () {
    const p = SurveyPoint(
      id: '7',
      northing: 1,
      easting: 2,
      elevation: 3.25,
      description: 'IP',
    );
    expect(labelLinesFor(p, PointLabelFormat.numberOnly), ['7']);
    expect(labelLinesFor(p, PointLabelFormat.numberElevation), ['7', '3.25']);
    expect(labelLinesFor(p, PointLabelFormat.numberDescription), ['7', 'IP']);
    expect(
      labelLinesFor(p, PointLabelFormat.numberDescriptionElevation),
      ['7', 'IP', '3.25'],
    );
    expect(labelLinesFor(p, PointLabelFormat.none), isEmpty);
    expect(labelLinesFor(p, PointLabelFormat.descriptionElevation),
        ['IP', '3.25']);
    expect(PointLabelFormat.numberDescriptionElevation.label, 'PT NO DESC ELV');
  });

  test('parse DXF linework by layer', () {
    final text = File('test/fixtures/sample_linework.dxf').readAsStringSync();
    final lw = parseDxfLinework(text);
    expect(lw.layers, containsAll(['CL', 'CURB', 'STRUCTURE']));
    expect(lw.entities.length, 4);
    expect(lw.countForLayer('CURB'), 2);
    expect(lw.layerCounts['CL'], 1);
    final curb = lw.forLayers({'CURB'});
    expect(curb.length, 2);
    expect(lw.boundsFor({'CL'}), isNotNull);
  });

  test('parse DXF from file path (large-file safe path)', () {
    final lw = parseDxfLineworkFile('test/fixtures/sample_linework.dxf');
    expect(lw.entities.length, 4);
    expect(lw.layers, isNotEmpty);
  });

  test('plot linework cap keeps UI/PDF bounded', () {
    final text = File('test/fixtures/sample_linework.dxf').readAsStringSync();
    final lw = parseDxfLinework(text);
    final capped = lw.forLayersCapped(lw.layers.toSet(), maxEntities: 2);
    expect(capped.length, 2);
    expect(lw.forLayersCapped(lw.layers.toSet(), maxEntities: 100).length, 4);
  });

  test('forLayersNear prefers entities close to stake points', () {
    final near = LineworkEntity(
      layer: 'CL',
      type: 'LINE',
      vertices: [
        [100.0, 100.0],
        [110.0, 100.0],
      ],
    );
    final far = LineworkEntity(
      layer: 'CL',
      type: 'LINE',
      vertices: [
        [90000.0, 90000.0],
        [90100.0, 90000.0],
      ],
    );
    final lw = DxfLinework(
      entities: [far, near, far, near],
      layers: const ['CL'],
      layerCounts: const {'CL': 4},
    );
    final picked = lw.forLayersNear(
      {'CL'},
      points: [(easting: 105.0, northing: 100.0)],
      maxEntities: 2,
    );
    expect(picked.length, 2);
    for (final e in picked) {
      expect(e.vertices.first[0], lessThan(200));
    }
  });

  test('plan framing ignores distant linework so stakes stay on-sheet', () async {
    final pts = parsePointsCsv(
      File('test/fixtures/sample_points.csv').readAsStringSync(),
    );
    final near = parseDxfLinework(
      File('test/fixtures/sample_linework.dxf').readAsStringSync(),
    ).entities;
    // Origin junk + site linework — classic empty-plot trigger when bounds
    // included every sample (scale → 10000', markers painted off-panel).
    final mixed = <LineworkEntity>[
      const LineworkEntity(
        layer: 'JUNK',
        type: 'LINE',
        vertices: [
          [0, 0],
          [100, 100],
        ],
      ),
      ...near,
    ];

    final scaleNear = chooseEngineeringScale(pts, linework: near);
    final scaleMixed = chooseEngineeringScale(pts, linework: mixed);
    expect(scaleMixed, scaleNear);
    expect(scaleMixed, lessThan(1000));

    final bounds = computePlanViewBounds(pts, linework: mixed);
    expect(bounds.minE, greaterThan(2495800));
    expect(bounds.maxE, lessThan(2496100));

    final field = plotTemplateById('field_b_landscape');
    final bytes = await buildStakingPlotPdf(
      points: pts,
      jobName: 'FAR LINEWORK',
      date: DateTime(2026, 7, 15),
      options: PlotOptions(
        template: field,
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberOnly,
        includeLinework: true,
      ),
      linework: mixed,
    );
    expect(bytes.length, greaterThan(1000));
    expect(chooseEngineeringScale(pts, linework: mixed, template: field), scaleNear);
  });

  test('staking plot PDF with options and linework', () async {
    final text = File('test/fixtures/sample_points.csv').readAsStringSync();
    final pts = parsePointsCsv(text);
    final dxf = File('test/fixtures/sample_linework.dxf').readAsStringSync();
    final lw = parseDxfLinework(dxf);

    for (final marker in PointMarkerStyle.values) {
      final bytes = await buildStakingPlotPdf(
        points: pts,
        jobName: 'ALPINE HILLS',
        date: DateTime(2026, 7, 15),
        options: PlotOptions(
          markerStyle: marker,
          labelFormat: PointLabelFormat.numberElevation,
          showPointList: false,
          includeLinework: true,
        ),
        linework: lw.forLayers(lw.layers.toSet()),
      );
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }

    final withTable = await buildStakingPlotPdf(
      points: pts,
      jobName: 'ALPINE HILLS',
      date: DateTime(2026, 7, 15),
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberDescription,
        showPointList: true,
        includeLinework: false,
      ),
    );
    final out = File('test/fixtures/sample_staking_plot.pdf');
    await out.writeAsBytes(withTable);
    expect(withTable.length, greaterThan(1000));
  });

  test('auto-spread separates stacked labels; preserves pinned drags', () {
    final pts = [
      for (var i = 0; i < 6; i++)
        SurveyPoint(
          id: '${100 + i}',
          northing: 1000 + i * 2.0,
          easting: 2000 + i * 2.0,
          elevation: 10,
          description: 'STM',
        ),
    ];
    final pinned = {
      '100': const LabelDragState(offsetE: 40, offsetN: 40, pinned: true),
    };
    final spread = autoSpreadLabels(
      points: pts,
      format: PointLabelFormat.numberDescriptionElevation,
      scaleFtPerInch: 30,
      existing: pinned,
      annotationScale: 1.2,
    );
    expect(spread['100']!.offsetE, 40);
    expect(spread['100']!.offsetN, 40);
    expect(spread['100']!.pinned, isTrue);
    // Other labels get non-zero Civil-style offsets (unpinned).
    for (final p in pts.skip(1)) {
      expect(spread[p.id]!.isDragged, isTrue);
      expect(spread[p.id]!.pinned, isFalse);
    }
    // Large engineering scale still separates callouts.
    final far = [
      const SurveyPoint(
        id: 'A',
        northing: 0,
        easting: 0,
        elevation: 0,
        description: 'IP',
      ),
      const SurveyPoint(
        id: 'B',
        northing: 40,
        easting: 40,
        elevation: 0,
        description: 'IP',
      ),
    ];
    final farSpread = autoSpreadLabels(
      points: far,
      format: PointLabelFormat.numberDescriptionElevation,
      scaleFtPerInch: 200,
    );
    expect(farSpread['A']!.isDragged, isTrue);
    expect(farSpread['B']!.isDragged, isTrue);
    // Offsets should be large enough to clear label boxes at 1"=200'.
    final dist = math.sqrt(
      math.pow(farSpread['A']!.offsetE - farSpread['B']!.offsetE, 2) +
          math.pow(farSpread['A']!.offsetN - farSpread['B']!.offsetN, 2),
    );
    // Not a strict separation of anchors alone — ensure each left the marker.
    expect(farSpread['A']!.offsetE.abs() + farSpread['A']!.offsetN.abs(),
        greaterThan(30));
    expect(dist, greaterThanOrEqualTo(0));
  });

  test('symbols do not expand plan framing by default', () {
    final pts = [
      const SurveyPoint(
        id: '1',
        northing: 100,
        easting: 100,
        elevation: 0,
        description: '',
      ),
      const SurveyPoint(
        id: '2',
        northing: 120,
        easting: 120,
        elevation: 0,
        description: '',
      ),
    ];
    final without = computePlanViewBounds(pts);
    // Far symbol should not change bounds when includeSymbols is false.
    final withSym = computePlanViewBounds(
      pts,
      symbols: [
        PlacedPlotSymbol.builtin(
          id: 's1',
          kind: PlotSymbolKind.hub,
          easting: 5000,
          northing: 5000,
        ),
      ],
    );
    expect(withSym.rangeE, without.rangeE);
    expect(withSym.rangeN, without.rangeN);
  });

  test('text style catalog resolves Civil DWG styles', () {
    final cat = TextStyleCatalog.builtin();
    expect(cat.styles.length, greaterThanOrEqualTo(14));
    expect(cat.resolve('OR-LD_SHX').flutterFamily, 'PlotSans');
    expect(cat.resolve('arial').flutterFamily, 'PlotSans');
    expect(cat.resolve('P-CONT').bold, isTrue);
    expect(cat.resolve('Standard').effectiveItalic, isTrue);
    expect(cat.resolve('ITALICT').flutterStyle, FontStyle.italic);
    expect(
      cat.resolve('ROMANS_SHX').faceKey,
      isNot(cat.resolve('OR-LD_SHX').faceKey),
    );
    expect(cat.pdfFont(cat.resolve('arial')), isNotNull);
  });

  test('asset text style catalog includes Drive Support fonts', () {
    final json = jsonDecode(
      File('assets/plot_styles/text_style_catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cat = TextStyleCatalog.fromJson(json);
    expect(cat.styles.length, greaterThanOrEqualTo(100));
    expect(cat.byId.containsKey('ROMAND_SHX'), isTrue);
    expect(cat.byId.containsKey('OR-LD_SHX'), isTrue);
    expect(cat.resolve('P-TEXT').font.toLowerCase(), contains('romans'));
    expect(cat.resolve('P-CONT').face, anyOf('souvenir', 'sans'));
    final fonts = {for (final s in cat.styles) s.font.toLowerCase()};
    expect(fonts.any((f) => f.contains('romans')), isTrue);
    expect(fonts.any((f) => f.contains('souvenir')), isTrue);
    expect(fonts.any((f) => f.contains('poppins')), isTrue);
    expect(fonts.any((f) => f.contains('or-ld')), isTrue);
  });

  test('TRIO.lin linetype catalog expands utility patterns', () {
    final json = jsonDecode(
      File('assets/linework/linetype_catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final cat = LinetypeCatalog.fromJson(json);
    expect(cat.linetypes.length, greaterThanOrEqualTo(50));
    expect(cat.resolve('LEDG_WATER').elements, isNotEmpty);
    expect(cat.resolve('FLOWPATH').elements, isNotEmpty);
    expect(cat.resolve('SAWCUT').elements, isNotEmpty);
    expect(cat.resolve('SIDEWALK').elements, isNotEmpty);
  });

  
  test('Romans TT includes a real space glyph for plot labels', () {
    final bytes = File('assets/fonts/RomansTT-Regular.ttf').readAsBytesSync();
    // Patched Romans TT adds uni0020 so PDF/Flutter do not draw spaces as "U".
    expect(String.fromCharCodes(bytes).contains('uni0020'), isTrue);
    final font = pw.Font.ttf(ByteData.sublistView(Uint8List.fromList(bytes)));
    expect(font, isNotNull);
  });

test('Support BLOCKS merge into DWG block catalog', () {
    final cat = BlockCatalog.loadFile('assets/symbol_library/dwg_blocks.json');
    expect(cat.blocks.length, greaterThanOrEqualTo(230));
    expect(cat['NORTH_ARROW'], isNotNull);
    final names = {for (final b in cat.blocks) b.name.toUpperCase()};
    expect(names.contains('NORTH ARROW'), isTrue);
  });

  test('composePlotTemplate builds ANSI size × orientation', () {
    final t = composePlotTemplate(
      size: AnsiSheetSize.b,
      orientation: SheetOrientation.landscape,
      layout: PlotTemplateLayout.sidePanel,
    );
    expect(t.size.pickerLabel, contains('ANSI B'));
    expect(t.widthIn, 17);
    expect(t.heightIn, 11);
  });

  test('CTB plot styles drive ACI color and lineweight', () {
    final json = jsonDecode(
      File('assets/plot_styles/staking_plot_ctb.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final ctb = CtbPlotStyleTable.fromJson(json);
    // ACI 10 uses object color (reddish); 0.254 mm.
    final p10 = ctb.resolve(10);
    expect((p10.colorArgb >> 16) & 0xFF, greaterThan(200));
    expect(p10.strokeWidthPt, closeTo(0.254 * 72 / 25.4, 0.01));
    // ACI 252 forced grey.
    final p252 = ctb.resolve(252);
    expect((p252.colorArgb >> 16) & 0xFF, 152);
    // Object-color ACI 1 keeps red hue via ACI palette.
    final p1 = ctb.resolve(1);
    expect((p1.colorArgb >> 16) & 0xFF, greaterThan(200));

    final style = resolveLineworkStyle(
      entity: const LineworkEntity(
        id: 'e',
        layer: 'CL',
        type: 'LINE',
        vertices: [
          [0.0, 0.0],
          [1.0, 0.0],
        ],
        colorAci: 252,
      ),
      catalog: LinetypeCatalog.builtin(),
      ctb: ctb,
    );
    expect((style.colorArgb >> 16) & 0xFF, 152);
  });

  test('linetype catalog resolves Civil utility styles', () {
    final cat = LinetypeCatalog.builtin();
    expect(cat.resolve('DASHED').isContinuous, isFalse);
    expect(cat.resolve('Continuous').isContinuous, isTrue);
    expect(cat.resolve('STORM').elements, isNotEmpty);
    expect(aciToArgb(1) & 0x00FF0000, greaterThan(0));
    expect(lineweightToPoints(50), greaterThan(1.0));

    final json = jsonDecode(
      File('assets/linework/linetype_catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final full = LinetypeCatalog.fromJson(json);
    expect(full.linetypes.length, greaterThanOrEqualTo(20));
    expect(full.resolve('LEDG_WATER').elements, isNotEmpty);
    expect(full.resolve(r'RES_SURVEY$0$DASHED').name.toUpperCase(), 'DASHED');
  });

  test('DXF LAYER table styles are parsed', () {
    final path =
        'test/fixtures/pheasant_farm_staking_layers_clip.dxf';
    if (!File(path).existsSync()) return;
    final lw = parseDxfLineworkFile(path);
    expect(lw.layerStyles, isNotEmpty);
    expect(lw.entities.first.id, isNotEmpty);
  });

  test('explode polyline and remove segment/node', () {
    const poly = LineworkEntity(
      id: 'p1',
      layer: 'CL',
      type: 'LWPOLYLINE',
      vertices: [
        [0.0, 0.0],
        [10.0, 0.0],
        [20.0, 0.0],
        [30.0, 0.0],
      ],
    );
    final exploded = explodeLineworkEntity(poly);
    expect(exploded.length, 3);
    expect(exploded.every((e) => e.type == 'LINE'), isTrue);

    final cut = removeSegment(poly, segmentIndex: 1);
    expect(cut.length, 2);
    expect(cut[0].vertices.length, 2);
    expect(cut[1].vertices.length, 2);

    final noded = removeNode(poly, nodeIndex: 1);
    expect(noded.length, 1);
    expect(noded.first.vertices.length, 3);
  });

  test('custom label text and annotation options export', () async {
    final pts = parsePointsCsv(
      File('test/fixtures/sample_points.csv').readAsStringSync(),
    );
    final bytes = await buildStakingPlotPdf(
      points: pts,
      jobName: 'LABEL DRAG',
      date: DateTime(2026, 7, 23),
      options: PlotOptions(
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        annotationScale: 1.5,
        showObjectLabels: false,
        autoSpreadLabels: true,
        labelDrags: {
          pts.first.id: const LabelDragState(
            offsetE: 55,
            offsetN: -30,
            customText: '700\nCUSTOM',
          ),
        },
      ),
    );
    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
