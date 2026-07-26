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

/// AutoCAD Color Index → ARGB (common ACI entries + greys).
int aciToArgb(int aci) {
  final a = aci.abs();
  const map = <int, int>{
    1: 0xFFFF0000,
    2: 0xFFFFFF00,
    3: 0xFF00FF00,
    4: 0xFF00FFFF,
    5: 0xFF0000FF,
    6: 0xFFFF00FF,
    7: 0xFF1A1A1A, // "white" on dark CAD → dark for paper plots
    8: 0xFF808080,
    9: 0xFFC0C0C0,
    30: 0xFFFF7F00,
    40: 0xFFFF7F7F,
    50: 0xFFFFFF99,
    60: 0xFF99FF99,
    70: 0xFF99FFFF,
    80: 0xFF7F7FFF,
    90: 0xFFFF7FFF,
    92: 0xFFA0A0A4,
    94: 0xFF808080,
    96: 0xFFA0A0A0,
    204: 0xFFB4B4B4,
    210: 0xFFA0A0FF,
    235: 0xFF5A5A5A,
    250: 0xFF333333,
    251: 0xFF505050,
    252: 0xFF696969,
    253: 0xFF828282,
    254: 0xFFBEBEBE,
    255: 0xFFE0E0E0,
  };
  if (map.containsKey(a)) return map[a]!;
  final h = (a % 250) / 250.0;
  final r = (0.5 + 0.5 * math.cos(2 * math.pi * h)).clamp(0.0, 1.0);
  final g = (0.5 + 0.5 * math.cos(2 * math.pi * (h + 0.33))).clamp(0.0, 1.0);
  final b = (0.5 + 0.5 * math.cos(2 * math.pi * (h + 0.67))).clamp(0.0, 1.0);
  return (0xFF << 24) |
      ((r * 255).round() << 16) |
      ((g * 255).round() << 8) |
      (b * 255).round();
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
