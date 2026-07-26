import 'dart:io';

import 'package:stakedxf/points/dxf_linework.dart';

void main(List<String> args) {
  final paths = args.isEmpty
      ? <String>[
          'test/fixtures/sample_linework.dxf',
          'test/fixtures/pheasant_farm_staking_layers_clip.dxf',
          '../../dist/pheasant_farm/PHEASANT_FARM_staking_layers_clip.dxf',
          '../../dist/pheasant_farm/PHEASANT_FARM_trimble_access.dxf',
        ]
      : args;
  for (final path in paths) {
    final f = File(path);
    if (!f.existsSync()) {
      stdout.writeln('MISSING $path');
      continue;
    }
    final len = f.lengthSync();
    stdout.writeln(
      '--- $path (${(len / 1024 / 1024).toStringAsFixed(2)} MB) ---',
    );
    try {
      final sw = Stopwatch()..start();
      final text = f.readAsStringSync();
      stdout.writeln('read ${sw.elapsedMilliseconds}ms');
      final lw = parseDxfLinework(text);
      stdout.writeln(
        'parse ${sw.elapsedMilliseconds}ms '
        'entities=${lw.entities.length} layers=${lw.layers.length}',
      );
      // Simulate export UI layer-count loop (O(layers*entities))
      final sw2 = Stopwatch()..start();
      var total = 0;
      for (final layer in lw.layers) {
        total += lw.entities.where((e) => e.layer == layer).length;
      }
      stdout.writeln(
        'UI count loop ${sw2.elapsedMilliseconds}ms totalCounted=$total',
      );
      final b = lw.boundsFor(lw.layers.toSet());
      stdout.writeln('bounds ${sw.elapsedMilliseconds}ms $b');
    } catch (e, st) {
      stdout.writeln('FAIL $e\n$st');
    }
  }
}
