import 'dart:io';

import 'package:stakedxf/points/csv_io.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/plot_options.dart';
import 'package:stakedxf/points/plot_pdf.dart';

Future<void> main() async {
  final pts = parsePointsCsv(
    File('test/fixtures/pheasant_farm_rock_probe.txt').readAsStringSync(),
  );
  final text =
      File('../../dist/pheasant_farm/PHEASANT_FARM_trimble_access.dxf')
          .readAsStringSync();
  final lw = parseDxfLinework(text);
  stdout.writeln('entities ${lw.entities.length} layers ${lw.layers.length}');
  final sw = Stopwatch()..start();
  try {
    final bytes = await buildStakingPlotPdf(
      points: pts.take(20).toList(),
      jobName: 'CRASH TEST',
      options: const PlotOptions(includeLinework: true, showPointList: false),
      linework: lw.forLayers(lw.layers.toSet()),
    );
    stdout.writeln('pdf ${bytes.length} in ${sw.elapsedMilliseconds}ms');
    File('/tmp/crash_test_plot.pdf').writeAsBytesSync(bytes);
  } catch (e, st) {
    stdout.writeln('PDF FAIL $e\n$st');
  }
}
