import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/aci_palette.dart';
import 'package:stakedxf/points/linetype_catalog.dart' show aciToArgb;

/// The layer-properties table in v1.24.3 finally shows the ACI number /
/// hex next to the colour swatch, Civil 3D style. These tests pin the
/// helpers behind that read-out so a future palette tweak can't silently
/// regress the labels.
void main() {
  group('argbToAci', () {
    test('recognises every palette swatch (except duplicates)', () {
      // A few palette entries deliberately share an RGB triplet — e.g.
      // ACI 10 is a paper-space "stake red" alias for ACI 1. Those
      // duplicates always resolve to the lowest matching index (ACI 1),
      // which is the canonical Civil 3D behaviour.
      for (var aci = 1; aci <= 255; aci++) {
        final argb = aciToArgb(aci);
        final resolved = argbToAci(argb);
        expect(resolved, isNotNull,
            reason: 'ACI $aci must map back to *some* palette swatch');
        expect(aciToArgb(resolved!), argb,
            reason:
                'Reverse lookup must return an index with the same RGB '
                '(got ACI $resolved for ACI $aci)');
      }
    });

    test('returns null for a colour that is not on the ACI palette', () {
      // A random true-colour surveyors like to pin manually.
      const gold = 0xFFFFA800;
      expect(argbToAci(gold), isNull);
    });

    test('ignores the alpha channel', () {
      final argb = aciToArgb(34) & 0x00FFFFFF; // strip alpha
      expect(argbToAci(argb), 34);
    });
  });

  group('aciLabelFor', () {
    test('shows the ACI number for palette colours', () {
      expect(aciLabelFor(aciToArgb(34)), 'ACI 34');
      expect(aciLabelFor(aciToArgb(1)), 'ACI 1');
    });

    test('falls back to a hex triplet for true colour', () {
      expect(aciLabelFor(0xFFFFA800), '#FFA800');
      expect(aciLabelFor(0x00123456), '#123456');
    });
  });

  group('buildAciSwatchesByShade', () {
    test('keeps every ACI 1–255 exactly once (except intentional grey pad)', () {
      final swatches = buildAciSwatchesByShade(null);
      // Standards 1–9 + 250, hues 10–249, greys 251–255 = 9+1+240+5 = 255.
      expect(swatches.length, 255);
      final acis = swatches.map((s) => s.aci).toSet();
      expect(acis.length, 255);
      for (var aci = 1; aci <= 255; aci++) {
        expect(acis.contains(aci), isTrue, reason: 'missing ACI $aci');
      }
    });

    test('groups each hue family into one 10-swatch row', () {
      final swatches = buildAciSwatchesByShade(null);
      // After the standards row (10 cells), row 1 starts at index 10.
      // Hue 0 = ACI 10–19.
      expect(
        [for (var i = 10; i < 20; i++) swatches[i].aci],
        [for (var a = 10; a <= 19; a++) a],
      );
      // Hue 1 = ACI 20–29 at the next row.
      expect(
        [for (var i = 20; i < 30; i++) swatches[i].aci],
        [for (var a = 20; a <= 29; a++) a],
      );
    });
  });
}
