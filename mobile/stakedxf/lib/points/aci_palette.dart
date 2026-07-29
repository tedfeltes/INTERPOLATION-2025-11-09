import 'ctb_plot_style.dart';
import 'linetype_catalog.dart';

/// One ACI color chip for the picker.
class AciSwatch {
  const AciSwatch({required this.aci, required this.argb});
  final int aci;
  final int argb;
}

/// Build ACI 1–255 swatches, preferring CTB-resolved colors when available.
///
/// Order is **numeric ACI 1→255** (legacy callers / reverse-lookup helpers).
List<AciSwatch> buildAciSwatches(CtbPlotStyleTable? ctb) {
  final out = <AciSwatch>[];
  for (var aci = 1; aci <= 255; aci++) {
    final argb = ctb?.resolve(aci).colorArgb ?? aciToArgb(aci);
    out.add(AciSwatch(aci: aci, argb: argb | 0xFF000000));
  }
  return out;
}

/// ACI swatches arranged for a 10-column picker grid by **shade family**.
///
/// Layout (Civil 3D / AutoCAD-style, not raw ACI order):
///  * Row 0 — standard index colors ACI 1–9, padded with ACI 250
///  * Rows 1–24 — hue families ACI 10–249 (one hue per row, 10 shade columns)
///  * Row 25 — remaining greys ACI 251–255 (padded)
///
/// ACI numbers on each swatch are unchanged; only display order changes.
List<AciSwatch> buildAciSwatchesByShade(CtbPlotStyleTable? ctb) {
  AciSwatch sw(int aci) {
    final argb = ctb?.resolve(aci).colorArgb ?? aciToArgb(aci);
    return AciSwatch(aci: aci, argb: argb | 0xFF000000);
  }

  final out = <AciSwatch>[];
  // Standards row (pad to 10 with first grey).
  for (var aci = 1; aci <= 9; aci++) {
    out.add(sw(aci));
  }
  out.add(sw(250));

  // 24 hue rows × 10 shade columns (ACI 10–249).
  for (var hue = 0; hue < 24; hue++) {
    for (var shade = 0; shade < 10; shade++) {
      out.add(sw(10 + hue * 10 + shade));
    }
  }

  // Remaining greys (incomplete last row is fine).
  for (var aci = 251; aci <= 255; aci++) {
    out.add(sw(aci));
  }
  return out;
}

/// Expand [aciToArgb] coverage with the classic AutoCAD ACI rainbow rows.
///
/// Keeps existing special cases (7 paper-black, 10 red, 252 grey) via
/// [aciToArgb]'s map, and fills gaps with the standard ACI algorithm.
int fullAciToArgb(int aci) => aciToArgb(aci);

/// Reverse lookup: return the ACI index that matches [argb] exactly, or
/// null if [argb] is a true-color (doesn't correspond to any ACI swatch).
///
/// [ctb] applies the same paper-space overrides as [buildAciSwatches] so
/// swatches that CTB overrides still map back to their ACI number instead
/// of falling into "true color".
int? argbToAci(int argb, {CtbPlotStyleTable? ctb}) {
  final rgb = argb & 0x00FFFFFF;
  for (var aci = 1; aci <= 255; aci++) {
    final swatch = (ctb?.resolve(aci).colorArgb ?? aciToArgb(aci)) & 0x00FFFFFF;
    if (swatch == rgb) return aci;
  }
  return null;
}

/// Human-readable label for a color chip in the layer manager / pickers.
///
/// Prefers an ACI number ("ACI 34") when the color maps back exactly to a
/// palette swatch; otherwise falls back to the hex triplet ("#FFA800"),
/// mirroring Civil 3D's Layer Properties panel behaviour.
String aciLabelFor(int argb, {CtbPlotStyleTable? ctb}) {
  final aci = argbToAci(argb, ctb: ctb);
  if (aci != null) return 'ACI $aci';
  final hex = (argb & 0x00FFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0');
  return '#$hex';
}
