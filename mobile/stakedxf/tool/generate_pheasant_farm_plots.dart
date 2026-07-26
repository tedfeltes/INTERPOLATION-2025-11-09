/// Pheasant Farm example staking plots — rock probe points + converted DXF layers.
///
/// Run from mobile/stakedxf:
///   dart run tool/generate_pheasant_farm_plots.dart
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';
import 'package:stakedxf/points/plot_symbols.dart';
import 'package:stakedxf/points/survey_point.dart';

class _Example {
  const _Example({
    required this.fileStem,
    required this.description,
    required this.options,
    required this.layers,
    this.withLibraryObjects = false,
  });

  final String fileStem;
  final String description;
  final PlotOptions options;
  final Set<String> layers;
  final bool withLibraryObjects;
}

Future<void> main() async {
  final root = Directory.current.path;
  final fixtures = p.join(root, 'test', 'fixtures');
  final outDir = Directory(
    p.normalize(p.join(root, '../../dist/pheasant_farm/plot_examples')),
  );
  outDir.createSync(recursive: true);

  final points = parsePointsCsv(
    File(p.join(fixtures, 'pheasant_farm_rock_probe.txt')).readAsStringSync(),
  );
  if (points.isEmpty) {
    stderr.writeln('No rock probe points found in fixtures.');
    exit(1);
  }

  final lw = parseDxfLinework(
    File(p.join(fixtures, 'pheasant_farm_staking_layers_clip.dxf'))
        .readAsStringSync(),
  );

  final examples = <_Example>[
    _Example(
      fileStem: '01_rock_probe_curb_storm',
      description:
          'Rock probe grid — large X, number + elevation, curb + storm layers',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberElevation,
        showPointList: false,
        includeLinework: true,
      ),
      layers: {'P-CURB', 'P-U-STM', 'P-SW'},
    ),
    _Example(
      fileStem: '02_utilities_with_table',
      description:
          'Filled triangle — full labels + point table, STM/SAN/WAT utilities',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.triangleFilled,
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        showPointList: true,
        includeLinework: true,
      ),
      layers: {'P-U-STM', 'P-U-SAN', 'P-U-WAT', 'P-(FUTURE)-U-STM'},
    ),
    _Example(
      fileStem: '03_lotlines_and_cl',
      description:
          'Circle markers — number + description, lot lines + centerline',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.circle,
        labelFormat: PointLabelFormat.numberDescription,
        showPointList: false,
        includeLinework: true,
      ),
      layers: {
        'RES_SURVEY\$0\$P-LOTLINE',
        'RES_SURVEY\$0\$E-LOTLINE',
        'RES_SURVEY\$0\$P-CL',
        'RES_SURVEY\$0\$E-ROW',
      },
    ),
    _Example(
      fileStem: '04_selected_layers_overview',
      description:
          'Large dots — no labels, all clipped staking layers (layer-select demo)',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeDot,
        labelFormat: PointLabelFormat.none,
        showPointList: false,
        includeLinework: true,
      ),
      layers: lw.layers.toSet(),
    ),
    _Example(
      fileStem: '05_points_only_grade_check',
      description: 'Dot markers — number + elevation, points only (no linework)',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.dot,
        labelFormat: PointLabelFormat.numberElevation,
        showPointList: true,
        includeLinework: false,
      ),
      layers: {},
    ),
    _Example(
      fileStem: '06_full_sheet_selected_linework',
      description:
          'Control-note style — table + curb/sidewalk/storm/lotline selection',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.triangleFilled,
        labelFormat: PointLabelFormat.numberDescriptionElevation,
        showPointList: true,
        includeLinework: true,
      ),
      layers: {
        'P-CURB',
        'P-SW',
        'P-U-STM',
        'RES_SURVEY\$0\$P-LOTLINE',
        'P-CONT',
      },
    ),
    _Example(
      fileStem: '07_object_library_overlay',
      description:
          'Object library demo — hydrant, MH, STOP, silt fence placed on rock probes',
      options: const PlotOptions(
        markerStyle: PointMarkerStyle.largeX,
        labelFormat: PointLabelFormat.numberElevation,
        showPointList: false,
        includeLinework: true,
      ),
      layers: {'P-CURB', 'P-U-STM', 'P-SW'},
      withLibraryObjects: true,
    ),
  ];

  final readme = StringBuffer()
    ..writeln('# Pheasant Farm — example staking plots')
    ..writeln()
    ..writeln('Demonstrates StakeDXF after Convert DWG layer selection:')
    ..writeln()
    ..writeln('- **Points:** `PHEASANT_FARM-STAKE-ROCK_PROBE_2026-07-16.txt` (40 rock probes)')
    ..writeln(
      '- **Linework:** clipped selected layers from `PHEASANT_FARM_trimble_access.dxf` '
      '(`PHEASANT_FARM_staking_layers_clip.dxf`)',
    )
    ..writeln('- Generated by `mobile/stakedxf/tool/generate_pheasant_farm_plots.dart`')
    ..writeln()
    ..writeln('| File | What it shows | Layers |')
    ..writeln('| --- | --- | --- |');

  final date = DateTime(2026, 7, 16);

  for (final ex in examples) {
    final linework = (ex.options.includeLinework && ex.layers.isNotEmpty)
        ? lw.forLayers(ex.layers)
        : const <LineworkEntity>[];
    final symbols = ex.withLibraryObjects
        ? _demoLibraryObjects(points)
        : const <PlacedPlotSymbol>[];

    final bytes = await buildStakingPlotPdf(
      points: points,
      jobName: 'PHEASANT FARM',
      title: 'STAKING PLOT',
      date: date,
      options: ex.options,
      linework: linework,
      symbols: symbols,
    );
    final outPath = p.join(outDir.path, '${ex.fileStem}.pdf');
    await File(outPath).writeAsBytes(bytes, flush: true);
    final layerList = ex.layers.isEmpty
        ? '—'
        : ex.layers.length > 4
            ? '${ex.layers.length} selected'
            : ex.layers.join(', ');
    readme.writeln(
      '| `${ex.fileStem}.pdf` | ${ex.description} | $layerList |',
    );
    stdout.writeln(
      'Wrote $outPath (${bytes.length} bytes, ${linework.length} linework ents)',
    );
  }

  await File(p.join(outDir.path, 'README.md')).writeAsString(readme.toString());
  // Convenience copy of the primary field sheet
  await File(p.join(outDir.path, '01_rock_probe_curb_storm.pdf')).copy(
    p.normalize(
      p.join(root, '../../dist/pheasant_farm/PHEASANT_FARM_staking_plot.pdf'),
    ),
  );
  stdout.writeln('Updated dist/pheasant_farm/PHEASANT_FARM_staking_plot.pdf');
  stdout.writeln('Done — ${examples.length} examples in ${outDir.path}');
}

