import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_symbols.dart';

void main() {
  test('symbol catalog covers civil sheet categories', () {
    expect(PlotSymbolKind.values.length, greaterThanOrEqualTo(25));
    for (final cat in PlotSymbolCategory.values) {
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

  test('placed symbol copyWith and size', () {
    final s = PlacedPlotSymbol(
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

  test('staking plot PDF includes library objects', () async {
    final points = parsePointsCsv(
      File('test/fixtures/sample_points.csv').readAsStringSync(),
    );
    final symbols = [
      PlacedPlotSymbol(
        id: '1',
        kind: PlotSymbolKind.fireHydrant,
        easting: points.first.easting + 15,
        northing: points.first.northing + 10,
        scale: 1.5,
        colorArgb: 0xFFE10600,
        label: 'FH-1',
      ),
      PlacedPlotSymbol(
        id: '2',
        kind: PlotSymbolKind.stopSign,
        easting: points.last.easting - 10,
        northing: points.last.northing + 5,
        rotationDeg: 90,
        colorArgb: 0xFFE10600,
      ),
      PlacedPlotSymbol(
        id: '3',
        kind: PlotSymbolKind.sanitaryManhole,
        easting: points[1].easting,
        northing: points[1].northing,
        colorArgb: 0xFF0057B8,
      ),
    ];

    final bytes = await buildStakingPlotPdf(
      points: points,
      jobName: 'SYMBOL LIBRARY DEMO',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberElevation,
        showPointList: false,
        includeLinework: false,
      ),
      symbols: symbols,
    );
    expect(bytes.length, greaterThan(1000));
    expect(bytes.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
  });
}
