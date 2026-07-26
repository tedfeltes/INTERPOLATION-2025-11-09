import 'dart:io';
import 'dart:math' as math;

/// Soft cap for plot drawing — full converted Civil DXFs can be 30k+ entities.
const int kMaxPlotLineworkEntities = 12000;

/// One plan-view polyline / segment / arc from a DXF ENTITIES section.
class LineworkEntity {
  const LineworkEntity({
    required this.layer,
    required this.type,
    required this.vertices,
    this.closed = false,
    this.bulge = 0,
    this.radius,
    this.startAngleDeg,
    this.endAngleDeg,
  });

  final String layer;
  final String type; // LINE, LWPOLYLINE, POLYLINE, ARC, CIRCLE
  /// Vertices as (easting, northing) — DXF X=E, Y=N for plan survey drawings.
  final List<List<double>> vertices;
  final bool closed;
  final double bulge;
  final double? radius;
  final double? startAngleDeg;
  final double? endAngleDeg;

  Iterable<List<double>> get samplePoints sync* {
    if (type == 'CIRCLE' && vertices.isNotEmpty && radius != null) {
      final c = vertices.first;
      for (var i = 0; i <= 48; i++) {
        final a = i * 2 * math.pi / 48;
        yield [c[0] + radius! * math.cos(a), c[1] + radius! * math.sin(a)];
      }
      return;
    }
    if (type == 'ARC' &&
        vertices.isNotEmpty &&
        radius != null &&
        startAngleDeg != null &&
        endAngleDeg != null) {
      final c = vertices.first;
      var a0 = startAngleDeg! * math.pi / 180;
      var a1 = endAngleDeg! * math.pi / 180;
      if (a1 < a0) a1 += 2 * math.pi;
      final steps = math.max(8, ((a1 - a0) / (math.pi / 24)).ceil());
      for (var i = 0; i <= steps; i++) {
        final a = a0 + (a1 - a0) * i / steps;
        yield [c[0] + radius! * math.cos(a), c[1] + radius! * math.sin(a)];
      }
      return;
    }
    for (final v in vertices) {
      yield v;
    }
  }
}

class DxfLinework {
  const DxfLinework({
    required this.entities,
    required this.layers,
    this.layerCounts = const {},
  });

  final List<LineworkEntity> entities;
  final List<String> layers;

  /// Precomputed entity counts per layer (avoid O(layers×entities) in the UI).
  final Map<String, int> layerCounts;

  int countForLayer(String layer) => layerCounts[layer] ?? 0;

  List<LineworkEntity> forLayers(Set<String> selected) {
    if (selected.isEmpty) return const [];
    return entities.where((e) => selected.contains(e.layer)).toList();
  }

  /// Entities for selected layers, capped for safe on-device plot drawing.
  List<LineworkEntity> forLayersCapped(
    Set<String> selected, {
    int maxEntities = kMaxPlotLineworkEntities,
  }) {
    final all = forLayers(selected);
    if (all.length <= maxEntities) return all;
    // Prefer keeping shorter entities / spread across layers: take in order
    // but stop at the budget (stable, predictable).
    return all.sublist(0, maxEntities);
  }

  /// Bounding box of selected layers as [minE, minN, maxE, maxN], or null.
  List<double>? boundsFor(Set<String> selected) {
    final ents = forLayers(selected);
    if (ents.isEmpty) return null;
    var minE = double.infinity;
    var minN = double.infinity;
    var maxE = -double.infinity;
    var maxN = -double.infinity;
    var any = false;
    for (final e in ents) {
      for (final p in e.samplePoints) {
        any = true;
        minE = math.min(minE, p[0]);
        maxE = math.max(maxE, p[0]);
        minN = math.min(minN, p[1]);
        maxN = math.max(maxN, p[1]);
      }
    }
    if (!any) return null;
    return [minE, minN, maxE, maxN];
  }
}