List<PlacedPlotSymbol> _demoLibraryObjects(List<SurveyPoint> pts) {
  if (pts.length < 21) return const [];
  return [
    PlacedPlotSymbol.builtin(
      id: 'fh1',
      kind: PlotSymbolKind.fireHydrant,
      easting: pts[2].easting + 20,
      northing: pts[2].northing + 15,
      scale: 1.4,
      colorArgb: 0xFFE10600,
      label: 'FH-1',
    ),
    PlacedPlotSymbol.builtin(
      id: 'mh1',
      kind: PlotSymbolKind.stormManhole,
      easting: pts[5].easting,
      northing: pts[5].northing,
      colorArgb: 0xFF0057B8,
      label: 'STM MH',
    ),
    PlacedPlotSymbol.builtin(
      id: 'stop1',
      kind: PlotSymbolKind.stopSign,
      easting: pts[10].easting - 12,
      northing: pts[10].northing + 8,
      rotationDeg: 15,
      colorArgb: 0xFFE10600,
    ),
    PlacedPlotSymbol.builtin(
      id: 'sf1',
      kind: PlotSymbolKind.siltFence,
      easting: pts[15].easting,
      northing: pts[15].northing - 20,
      scale: 2.0,
      rotationDeg: -30,
      colorArgb: 0xFF1B7A3D,
      label: 'SILT FENCE',
    ),
    PlacedPlotSymbol.builtin(
      id: 'cb1',
      kind: PlotSymbolKind.catchBasin,
      easting: pts[20].easting + 8,
      northing: pts[20].northing - 8,
      colorArgb: 0xFF1A1A1A,
      label: 'CB',
    ),
  ];
}
