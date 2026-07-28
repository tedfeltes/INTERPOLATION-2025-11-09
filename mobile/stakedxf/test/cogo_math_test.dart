import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/cogo/cogo_linework.dart';
import 'package:stakedxf/cogo/cogo_math.dart';
import 'package:stakedxf/points/dxf_linework.dart';

void main() {
  group('inverse', () {
    test('due east 100 ft', () {
      final r = inverse(n1: 1000, e1: 2000, n2: 1000, e2: 2100);
      expect(r.distance, closeTo(100, 1e-9));
      expect(r.deltaN, closeTo(0, 1e-9));
      expect(r.deltaE, closeTo(100, 1e-9));
      expect(r.azimuthDeg, closeTo(90, 1e-9));
    });

    test('northeast 45°', () {
      final r = inverse(n1: 0, e1: 0, n2: 100, e2: 100);
      expect(r.distance, closeTo(141.421356, 1e-5));
      expect(r.azimuthDeg, closeTo(45, 1e-9));
      expect(formatBearingDms(r.azimuthDeg), contains('N'));
      expect(formatBearingDms(r.azimuthDeg), contains('E'));
    });

    test('forward round-trip', () {
      final inv = inverse(n1: 5000, e1: 2000, n2: 5120, e2: 2090);
      final fwd = forward(
        n1: 5000,
        e1: 2000,
        azimuthDeg: inv.azimuthDeg,
        distance: inv.distance,
      );
      expect(fwd.n, closeTo(5120, 1e-6));
      expect(fwd.e, closeTo(2090, 1e-6));
    });
  });

  group('projectToSegment', () {
    test('point to the right of northbound segment is +offset', () {
      // A→B due north; point east of mid-segment → right of travel → +.
      final p = projectToSegment(
        n: 50,
        e: 10,
        aN: 0,
        aE: 0,
        bN: 100,
        bE: 0,
      );
      expect(p.t, closeTo(0.5, 1e-9));
      expect(p.projN, closeTo(50, 1e-9));
      expect(p.projE, closeTo(0, 1e-9));
      expect(p.distance, closeTo(10, 1e-9));
      expect(p.signedOffset, closeTo(10, 1e-9));
    });

    test('point to the left is −offset', () {
      final p = projectToSegment(
        n: 50,
        e: -8,
        aN: 0,
        aE: 0,
        bN: 100,
        bE: 0,
      );
      expect(p.signedOffset, closeTo(-8, 1e-9));
    });

    test('clamps beyond endpoints', () {
      final p = projectToSegment(
        n: 150,
        e: 5,
        aN: 0,
        aE: 0,
        bN: 100,
        bE: 0,
      );
      expect(p.t, 1.0);
      expect(p.projN, closeTo(100, 1e-9));
    });
  });

  group('formatStation / azimuth', () {
    test('station 0+00.00 and 12+34.56', () {
      expect(formatStation(0), '0+00.00');
      expect(formatStation(1234.56), '12+34.56');
    });

    test('azimuth DMS', () {
      expect(formatAzimuthDms(90), "090°00'00\"");
    });
  });

  group('projectPointToLinework', () {
    test('projects onto a LINE with begin station', () {
      final ent = LineworkEntity(
        id: 'L1',
        layer: 'CL',
        type: 'LINE',
        vertices: const [
          [0.0, 0.0],
          [0.0, 200.0],
        ],
      );
      final r = projectPointToLinework(
        northing: 50,
        easting: 12,
        linework: [ent],
        beginStation: 1000,
      );
      expect(r, isNotNull);
      expect(r!.layer, 'CL');
      expect(r.station, closeTo(1050, 1e-6));
      expect(r.offset, closeTo(12, 1e-6));
      expect(r.projNorthing, closeTo(50, 1e-6));
      expect(r.projEasting, closeTo(0, 1e-6));
    });

    test('picks nearest of two entities', () {
      final far = LineworkEntity(
        id: 'FAR',
        layer: 'A',
        type: 'LINE',
        vertices: const [
          [100.0, 0.0],
          [100.0, 100.0],
        ],
      );
      final near = LineworkEntity(
        id: 'NEAR',
        layer: 'B',
        type: 'LINE',
        vertices: const [
          [0.0, 0.0],
          [0.0, 100.0],
        ],
      );
      final r = projectPointToLinework(
        northing: 40,
        easting: 3,
        linework: [far, near],
      );
      expect(r!.entityId, 'NEAR');
      expect(r.distance, closeTo(3, 1e-6));
    });

    test('entity length for polyline', () {
      final ent = LineworkEntity(
        id: 'P1',
        layer: 'CL',
        type: 'LWPOLYLINE',
        vertices: const [
          [0.0, 0.0],
          [30.0, 0.0],
          [30.0, 40.0],
        ],
      );
      expect(lineworkEntityLength(ent), closeTo(70, 1e-9));
    });
  });
}
