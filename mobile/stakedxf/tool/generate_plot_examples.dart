/// Generate example staking plot PDFs showcasing customization options.
///
/// Run from mobile/stakedxf:
///   dart run tool/generate_plot_examples.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/survey_point.dart';

class _Example {
  const _Example({
    required this.fileStem,
    required this.title,
    required this.jobName,
    required this.options,
    required this.useLinework,
    this.points,
    this.layers,
    this.description = '',
  });

  final String fileStem;
  final String title;
  final String jobName;
  final PlotOptions options;
  final bool useLinework;
  final List<SurveyPoint>? points;
  /// When null and [useLinework] is true, all DXF layers are used.
  final Set<String>? layers;
  final String description;
}

Future<void> main() async {
  final root = Directory.current.path;
  final fixtures = p.join(root, 'test', 'fixtures');
  final outDir = Directory(p.normalize(p.join(root, '../../dist/plot_examples')));
  outDir.createSync(recursive: true);

  final basePoints =
      parsePointsCsv(File(p.join(fixtures, 'sample_points.csv')).readAsStringSync());
  final densePoints = _denseSitePoints();
  final lw = parseDxfLinework(
    File(p.join(fixtures, 'sample_linework.dxf')).readAsStringSync(),
  );
  final examples = <_Example>[
    _Example(
      fileStem: '01_field_staking_large_x',
      title: 'STAKING PLOT',
      jobName: 'ALPINE HILLS',
      description: 'Field staking — large X, number + elevation, no table, full DXF linework',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberElevation,
        showPointList: false,
        includeLinework: true,
      ),
      useLinework: true,
    ),
    _Example(
      fileStem: '02_control_note_style_table',
      title: 'STAKING PLOT',
      jobName: 'ALPINE HILLS',
      description: 'Control-note style — filled triangle, full labels, point table on',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.triangleFilled,
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        showPointList: true,
        includeLinework: false,
      ),
      useLinework: false,
    ),
    _Example(
      fileStem: '03_markers_circle_dot',
      title: 'STAKING PLOT',
      jobName: 'STRUCTURES',
      description: 'Circle markers — number + description, curb linework only',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.circle,
        labelFormat: PointLabelFormat.numberDescription,
        showPointList: false,
        includeLinework: true,
      ),
      useLinework: true,
      layers: {'CURB'},
    ),
    _Example(
      fileStem: '04_markers_cross_plus',
      title: 'STAKING PLOT',
      jobName: 'CURB LAYOUT',
      description: 'Cross (+) markers — number only, no linework',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.cross,
        labelFormat: PointLabelFormat.numberOnly,
        showPointList: false,
        includeLinework: false,
      ),
      useLinework: false,
    ),
    _Example(
      fileStem: '05_markers_triangle_outline',
      title: 'STAKING PLOT',
      jobName: 'CONTROL CHECK',
      description: 'Triangle outline — number + description + elevation, table on',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.triangleOutline,
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        showPointList: true,
        includeLinework: true,
      ),
      useLinework: true,
    ),
    _Example(
      fileStem: '06_markers_large_dot_no_labels',
      title: 'STAKING PLOT',
      jobName: 'OVERVIEW',
      description: 'Large dots — no labels (clean overview with linework)',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeDot,
        labelFormat: PointLabelFormat.none,
        showPointList: false,
        includeLinework: true,
      ),
      useLinework: true,
      points: densePoints,
    ),
    _Example(
      fileStem: '07_labels_number_only',
      title: 'STAKING PLOT',
      jobName: 'STAKEOUT SET',
      description: 'Small X markers — number-only labels for dense sets',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.x,
        labelFormat: PointLabelFormat.numberOnly,
        showPointList: false,
        includeLinework: true,
      ),
      useLinework: true,
      points: densePoints,
    ),
    _Example(
      fileStem: '08_dot_with_elevations',
      title: 'STAKING PLOT',
      jobName: 'GRADE CHECK',
      description: 'Filled dots — number + elevation for grade staking',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.dot,
        labelFormat: PointLabelFormat.numberElevation,
        showPointList: false,
        includeLinework: false,
      ),
      useLinework: false,
      points: densePoints,
    ),
    _Example(
      fileStem: '09_full_sheet_with_table_and_linework',
      title: 'STAKING PLOT',
      jobName: 'WILDFLOWER',
      description: 'Filled triangle — full labels, table + all linework layers',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.triangleFilled,
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        showPointList: true,
        includeLinework: true,
      ),
      useLinework: true,
      points: densePoints,
    ),
    _Example(
      fileStem: '10_minimal_markers_only',
      title: 'STAKING PLOT',
      jobName: 'QUICK PLOT',
      description: 'Minimal — small dots, no labels, no table, no linework',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.dot,
        labelFormat: PointLabelFormat.none,
        showPointList: false,
        includeLinework: false,
      ),
      useLinework: false,
    ),
  ];

  final readme = StringBuffer()
    ..writeln('# Staking plot PDF examples')
    ..writeln()
    ..writeln('Generated by `mobile/stakedxf/tool/generate_plot_examples.dart`.')
    ..writeln()
    ..writeln('| File | What it shows |')
    ..writeln('| --- | --- |');

  final date = DateTime(2026, 7, 24);

  for (final ex in examples) {
    final pts = ex.points ?? basePoints;
    final linework = (ex.useLinework && ex.options.includeLinework)
        ? lw.forLayers(ex.layers ?? lw.layers.toSet())
        : const <LineworkEntity>[];

    final bytes = await buildStakingPlotPdf(
      points: pts,
      jobName: ex.jobName,
      title: ex.title,
      date: date,
      options: ex.options,
      linework: linework,
    );
    final outPath = p.join(outDir.path, '${ex.fileStem}.pdf');
    await File(outPath).writeAsBytes(bytes, flush: true);
    readme.writeln('| `${ex.fileStem}.pdf` | ${ex.description} |');
    stdout.writeln('Wrote $outPath (${bytes.length} bytes)');
  }

  await File(p.join(outDir.path, 'README.md')).writeAsString(readme.toString());
  // Keep dist/sample_staking_plot.pdf as the primary field example.
  await File(p.join(outDir.path, '01_field_staking_large_x.pdf'))
      .copy(p.normalize(p.join(root, '../../dist/sample_staking_plot.pdf')));
  stdout.writeln('Updated dist/sample_staking_plot.pdf');
  stdout.writeln('Done — ${examples.length} examples in ${outDir.path}');
}

