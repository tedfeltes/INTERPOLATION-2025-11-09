/// Generate one sample staking plot PDF per selectable ANSI template.
///
/// Run from mobile/stakedxf:
///   dart run tool/generate_template_examples.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_templates.dart';

Future<void> main() async {
  final root = Directory.current.path;
  final outDir = Directory(
    p.normalize(p.join(root, '../../dist/plot_templates/examples')),
  );
  outDir.createSync(recursive: true);

  final points = parsePointsCsv(
    File(p.join(root, 'test/fixtures/sample_points.csv')).readAsStringSync(),
  );
  final lw = parseDxfLinework(
    File(p.join(root, 'test/fixtures/sample_linework.dxf')).readAsStringSync(),
  );

  final inventory = StringBuffer()
    ..writeln('# Template example PDFs')
    ..writeln()
    ..writeln('| File | Template | Size | Layout |')
    ..writeln('| --- | --- | --- | --- |');

  for (final t in kPlotTemplates) {
    final bytes = await buildStakingPlotPdf(
      points: points,
      jobName: 'TEMPLATE CATALOG',
      title: 'STAKING PLOT',
      date: DateTime(2026, 7, 15),
      options: PlotOptions(
        template: t,
        markerStyle: PointMarkerStyle.x,
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        showPointList: t.layout == PlotTemplateLayout.sidePanel,
        includeLinework: true,
      ),
      linework: lw.forLayers(lw.layers.toSet()),
    );
    final name = '${t.id}.pdf';
    final out = File(p.join(outDir.path, name));
    await out.writeAsBytes(bytes, flush: true);
    inventory.writeln(
      '| `$name` | ${t.name} | ${t.sizeCallout} | ${t.layout.label} |',
    );
    stdout.writeln('Wrote ${out.path} (${bytes.length} bytes)');
  }

  File(p.join(outDir.path, 'README.md')).writeAsStringSync(inventory.toString());
  stdout.writeln('Wrote ${kPlotTemplates.length} template examples → ${outDir.path}');
}
