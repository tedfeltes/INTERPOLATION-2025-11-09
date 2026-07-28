import '../points/dxf_linework.dart';
import 'cogo_math.dart';

/// Project a plan point onto the nearest DXF linework entity.
///
/// Walks each entity's [LineworkEntity.samplePoints] (arcs/circles tessellated)
/// and returns the closest perpendicular foot with station measured from the
/// entity start. Offset sign: **right of travel = positive**.
StationOffsetResult? projectPointToLinework({
  required double northing,
  required double easting,
  required List<LineworkEntity> linework,
  Set<String>? layers,
  double? maxDistance,

  /// Station value at the start of each entity (added to along-entity distance).
  double beginStation = 0,
}) {
  StationOffsetResult? best;

  for (final ent in linework) {
    if (layers != null && layers.isNotEmpty && !layers.contains(ent.layer)) {
      continue;
    }
    final samples = [
      for (final p in ent.samplePoints)
        if (p.length >= 2 && p[0].isFinite && p[1].isFinite) p,
    ];
    if (samples.length < 2) continue;

    var stationAtSegStart = 0.0;
    for (var i = 0; i < samples.length - 1; i++) {
      final aE = samples[i][0];
      final aN = samples[i][1];
      final bE = samples[i + 1][0];
      final bN = samples[i + 1][1];
      final proj = projectToSegment(
        n: northing,
        e: easting,
        aN: aN,
        aE: aE,
        bN: bN,
        bE: bE,
      );
      final along = stationAtSegStart + proj.segLength * proj.t;
      final station = beginStation + along;
      if (best == null || proj.distance < best.distance) {
        best = StationOffsetResult(
          entityId: ent.id,
          layer: ent.layer,
          entityType: ent.type,
          station: station,
          offset: proj.signedOffset,
          projEasting: proj.projE,
          projNorthing: proj.projN,
          distance: proj.distance,
          segmentIndex: i,
        );
      }
      stationAtSegStart += proj.segLength;
    }

    // Closed figures: closing segment sample.last → sample.first.
    if (ent.closed && samples.length >= 3) {
      final aE = samples.last[0];
      final aN = samples.last[1];
      final bE = samples.first[0];
      final bN = samples.first[1];
      final proj = projectToSegment(
        n: northing,
        e: easting,
        aN: aN,
        aE: aE,
        bN: bN,
        bE: bE,
      );
      final along = stationAtSegStart + proj.segLength * proj.t;
      final station = beginStation + along;
      if (best == null || proj.distance < best.distance) {
        best = StationOffsetResult(
          entityId: ent.id,
          layer: ent.layer,
          entityType: ent.type,
          station: station,
          offset: proj.signedOffset,
          projEasting: proj.projE,
          projNorthing: proj.projN,
          distance: proj.distance,
          segmentIndex: samples.length - 1,
        );
      }
    }
  }

  if (best == null) return null;
  if (maxDistance != null && best.distance > maxDistance) return null;
  return best;
}

/// Total length of an entity along its sample polyline (feet).
double lineworkEntityLength(LineworkEntity ent) {
  final samples = [
    for (final p in ent.samplePoints)
      if (p.length >= 2 && p[0].isFinite && p[1].isFinite) p,
  ];
  if (samples.length < 2) return 0;
  var len = 0.0;
  for (var i = 0; i < samples.length - 1; i++) {
    len += horizontalDistance(
      n1: samples[i][1],
      e1: samples[i][0],
      n2: samples[i + 1][1],
      e2: samples[i + 1][0],
    );
  }
  if (ent.closed && samples.length >= 3) {
    len += horizontalDistance(
      n1: samples.last[1],
      e1: samples.last[0],
      n2: samples.first[1],
      e2: samples.first[0],
    );
  }
  return len;
}
