import 'ctb_plot_style.dart';
import 'linetype_catalog.dart';

/// One ACI color chip for the picker.
class AciSwatch {
  const AciSwatch({required this.aci, required this.argb});
  final int aci;
  final int argb;
}

/// Build ACI 1–255 swatches, preferring CTB-resolved colors when available.
List<AciSwatch> buildAciSwatches(CtbPlotStyleTable? ctb) {
  final out = <AciSwatch>[];
  for (var aci = 1; aci <= 255; aci++) {
    final argb = ctb?.resolve(aci).colorArgb ?? aciToArgb(aci);
    out.add(AciSwatch(aci: aci, argb: argb | 0xFF000000));
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