/// Slightly denser point set to show label crowding / overview modes.
List<SurveyPoint> _denseSitePoints() {
  return const [
    SurveyPoint(id: '700', northing: 410233.245, easting: 2495897.503, elevation: 961.66, description: '125 HUB'),
    SurveyPoint(id: '701', northing: 410284.590, easting: 2495978.433, elevation: 958.51, description: '125 PK'),
    SurveyPoint(id: '702', northing: 410200.130, easting: 2495950.810, elevation: 964.80, description: '125 PK'),
    SurveyPoint(id: '703', northing: 410250.000, easting: 2495920.000, elevation: 970.58, description: '125 PK'),
    SurveyPoint(id: '704', northing: 410215.500, easting: 2495910.200, elevation: 962.10, description: 'IP'),
    SurveyPoint(id: '705', northing: 410265.800, easting: 2495945.600, elevation: 959.40, description: 'CURB'),
    SurveyPoint(id: '706', northing: 410240.100, easting: 2495965.000, elevation: 960.05, description: 'CATCH'),
    SurveyPoint(id: '707', northing: 410275.200, easting: 2495905.400, elevation: 966.20, description: 'BOC'),
    SurveyPoint(id: '708', northing: 410222.700, easting: 2495935.800, elevation: 963.55, description: 'EOC'),
    SurveyPoint(id: '709', northing: 410255.300, easting: 2495988.100, elevation: 957.90, description: 'MH'),
  ];
}
