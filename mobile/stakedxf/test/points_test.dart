import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_templates.dart';
import 'package:stakedxf/points/survey_point.dart';

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
}
