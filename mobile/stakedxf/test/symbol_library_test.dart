import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/block_catalog.dart';
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_symbols.dart';

void main() {
  test('symbol catalog covers civil sheet categories', () {
    expect(PlotSymbolKind.values.length, greaterThanOrEqualTo(25));
    for (final cat in PlotSymbolCategory.values) {
      if (cat == PlotSymbolCategory.dwgBlocks) {
        expect(symbolsInCategory(cat), isEmpty);
        continue;
      }
      expect(symbolsInCategory(cat), isNotEmpty, reason: cat.label);
    }
    expect(
      PlotSymbolKind.values.any((k) => k.source.contains('C7.00')),
      isTrue,
    );
    expect(
      PlotSymbolKind.values.any((k) => k.source.contains('C6.11')),
      isTrue,
    );
  });

  test('DWG block catalog loads extracted blocks', () {
    final catalog = BlockCatalog.loadFile(
      'assets/symbol_library/dwg_blocks.json',
    );
    expect(catalog.blocks.length, greaterThanOrEqualTo(200));
    expect(catalog['NORTH ARROW'], isNotNull);
    expect(catalog['EUWHYD'], isNotNull);
    expect(catalog['digger-symbol'], isNotNull);
    // From Drive symbol folder 1BpM_hSs84FBru9tB-ATBgYA79fkG93NF
    expect(catalog['DUMPSTER'], isNotNull);
    expect(catalog['CAR-PLANVIEW'], isNotNull);
    expect(catalog['ARROW-typ'], isNotNull);
    final hyd = catalog['EUWHYD']!;
    expect(hyd.paths, isNotEmpty);
    expect(hyd.paths.first.points.length, greaterThanOrEqualTo(2));
  });

  test('placed symbol copyWith and size', () {
    final s = PlacedPlotSymbol.builtin(
      id: 'a',
      kind: PlotSymbolKind.fireHydrant,
      easting: 100,
      northing: 200,
      scale: 2,
      colorArgb: 0xFFE10600,
    );
    expect(s.sizeFt, PlotSymbolKind.fireHydrant.defaultSizeFt * 2);
    final moved = s.copyWith(easting: 110, rotationDeg: 45);
    expect(moved.easting, 110);
    expect(moved.rotationDeg, 45);
    expect(moved.northing, 200);
  });

  test('staking plot PDF includes builtin and DWG block objects', () async {
    final points = parsePointsCsv(
      File('test/fixtures/sample_points.csv').readAsStringSync(),
    );
    final catalog = BlockCatalog.loadFile(
      'assets/symbol_library/dwg_blocks.json',
    );
    final block = catalog['EUWHYD'] ?? catalog.blocks.first;
    final symbols = [
      PlacedPlotSymbol.builtin(
        id: '1',
        kind: PlotSymbolKind.fireHydrant,
        easting: points.first.easting + 15,
        northing: points.first.northing + 10,
        scale: 1.5,
        colorArgb: 0xFFE10600,
        label: 'FH-1',
      ),
      PlacedPlotSymbol.block(
        id: '2',
        blockId: block.id,
        displayName: block.name,
        defaultSizeFt: block.defaultSizeFt,
        easting: points.last.easting - 10,
        northing: points.last.northing + 5,
        colorArgb: 0xFF0057B8,
        label: block.name,
      ),
    ];

    final bytes = await buildStakingPlotPdf(
      points: points,
      jobName: 'SYMBOL LIBRARY DEMO',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberElevation,
        includeLinework: false,
      ),
      symbols: symbols,
      blockCatalog: catalog,
    );
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
  });
}
