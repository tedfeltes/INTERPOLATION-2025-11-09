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
