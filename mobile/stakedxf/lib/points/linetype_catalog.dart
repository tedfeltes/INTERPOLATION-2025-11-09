import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

/// One dash/gap/dot (or text) element from a CAD linetype definition.
class LinetypeElement {
  const LinetypeElement({
    required this.length,
    this.text,
    this.scale = 1.0,
  });

  /// Positive = dash, negative = gap, zero = dot (CAD convention).
  final double length;
  final String? text;
  final double scale;

  bool get isGap => length < 0;
  bool get isDot => length == 0;
  bool get isDash => length > 0;
}

/// Named linetype pattern (from Civil 3D / Autodesk .lin + project DXF).
class LinetypeDef {
  const LinetypeDef({
    required this.id,
    required this.name,
    this.description = '',
    this.patternLength = 0,
    this.elements = const [],
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String description;
  final double patternLength;
  final List<LinetypeElement> elements;
  final List<String> aliases;

  bool get isContinuous =>
      elements.isEmpty || name.toUpperCase() == 'CONTINUOUS';

  /// Dash pattern lengths in paper points (72 pt/inch × element inches × scale).
  List<double> dashPatternPoints(double scale) {
    if (isContinuous) return const [];
    final s = scale.clamp(0.05, 50.0);
    final out = <double>[];
    for (final el in elements) {
      if (el.text != null && el.text!.trim().isNotEmpty) {
        // Approximate embedded text as a gap sized to the glyph run.
        final gap = (el.text!.length * 0.12 * el.scale + 0.08) * 72.0 * s;
        out.add(math.max(1.0, gap));
        continue;
      }
      if (el.isDot) {
        out.add(0.8 * s);
        out.add(math.max(1.0, 2.0 * s));
        continue;
      }
      final abs = el.length.abs() * 72.0 * s;
      out.add(math.max(0.5, abs));
    }
    // PDF/Flutter dash arrays must be even length (dash, gap, …).
    if (out.length.isOdd) out.add(math.max(1.0, 2.0 * s));
    return out;
  }
}

/// Built-in catalog compiled from Pheasant Farm Civil 3D LTYPEs + standards.
class LinetypeCatalog {
  LinetypeCatalog._(this.linetypes, this.byName);

  final List<LinetypeDef> linetypes;
  final Map<String, LinetypeDef> byName;

  /// Display names for pickers (Layer Properties Manager, etc.).
  List<String> get names => [for (final l in linetypes) l.name];

  static LinetypeCatalog? _cached;

  static Future<LinetypeCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw =
        await rootBundle.loadString('assets/linework/linetype_catalog.json');
    final cat = fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cached = cat;
    return cat;
  }

  /// Synchronous fallback used in tests / when asset not loaded yet.
  static LinetypeCatalog builtin() => fromJson(_kBuiltinFallback);

  static LinetypeCatalog fromJson(Map<String, dynamic> json) {
    final list = <LinetypeDef>[];
    final byName = <String, LinetypeDef>{};
    final arr = json['linetypes'] as List<dynamic>? ?? const [];
    for (final item in arr) {
      final m = item as Map<String, dynamic>;
      final els = <LinetypeElement>[
        for (final e in (m['elements'] as List<dynamic>? ?? const []))
          LinetypeElement(
            length: (e as Map<String, dynamic>)['length'] is num
                ? (e['length'] as num).toDouble()
                : 0,
            text: e['text'] as String?,
            scale: e['scale'] is num ? (e['scale'] as num).toDouble() : 1.0,
          ),
      ];
      final def = LinetypeDef(
        id: (m['id'] as String?) ?? (m['name'] as String? ?? 'CONTINUOUS'),
        name: (m['name'] as String?) ?? 'Continuous',
        description: (m['description'] as String?) ?? '',
        patternLength: (m['patternLength'] as num?)?.toDouble() ?? 0,
        elements: els,
        aliases: [
          for (final a in (m['aliases'] as List<dynamic>? ?? const []))
            a.toString(),
        ],
      );
      list.add(def);
      void put(String k) {
        if (k.trim().isEmpty) return;
        byName[k] = def;
        byName[k.toUpperCase()] = def;
        byName[normalizeLinetypeName(k)] = def;
        byName[normalizeLinetypeName(k).toUpperCase()] = def;
      }

      put(def.name);
      put(def.id);
      for (final a in def.aliases) {
        put(a);
      }
    }
    if (!byName.containsKey('CONTINUOUS')) {
      const c = LinetypeDef(id: 'CONTINUOUS', name: 'Continuous');
      list.insert(0, c);
      byName['CONTINUOUS'] = c;
      byName['Continuous'] = c;
    }
    return LinetypeCatalog._(List.unmodifiable(list), byName);
  }

  LinetypeDef resolve(String? name) {
    if (name == null || name.trim().isEmpty) {
      return byName['CONTINUOUS']!;
    }
    final n = normalizeLinetypeName(name);
    return byName[n] ??
        byName[n.toUpperCase()] ??
        byName[name] ??
        byName[name.toUpperCase()] ??
        byName['CONTINUOUS']!;
  }
}

/// Strip xref-style prefixes (`RES_SURVEY$0$DASHED` → `DASHED`).
String normalizeLinetypeName(String name) {
  var n = name.trim();
  if (n.contains(r'$0$')) {
    n = n.split(r'$0$').last;
  } else if (n.contains(r'$')) {
    n = n.split(r'$').last;
  }
  return n;
}

/// AutoCAD Color Index → ARGB (full ACI 1–255 for paper plots).
int aciToArgb(int aci) {
  final a = aci.abs().clamp(0, 255);
  // Specials tuned for paper (ACI 7 “white” → near-black ink).
  const specials = <int, int>{
    0: 0xFF1A1A1A,
    1: 0xFFFF0000,
    2: 0xFFFFFF00,
    3: 0xFF00FF00,
    4: 0xFF00FFFF,
    5: 0xFF0000FF,
    6: 0xFFFF00FF,
    7: 0xFF1A1A1A,
    8: 0xFF808080,
    9: 0xFFC0C0C0,
    10: 0xFFFF0000, // stake points / labels
    250: 0xFF333333,
    251: 0xFF505050,
    252: 0xFFA0A0A4, // default linework grey
    253: 0xFF828282,
    254: 0xFFBEBEBE,
    255: 0xFFE0E0E0,
  };
  if (specials.containsKey(a)) return specials[a]!;

  // Classic AutoCAD ACI rows 10–249: 24 hues × 10 shades / tints.
  if (a >= 10 && a <= 249) {
    final row = (a - 10) ~/ 10; // 0..23
    final col = (a - 10) % 10; // 0..9
    final hue = row * 15.0; // degrees
    // Columns: 0 full, 1–4 darker, 5–9 lighter pastels (approximate CAD).
    double value;
    double sat;
    if (col == 0) {
      value = 1.0;
      sat = 1.0;
    } else if (col <= 4) {
      value = 1.0 - col * 0.18;
      sat = 1.0;
    } else {
      value = 1.0;
      sat = 1.0 - (col - 4) * 0.16;
    }
    return _hsvArgb(hue, sat.clamp(0.15, 1.0), value.clamp(0.15, 1.0));
  }

  // Greys 250–255 already handled; fallback.
  final g = (a * 255 / 255).round().clamp(0, 255);
  return 0xFF000000 | (g << 16) | (g << 8) | g;
}

int _hsvArgb(double h, double s, double v) {
  final c = v * s;
  final x = c * (1 - (((h / 60) % 2) - 1).abs());
  final m = v - c;
  double r = 0, g = 0, b = 0;
  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else {
    r = c;
    b = x;
  }
  final ri = ((r + m) * 255).round().clamp(0, 255);
  final gi = ((g + m) * 255).round().clamp(0, 255);
  final bi = ((b + m) * 255).round().clamp(0, 255);
  return 0xFF000000 | (ri << 16) | (gi << 8) | bi;
}

/// DXF lineweight (group 370, hundredths of mm) → paper stroke points.
double lineweightToPoints(int lineweight370, {double fallback = 0.7}) {
  if (lineweight370 < 0) return fallback; // ByLayer / ByBlock / default
  return (lineweight370 / 100.0) * 72.0 / 25.4;
}

/// Minimal embedded fallback so unit tests work without binding Flutter assets.
const _kBuiltinFallback = {
  'linetypes': [
    {
      'id': 'CONTINUOUS',
      'name': 'Continuous',
      'description': 'Solid line',
      'patternLength': 0,
      'elements': [],
      'aliases': [],
    },
    {
      'id': 'DASHED',
      'name': 'DASHED',
      'description': 'Dashed',
      'patternLength': 0.75,
      'elements': [
        {'length': 0.5},
        {'length': -0.25},
      ],
      'aliases': [],
    },
    {
      'id': 'HIDDEN',
      'name': 'HIDDEN',
      'description': 'Hidden',
      'patternLength': 0.375,
      'elements': [
        {'length': 0.25},
        {'length': -0.125},
      ],
      'aliases': [],
    },
    {
      'id': 'CENTER',
      'name': 'CENTER',
      'description': 'Center',
      'patternLength': 2.0,
      'elements': [
        {'length': 1.25},
        {'length': -0.25},
        {'length': 0.25},
        {'length': -0.25},
      ],
      'aliases': [],
    },
    {
      'id': 'STORM',
      'name': 'STORM',
      'description': 'Storm',
      'patternLength': 0.6,
      'elements': [
        {'length': 0.5},
        {'length': -0.1},
      ],
      'aliases': [],
    },
    {
      'id': 'SANITARY',
      'name': 'SANITARY',
      'description': 'Sanitary',
      'patternLength': 1.7,
      'elements': [
        {'length': 1.5},
        {'length': -0.2},
      ],
      'aliases': [],
    },
  ],
};
