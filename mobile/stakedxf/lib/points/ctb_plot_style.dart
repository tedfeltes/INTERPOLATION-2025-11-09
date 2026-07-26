import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'linetype_catalog.dart';

/// One ACI entry from a Color-Dependent Plot Style Table (.ctb).
class CtbAciStyle {
  const CtbAciStyle({
    required this.aci,
    required this.useObjectColor,
    required this.lineweightMm,
    this.rgb,
    this.screening = 100,
  });

  final int aci;
  final bool useObjectColor;
  final List<int>? rgb; // R,G,B after CTB white→black paper convention
  final double lineweightMm;
  final int screening;

  /// Resolved paper ARGB for this ACI (object hue or CTB override + screening).
  int resolveArgb({int? objectAci}) {
    final baseAci = objectAci ?? aci;
    int argb;
    if (useObjectColor || rgb == null) {
      argb = aciToArgb(baseAci);
    } else {
      final r = rgb![0].clamp(0, 255);
      final g = rgb![1].clamp(0, 255);
      final b = rgb![2].clamp(0, 255);
      argb = 0xFF000000 | (r << 16) | (g << 8) | b;
    }
    return applyScreening(argb, screening);
  }

  /// Lineweight in PDF/Flutter points (1 pt = 1/72").
  double get strokeWidthPt => (lineweightMm * 72.0 / 25.4).clamp(0.15, 6.0);
}

/// Loaded CTB plot style table used for staking plot PDF + preview.
class CtbPlotStyleTable {
  CtbPlotStyleTable._(this.styles, this.lineweightTableMm);

  final Map<int, CtbAciStyle> styles;
  final Map<int, double> lineweightTableMm;

  static CtbPlotStyleTable? _cached;

  static const assetPath = 'assets/plot_styles/staking_plot_ctb.json';

  static Future<CtbPlotStyleTable> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final table = fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cached = table;
    return table;
  }

  /// Sync fallback for tests / before assets bind.
  static CtbPlotStyleTable builtin() {
    return fromJson(_kBuiltinCtb);
  }

  static CtbPlotStyleTable fromJson(Map<String, dynamic> json) {
    final lwTable = <int, double>{};
    final lwRaw = json['lineweightTableMm'] as Map<String, dynamic>? ?? {};
    for (final e in lwRaw.entries) {
      lwTable[int.parse(e.key)] = (e.value as num).toDouble();
    }
    final styles = <int, CtbAciStyle>{};
    final sRaw = json['styles'] as Map<String, dynamic>? ?? {};
    for (final e in sRaw.entries) {
      final aci = int.parse(e.key);
      final m = e.value as Map<String, dynamic>;
      List<int>? rgb;
      final rgbRaw = m['rgb'];
      if (rgbRaw is List && rgbRaw.length >= 3) {
        rgb = [
          (rgbRaw[0] as num).toInt(),
          (rgbRaw[1] as num).toInt(),
          (rgbRaw[2] as num).toInt(),
        ];
      }
      styles[aci] = CtbAciStyle(
        aci: aci,
        useObjectColor: m['useObjectColor'] == true,
        rgb: rgb,
        lineweightMm: (m['lineweightMm'] as num?)?.toDouble() ?? 0.25,
        screening: (m['screening'] as num?)?.toInt() ?? 100,
      );
    }
    return CtbPlotStyleTable._(
      Map.unmodifiable(styles),
      Map.unmodifiable(lwTable),
    );
  }

  CtbAciStyle styleFor(int aci) {
    final a = aci.abs().clamp(1, 255);
    return styles[a] ??
        CtbAciStyle(
          aci: a,
          useObjectColor: true,
          lineweightMm: 0.25,
        );
  }

  /// Resolve paint for a DXF/entity ACI through this CTB.
  ({int colorArgb, double strokeWidthPt}) resolve(int aci) {
    final s = styleFor(aci);
    return (colorArgb: s.resolveArgb(objectAci: aci), strokeWidthPt: s.strokeWidthPt);
  }
}

int applyScreening(int argb, int screening) {
  final s = (screening.clamp(0, 100)) / 100.0;
  if (s >= 0.999) return argb;
  // Screen toward white paper (AutoCAD screening).
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  final nr = (r + (255 - r) * (1 - s)).round().clamp(0, 255);
  final ng = (g + (255 - g) * (1 - s)).round().clamp(0, 255);
  final nb = (b + (255 - b) * (1 - s)).round().clamp(0, 255);
  return 0xFF000000 | (nr << 16) | (ng << 8) | nb;
}

/// Compact builtin so unit tests work without Flutter asset binding.
const _kBuiltinCtb = {
  'lineweightTableMm': {
    '0': 0.0762,
    '4': 0.254,
    '5': 0.3556,
    '7': 0.508,
    '8': 0.635,
  },
  'styles': {
    '1': {
      'useObjectColor': true,
      'rgb': null,
      'lineweightMm': 0.254,
      'screening': 100,
    },
    '7': {
      'useObjectColor': true,
      'rgb': null,
      'lineweightMm': 0.254,
      'screening': 100,
    },
    '10': {
      'useObjectColor': true,
      'rgb': null,
      'lineweightMm': 0.254,
      'screening': 100,
    },
    '252': {
      'useObjectColor': false,
      'rgb': [152, 152, 152],
      'lineweightMm': 0.254,
      'screening': 100,
    },
  },
};

/// Default stake point / label ACI in the project CTB.
const kCtbPointLabelAci = 10;

/// Default linework ACI when DXF/layer has no color (project CTB grey).
const kCtbDefaultLineworkAci = 252;
