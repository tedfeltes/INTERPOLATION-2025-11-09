import 'dart:math' as math;

/// Horizontal inverse between two plan points (N/E survey feet).
class InverseResult {
  const InverseResult({
    required this.deltaN,
    required this.deltaE,
    required this.distance,
    required this.azimuthDeg,
  });

  final double deltaN;
  final double deltaE;
  final double distance;

  /// Azimuth clockwise from North, 0–360°.
  final double azimuthDeg;

  String get bearingDms => formatBearingDms(azimuthDeg);
}

/// Projection of a point onto one polyline segment (survey feet).
class SegmentProjection {
  const SegmentProjection({
    required this.t,
    required this.projE,
    required this.projN,
    required this.distance,
    required this.segLength,
    required this.signedOffset,
  });

  /// 0–1 parameter along the segment.
  final double t;
  final double projE;
  final double projN;
  final double distance;
  final double segLength;

  /// Signed perpendicular offset: **right of travel direction is positive**
  /// (survey convention when walking A→B).
  final double signedOffset;
}

/// Station / offset of a point relative to DXF linework.
class StationOffsetResult {
  const StationOffsetResult({
    required this.entityId,
    required this.layer,
    required this.entityType,
    required this.station,
    required this.offset,
    required this.projEasting,
    required this.projNorthing,
    required this.distance,
    required this.segmentIndex,
  });

  final String entityId;
  final String layer;
  final String entityType;

  /// Cumulative distance along the entity from its start (feet).
  final double station;

  /// Signed offset: right of alignment travel = positive (feet).
  final double offset;

  final double projEasting;
  final double projNorthing;

  /// Absolute perpendicular distance (always ≥ 0).
  final double distance;

  final int segmentIndex;
}

/// Horizontal distance between two plan points.
double horizontalDistance({
  required double n1,
  required double e1,
  required double n2,
  required double e2,
}) {
  final dn = n2 - n1;
  final de = e2 - e1;
  return math.sqrt(dn * dn + de * de);
}

/// Azimuth clockwise from North (0–360°).
double azimuthDegFromNorth({
  required double n1,
  required double e1,
  required double n2,
  required double e2,
}) {
  final dn = n2 - n1;
  final de = e2 - e1;
  if (dn.abs() < 1e-12 && de.abs() < 1e-12) return 0.0;
  var deg = math.atan2(de, dn) * 180.0 / math.pi; // N=0, E=90
  if (deg < 0) deg += 360.0;
  return deg;
}

InverseResult inverse({
  required double n1,
  required double e1,
  required double n2,
  required double e2,
}) {
  final dn = n2 - n1;
  final de = e2 - e1;
  return InverseResult(
    deltaN: dn,
    deltaE: de,
    distance: math.sqrt(dn * dn + de * de),
    azimuthDeg: azimuthDegFromNorth(n1: n1, e1: e1, n2: n2, e2: e2),
  );
}

/// Forward: from (n1,e1) along [azimuthDeg] for [distance].
({double n, double e}) forward({
  required double n1,
  required double e1,
  required double azimuthDeg,
  required double distance,
}) {
  final rad = azimuthDeg * math.pi / 180.0;
  return (
    n: n1 + distance * math.cos(rad),
    e: e1 + distance * math.sin(rad),
  );
}

/// Project point P onto segment AB in plan N/E.
SegmentProjection projectToSegment({
  required double n,
  required double e,
  required double aN,
  required double aE,
  required double bN,
  required double bE,
}) {
  final abN = bN - aN;
  final abE = bE - aE;
  final len2 = abN * abN + abE * abE;
  if (len2 < 1e-18) {
    final dn = n - aN;
    final de = e - aE;
    return SegmentProjection(
      t: 0,
      projE: aE,
      projN: aN,
      distance: math.sqrt(dn * dn + de * de),
      segLength: 0,
      signedOffset: 0,
    );
  }
  var t = ((n - aN) * abN + (e - aE) * abE) / len2;
  t = t.clamp(0.0, 1.0);
  final projN = aN + abN * t;
  final projE = aE + abE * t;
  final dn = n - projN;
  final de = e - projE;
  final dist = math.sqrt(dn * dn + de * de);
  // Cross product ab × ap in plan (E,N): abE*dn - abN*de
  // Positive cross = left of travel (CCW). Survey: right of travel = +.
  final cross = abE * dn - abN * de;
  final signed = cross >= 0 ? -dist : dist;
  return SegmentProjection(
    t: t,
    projE: projE,
    projN: projN,
    distance: dist,
    segLength: math.sqrt(len2),
    signedOffset: signed,
  );
}

/// Format azimuth clockwise from North as `123°45'06"`.
String formatAzimuthDms(double azimuthDeg) {
  var az = azimuthDeg % 360.0;
  if (az < 0) az += 360.0;
  final deg = az.floor();
  final minFloat = (az - deg) * 60.0;
  var min = minFloat.floor();
  var sec = ((minFloat - min) * 60.0).round();
  if (sec == 60) {
    sec = 0;
    min += 1;
  }
  var outDeg = deg;
  if (min == 60) {
    min = 0;
    outDeg = (deg + 1) % 360;
  }
  return '${outDeg.toString().padLeft(3, '0')}°'
      "${min.toString().padLeft(2, '0')}'"
      '${sec.toString().padLeft(2, '0')}"';
}

/// Format azimuth as quadrant bearing, e.g. `N 45°30'12" E`.
String formatBearingDms(double azimuthDeg) {
  var az = azimuthDeg % 360.0;
  if (az < 0) az += 360.0;

  late String ns;
  late String ew;
  late double angle;
  if (az >= 0 && az < 90) {
    ns = 'N';
    ew = 'E';
    angle = az;
  } else if (az >= 90 && az < 180) {
    ns = 'S';
    ew = 'E';
    angle = 180 - az;
  } else if (az >= 180 && az < 270) {
    ns = 'S';
    ew = 'W';
    angle = az - 180;
  } else {
    ns = 'N';
    ew = 'W';
    angle = 360 - az;
  }

  final deg = angle.floor();
  final minFloat = (angle - deg) * 60.0;
  var min = minFloat.floor();
  var sec = ((minFloat - min) * 60.0).round();
  if (sec == 60) {
    sec = 0;
    min += 1;
  }
  if (min == 60) {
    min = 0;
    // deg bump is display-only; keep simple
  }
  return '$ns ${deg.toString().padLeft(2, '0')}°'
      "${min.toString().padLeft(2, '0')}'"
      '${sec.toString().padLeft(2, '0')}" $ew';
}

String formatStation(double stationFeet, {double equation = 0}) {
  final s = stationFeet + equation;
  final maj = (s / 100).floor();
  final min = s - maj * 100;
  return '$maj+${min.toStringAsFixed(2).padLeft(5, '0')}';
}
