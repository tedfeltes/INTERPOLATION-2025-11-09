import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_templates.dart';

void main() {
  test('catalog covers ANSI A–D with field and control layouts', () {
    expect(kPlotTemplates.length, greaterThanOrEqualTo(12));
    final sizes = kPlotTemplates.map((t) => t.size).toSet();
    expect(sizes, containsAll(AnsiSheetSize.values));
    final layouts = kPlotTemplates.map((t) => t.layout).toSet();
    expect(layouts, containsAll(PlotTemplateLayout.values));
    expect(kPlotTemplates.map((t) => t.id).toSet().length, kPlotTemplates.length);
  });

  test('page formats match ANSI inch dimensions', () {
    for (final t in kPlotTemplates) {
      final fmt = t.pageFormat;
      expect(fmt.width, closeTo(t.widthIn * PdfPageFormat.inch, 0.01));
      expect(fmt.height, closeTo(t.heightIn * PdfPageFormat.inch, 0.01));
      expect(t.widthIn * t.heightIn, greaterThan(8 * 10));
    }
    final a = plotTemplateById('field_a_portrait');
    expect(a.widthIn, 8.5);
    expect(a.heightIn, 11);
    final b = plotTemplateById('control_b_landscape');
    expect(b.widthIn, 17);
    expect(b.heightIn, 11);
    final d = plotTemplateById('field_d_landscape');
    expect(d.widthIn, 34);
    expect(d.heightIn, 22);
  });

  test('default template is control note B landscape', () {
    expect(kDefaultPlotTemplate.id, 'control_b_landscape');
    expect(kDefaultPlotTemplate.layout, PlotTemplateLayout.sidePanel);
    expect(plotTemplateById('missing'), kDefaultPlotTemplate);
  });

  test('each template produces a valid PDF', () async {
    final pts = parsePointsCsv(
      File('test/fixtures/sample_points.csv').readAsStringSync(),
    );
    for (final t in kPlotTemplates) {
      final bytes = await buildStakingPlotPdf(
        points: pts,
        jobName: 'TEMPLATE DEMO',
        date: DateTime(2026, 7, 15),
        title: 'STAKING PLOT',
        options: PlotOptions(
          template: t,
          markerStyle: PointMarkerStyle.x,
          labelFormat: PointLabelFormat.numberDescription,
          showPointList: t.layout == PlotTemplateLayout.sidePanel,
        ),
      );
      expect(bytes.length, greaterThan(800), reason: t.id);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    }
  });

  test('engineering scale uses template usable area', () {
    final pts = parsePointsCsv(
      File('test/fixtures/sample_points.csv').readAsStringSync(),
    );
    final small = chooseEngineeringScale(
      pts,
      template: plotTemplateById('field_d_landscape'),
    );
    final large = chooseEngineeringScale(
      pts,
      template: plotTemplateById('field_a_portrait'),
    );
    // Larger sheet → smaller (finer) engineering scale number.
    expect(small, lessThanOrEqualTo(large));
  });
}
