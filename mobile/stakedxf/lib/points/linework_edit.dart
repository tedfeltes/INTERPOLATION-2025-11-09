import 'dxf_linework.dart';

int _nextId = 0;

String _newId(String prefix) {
  _nextId += 1;
  return '${prefix}_$_nextId';
}

/// Explode a polyline / arc / circle into individual LINE entities.
///
/// Point markers and other plot content are unaffected — this only splits
/// linework geometry so segments can be styled or removed independently.
List<LineworkEntity> explodeLineworkEntity(LineworkEntity ent) {
  final samples = [
    for (final p in ent.samplePoints)
      if (p[0].isFinite && p[1].isFinite) [p[0], p[1]],
  ];
  if (samples.length < 2) return [ent];

  final out = <LineworkEntity>[];
  final n = ent.closed || ent.type == 'CIRCLE'
      ? samples.length - 1
      : samples.length - 1;
  // For closed shapes samplePoints already repeats first point for CIRCLE;
  // for closed polylines, connect last→first.
  final pairs = <List<List<double>>>[];
  for (var i = 0; i < samples.length - 1; i++) {
    pairs.add([samples[i], samples[i + 1]]);
  }
  if (ent.closed && ent.type != 'CIRCLE') {
    final a = samples.last;
    final b = samples.first;
    if ((a[0] - b[0]).abs() > 1e-9 || (a[1] - b[1]).abs() > 1e-9) {
      pairs.add([a, b]);
    }
  }
  // Suppress unused warning if n unused — keep for clarity.
  assert(n >= 0);

  for (final pair in pairs) {
    final dx = pair[1][0] - pair[0][0];
    final dy = pair[1][1] - pair[0][1];
    if (dx.abs() < 1e-9 && dy.abs() < 1e-9) continue;
    out.add(
      LineworkEntity(
        id: _newId(ent.id.isEmpty ? 'seg' : ent.id),
        layer: ent.layer,
        type: 'LINE',
        vertices: [
          [pair[0][0], pair[0][1]],
          [pair[1][0], pair[1][1]],
        ],
        colorAci: ent.colorAci,
        linetypeName: ent.linetypeName,
        lineweight370: ent.lineweight370,
        linetypeScale: ent.linetypeScale,
        opacity: ent.opacity,
      ),
    );
  }
  return out.isEmpty ? [ent] : out;
}

/// Explode every matching entity in [entities] (by id). Returns a new list.
List<LineworkEntity> explodeEntitiesById(
  List<LineworkEntity> entities,
  String id,
) {
  final out = <LineworkEntity>[];
  for (final e in entities) {
    if (e.id == id) {
      out.addAll(explodeLineworkEntity(e));
    } else {
      out.add(e);
    }
  }
  return out;
}

/// Remove the segment between vertex [segmentIndex] and the next vertex.
///
/// For a 2-point LINE, removes the entity entirely.
/// For polylines, splits into zero/one/two polylines around the cut.
List<LineworkEntity> removeSegment(
  LineworkEntity ent, {
  required int segmentIndex,
}) {
  if (ent.type == 'LINE' || ent.vertices.length == 2) {
    return const [];
  }
  // Work from tessellated sample for arcs/circles after explode preferred;
  // for native polyline use vertices.
  final verts = [
    for (final v in ent.vertices)
      if (v.length >= 2 && v[0].isFinite && v[1].isFinite) [v[0], v[1]],
  ];
  if (verts.length < 2) return const [];

  final edgeCount = ent.closed ? verts.length : verts.length - 1;
  if (segmentIndex < 0 || segmentIndex >= edgeCount) return [ent];

  if (!ent.closed) {
    final left = verts.sublist(0, segmentIndex + 1);
    final right = verts.sublist(segmentIndex + 1);
    return [
      if (left.length >= 2) _polyFrom(ent, left),
      if (right.length >= 2) _polyFrom(ent, right),
    ];
  }

  // Closed: open the ring at the cut and keep one open polyline.
  final rotated = <List<double>>[
    ...verts.sublist(segmentIndex + 1),
    ...verts.sublist(0, segmentIndex + 1),
  ];
  return [
    if (rotated.length >= 2) _polyFrom(ent, rotated, closed: false),
  ];
}

/// Delete a vertex node; reconnects neighbors. Removes entity if < 2 verts remain.
List<LineworkEntity> removeNode(
  LineworkEntity ent, {
  required int nodeIndex,
}) {
  final verts = [
    for (final v in ent.vertices)
      if (v.length >= 2) [v[0], v[1]],
  ];
  if (nodeIndex < 0 || nodeIndex >= verts.length) return [ent];
  if (ent.type == 'LINE' || verts.length <= 2) return const [];
  verts.removeAt(nodeIndex);
  if (verts.length < 2) return const [];
  return [_polyFrom(ent, verts, closed: ent.closed && verts.length > 2)];
}

LineworkEntity _polyFrom(
  LineworkEntity src,
  List<List<double>> verts, {
  bool? closed,
}) {
  return LineworkEntity(
    id: _newId(src.id.isEmpty ? 'lw' : src.id),
    layer: src.layer,
    type: verts.length == 2 ? 'LINE' : 'LWPOLYLINE',
    vertices: verts,
    closed: closed ?? false,
    colorAci: src.colorAci,
    linetypeName: src.linetypeName,
    lineweight370: src.lineweight370,
    linetypeScale: src.linetypeScale,
    opacity: src.opacity,
  );
}

/// Replace entity [id] with [replacement] pieces in the list.
List<LineworkEntity> replaceEntity(
  List<LineworkEntity> entities,
  String id,
  List<LineworkEntity> replacement,
) {
  final out = <LineworkEntity>[];
  for (final e in entities) {
    if (e.id == id) {
      out.addAll(replacement);
    } else {
      out.add(e);
    }
  }
  return out;
}
