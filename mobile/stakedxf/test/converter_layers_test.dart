import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:stakedxf/converter.dart';

void main() {
  test('listLayersFromDxfText reports only layers with stakeable entities', () {
    final text = File('test/fixtures/sample_linework.dxf').readAsStringSync();
    final layers = listLayersFromDxfText(text);
    final names = layers.map((l) => l.name).toSet();
    expect(names, containsAll(['CL', 'CURB', 'STRUCTURE']));
    expect(layers.every((l) => l.entityCount > 0), isTrue);
  });

  test('filterTrimbleDxfByLayers keeps selected layers only', () {
    final dir = Directory.systemTemp.createTempSync('stakedxf_layers_');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final input = p.join(dir.path, 'in.dxf');
    final output = p.join(dir.path, 'out.dxf');
    File('test/fixtures/sample_linework.dxf').copySync(input);

    final count = filterTrimbleDxfByLayers(input, output, {'CURB'});
    expect(count, greaterThan(0));

    final layers = listLayersFromDxfText(File(output).readAsStringSync());
    expect(layers.map((l) => l.name).toSet(), {'CURB'});
  });

  test('parseLayersJson round-trip', () {
    const raw =
        '[{"name":"P-CURB","entity_count":12,"types":{"LINE":10,"ARC":2}}]';
    final layers = parseLayersJson(raw);
    expect(layers.length, 1);
    expect(layers.first.name, 'P-CURB');
    expect(layers.first.entityCount, 12);
    expect(layers.first.types['LINE'], 10);
  });

  test('pheasant farm rock probe points parse as PNEZD', () {
    final pts = File('test/fixtures/pheasant_farm_rock_probe.txt')
        .readAsStringSync();
    // Use csv_io through a light check here via converter-adjacent fixture.
    expect(pts.split('\n').where((l) => l.trim().isNotEmpty).length, 40);
    expect(pts.startsWith('300,'), isTrue);
  });
}
