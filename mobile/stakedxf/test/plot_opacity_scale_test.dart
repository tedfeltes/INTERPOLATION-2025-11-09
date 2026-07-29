import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/dxf_linework.dart';
import 'package:stakedxf/points/linework_style.dart';
import 'package:stakedxf/points/linetype_catalog.dart';
import 'package:stakedxf/points/plot_preview.dart';

void main() {
  group('previewFtPerPx', () {
    test('scales linearly with engineering scale', () {
      const sheetW = 396.0; // half of 792pt ≈ 11" preview
      const widthIn = 11.0;
      final a = previewFtPerPx(
        sheetWidthPx: sheetW,
        templateWidthIn: widthIn,
        scaleFtPerInch: 20,
      );
      final b = previewFtPerPx(
        sheetWidthPx: sheetW,
        templateWidthIn: widthIn,
        scaleFtPerInch: 40,
      );
      expect(b / a, closeTo(2.0, 1e-9));
      // Larger scaleFtPerInch → more feet per pixel → more area on sheet.
      expect(b, greaterThan(a));
    });
  });

  group('layer opacity override', () {
    test('resolveLineworkStyle applies layer opacity into color alpha', () {
      final ent = LineworkEntity(
        id: 'e1',
        type: 'LINE',
        layer: 'CURB',
        vertices: const [
          [0.0, 0.0],
          [10.0, 0.0],
        ],
      );
      final style = resolveLineworkStyle(
        entity: ent,
        catalog: LinetypeCatalog.builtin(),
        layerOverrides: {
          'CURB': const LineworkStyleOverride(opacity: 0.25),
        },
      );
      expect(style.opacity, closeTo(0.25, 1e-9));
      final alpha = (style.colorWithOpacity >> 24) & 0xFF;
      expect(alpha, closeTo(0.25 * 255, 1));
    });

    test('opacity 0 yields fully transparent ARGB', () {
      final ent = LineworkEntity(
        id: 'e2',
        type: 'LINE',
        layer: 'STM',
        vertices: const [
          [0.0, 0.0],
          [1.0, 1.0],
        ],
      );
      final style = resolveLineworkStyle(
        entity: ent,
        catalog: LinetypeCatalog.builtin(),
        layerOverrides: {
          'STM': const LineworkStyleOverride(opacity: 0.0),
        },
      );
      expect((style.colorWithOpacity >> 24) & 0xFF, 0);
    });
  });
}