/// Read an ASCII DXF from disk and parse linework (safe for large converted files).
///
/// Prefer this over loading bytes through a platform channel — Android's binder
/// ~1 MB limit will crash the app when [withData] is used on big DXFs.
DxfLinework parseDxfLineworkFile(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw FileSystemException('DXF not found', path);
  }
  // Reject obvious binary DXF early (header is ASCII "AutoCAD Binary DXF").
  final raf = file.openSync();
  try {
    final head = raf.readSync(22);
    final headStr = String.fromCharCodes(head);
    if (headStr.startsWith('AutoCAD Binary DXF')) {
      throw const FormatException(
        'Binary DXF is not supported — re-export / convert to ASCII DXF.',
      );
    }
  } finally {
    raf.closeSync();
  }
  return parseDxfLinework(file.readAsStringSync());
}

/// Parse ASCII DXF stakeable linework (LINE / LWPOLYLINE / POLYLINE / ARC / CIRCLE).
DxfLinework parseDxfLinework(String text) {
  final pairs = _dxfPairs(text);
  final entities = <LineworkEntity>[];
  final layerCounts = <String, int>{};

  var i = 0;
  var inEntities = false;
  while (i < pairs.length) {
    final code = pairs[i][0];
    final value = pairs[i][1];
    i++;

    if (!inEntities) {
      if (code == '2' && value.toUpperCase() == 'ENTITIES') {
        inEntities = true;
      }
      continue;
    }

    if (code == '0' && value.toUpperCase() == 'ENDSEC') break;
    if (code != '0') continue;

    final etype = value.toUpperCase();
    if (etype == 'LINE') {
      final ent = _readUntilNext0(pairs, i);
      i = ent.next;
      final layer = (ent.map['8'] ?? '0').trim();
      final x0 = _d(ent.map, '10');
      final y0 = _d(ent.map, '20');
      final x1 = _d(ent.map, '11');
      final y1 = _d(ent.map, '21');
      if (x0 == null || y0 == null || x1 == null || y1 == null) continue;
      layerCounts[layer] = (layerCounts[layer] ?? 0) + 1;
      entities.add(LineworkEntity(
        layer: layer,
        type: 'LINE',
        vertices: [
          [x0, y0],
          [x1, y1],
        ],
      ));
    } else if (etype == 'LWPOLYLINE') {
      final ent = _readLwPolyline(pairs, i);
      i = ent.next;
      if (ent.vertices.length < 2) continue;
      layerCounts[ent.layer] = (layerCounts[ent.layer] ?? 0) + 1;
      entities.add(LineworkEntity(
        layer: ent.layer,
        type: 'LWPOLYLINE',
        vertices: ent.vertices,
        closed: ent.closed,
      ));
    } else if (etype == 'POLYLINE') {
      final ent = _readPolyline(pairs, i);
      i = ent.next;
      if (ent.vertices.length < 2) continue;
      layerCounts[ent.layer] = (layerCounts[ent.layer] ?? 0) + 1;
      entities.add(LineworkEntity(
        layer: ent.layer,
        type: 'POLYLINE',
        vertices: ent.vertices,
        closed: ent.closed,
      ));
    } else if (etype == 'ARC') {
      final ent = _readUntilNext0(pairs, i);
      i = ent.next;
      final layer = (ent.map['8'] ?? '0').trim();
      final cx = _d(ent.map, '10');
      final cy = _d(ent.map, '20');
      final r = _d(ent.map, '40');
      final a0 = _d(ent.map, '50');
      final a1 = _d(ent.map, '51');
      if (cx == null || cy == null || r == null || a0 == null || a1 == null) {
        continue;
      }
      layerCounts[layer] = (layerCounts[layer] ?? 0) + 1;
      entities.add(LineworkEntity(
        layer: layer,
        type: 'ARC',
        vertices: [
          [cx, cy],
        ],
        radius: r,
        startAngleDeg: a0,
        endAngleDeg: a1,
      ));
    } else if (etype == 'CIRCLE') {
      final ent = _readUntilNext0(pairs, i);
      i = ent.next;
      final layer = (ent.map['8'] ?? '0').trim();
      final cx = _d(ent.map, '10');
      final cy = _d(ent.map, '20');
      final r = _d(ent.map, '40');
      if (cx == null || cy == null || r == null) continue;
      layerCounts[layer] = (layerCounts[layer] ?? 0) + 1;
      entities.add(LineworkEntity(
        layer: layer,
        type: 'CIRCLE',
        vertices: [
          [cx, cy],
        ],
        radius: r,
      ));
    } else {
      // Skip unknown entity body (INSERT, POINT, TEXT, …)
      final ent = _readUntilNext0(pairs, i);
      i = ent.next;
    }
  }

  final layers = layerCounts.keys.toList()..sort();
  return DxfLinework(
    entities: entities,
    layers: layers,
    layerCounts: Map<String, int>.unmodifiable(layerCounts),
  );
}

List<List<String>> _dxfPairs(String text) {
  final lines = text
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final pairs = <List<String>>[];
  for (var i = 0; i + 1 < lines.length; i += 2) {
    pairs.add([lines[i].trim(), lines[i + 1].trimRight()]);
  }
  return pairs;
}

double? _d(Map<String, String> map, String code) {
  final v = map[code];
  if (v == null) return null;
  return double.tryParse(v.trim());
}

class _EntityRead {
  _EntityRead(this.map, this.next);
  final Map<String, String> map;
  final int next;
}

_EntityRead _readUntilNext0(List<List<String>> pairs, int start) {
  final map = <String, String>{};
  var i = start;
  while (i < pairs.length) {
    if (pairs[i][0] == '0') break;
    // last-wins for simple group codes; enough for LINE/ARC/CIRCLE
    map[pairs[i][0]] = pairs[i][1];
    i++;
  }
  return _EntityRead(map, i);
}

class _LwRead {
  _LwRead(this.layer, this.vertices, this.closed, this.next);
  final String layer;
  final List<List<double>> vertices;
  final bool closed;
  final int next;
}

_LwRead _readLwPolyline(List<List<String>> pairs, int start) {
  var layer = '0';
  var closed = false;
  final verts = <List<double>>[];
  double? pendingX;
  var i = start;
  while (i < pairs.length) {
    final code = pairs[i][0];
    final value = pairs[i][1];
    if (code == '0') break;
    if (code == '8') layer = value.trim();
    if (code == '70') {
      final flags = int.tryParse(value.trim()) ?? 0;
      closed = (flags & 1) != 0;
    }
    if (code == '10') {
      pendingX = double.tryParse(value.trim());
    } else if (code == '20') {
      final x = pendingX;
      if (x != null) {
        final y = double.tryParse(value.trim());
        if (y != null) verts.add([x, y]);
        pendingX = null;
      }
    }
    i++;
  }
  return _LwRead(layer, verts, closed, i);
}

_LwRead _readPolyline(List<List<String>> pairs, int start) {
  var layer = '0';
  var closed = false;
  final verts = <List<double>>[];
  var i = start;
  // Header until first VERTEX or SEQEND
  while (i < pairs.length) {
    final code = pairs[i][0];
    final value = pairs[i][1];
    if (code == '0') break;
    if (code == '8') layer = value.trim();
    if (code == '70') {
      final flags = int.tryParse(value.trim()) ?? 0;
      closed = (flags & 1) != 0;
    }
    i++;
  }
  while (i < pairs.length) {
    if (pairs[i][0] != '0') {
      i++;
      continue;
    }
    final etype = pairs[i][1].toUpperCase();
    i++;
    if (etype == 'SEQEND') break;
    if (etype != 'VERTEX') {
      // unexpected — stop
      break;
    }
    final ent = _readUntilNext0(pairs, i);
    i = ent.next;
    final x = _d(ent.map, '10');
    final y = _d(ent.map, '20');
    if (x != null && y != null) verts.add([x, y]);
    if ((ent.map['8'] ?? '').trim().isNotEmpty) {
      layer = ent.map['8']!.trim();
    }
  }
  return _LwRead(layer, verts, closed, i);
}
