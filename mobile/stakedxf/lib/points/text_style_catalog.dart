import 'dart:convert';

import 'package:flutter/material.dart' show FontStyle, FontWeight;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;

/// One Civil/DXF text style mapped to a PDF/Flutter face.
class PlotTextStyleDef {
  const PlotTextStyleDef({
    required this.id,
    required this.name,
    required this.font,
    required this.pdfFamily,
    this.widthFactor = 1.0,
    this.obliqueDeg = 0,
    this.bold = false,
    this.italic = false,
    this.description = '',
  });

  final String id;
  final String name;
  final String font;
  final String pdfFamily; // times | helvetica | courier
  final double widthFactor;
  final double obliqueDeg;
  final bool bold;
  final bool italic;
  final String description;

  String get pickerLabel =>
      description.isEmpty ? name : '$name — $description';

  /// Flutter TextStyle approximation (no custom TTF assets shipped).
  String get flutterFontFamily {
    switch (pdfFamily) {
      case 'times':
        return 'serif';
      case 'courier':
        return 'monospace';
      default:
        return 'sans-serif';
    }
  }

  FontWeight get flutterWeight =>
      bold ? FontWeight.w700 : FontWeight.w500;

  FontStyle get flutterStyle =>
      (italic || obliqueDeg.abs() > 0.5) ? FontStyle.italic : FontStyle.normal;

  pw.Font pdfFont() {
    final family = pdfFamily.toLowerCase();
    if (family == 'times') {
      if (bold && (italic || obliqueDeg.abs() > 0.5)) {
        return pw.Font.timesBoldItalic();
      }
      if (bold) return pw.Font.timesBold();
      if (italic || obliqueDeg.abs() > 0.5) return pw.Font.timesItalic();
      return pw.Font.times();
    }
    if (family == 'courier') {
      if (bold) return pw.Font.courierBold();
      if (italic || obliqueDeg.abs() > 0.5) return pw.Font.courierOblique();
      return pw.Font.courier();
    }
    // helvetica default
    if (bold && (italic || obliqueDeg.abs() > 0.5)) {
      return pw.Font.helveticaBoldOblique();
    }
    if (bold) return pw.Font.helveticaBold();
    if (italic || obliqueDeg.abs() > 0.5) return pw.Font.helveticaOblique();
    return pw.Font.helvetica();
  }
}

/// Catalog of text styles extracted from the project Civil DWG.
class TextStyleCatalog {
  TextStyleCatalog._(this.styles, this.byId, this.defaultStyleId);

  final List<PlotTextStyleDef> styles;
  final Map<String, PlotTextStyleDef> byId;
  final String defaultStyleId;

  static TextStyleCatalog? _cached;

  static const assetPath = 'assets/plot_styles/text_style_catalog.json';

  static Future<TextStyleCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final cat = fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _cached = cat;
    return cat;
  }

  static TextStyleCatalog builtin() => fromJson(_kBuiltin);

  static TextStyleCatalog fromJson(Map<String, dynamic> json) {
    final list = <PlotTextStyleDef>[];
    final byId = <String, PlotTextStyleDef>{};
    for (final item in (json['styles'] as List<dynamic>? ?? const [])) {
      final m = item as Map<String, dynamic>;
      final def = PlotTextStyleDef(
        id: (m['id'] as String?) ?? 'Standard',
        name: (m['name'] as String?) ?? 'Standard',
        font: (m['font'] as String?) ?? 'romans.shx',
        pdfFamily: (m['pdfFamily'] as String?) ?? 'times',
        widthFactor: (m['widthFactor'] as num?)?.toDouble() ?? 1.0,
        obliqueDeg: (m['obliqueDeg'] as num?)?.toDouble() ?? 0,
        bold: m['bold'] == true,
        italic: m['italic'] == true,
        description: (m['description'] as String?) ?? '',
      );
      list.add(def);
      byId[def.id] = def;
      byId[def.name] = def;
    }
    final defId = (json['defaultStyleId'] as String?) ??
        (list.isNotEmpty ? list.first.id : 'ROMANS_SHX');
    return TextStyleCatalog._(
      List.unmodifiable(list),
      Map.unmodifiable(byId),
      defId,
    );
  }

  PlotTextStyleDef resolve(String? id) {
    if (id == null || id.trim().isEmpty) {
      return byId[defaultStyleId] ?? styles.first;
    }
    return byId[id] ?? byId[defaultStyleId] ?? styles.first;
  }

  List<String> get names => [for (final s in styles) s.name];
}

const _kBuiltin = {
  'defaultStyleId': 'ROMANS_SHX',
  'styles': [
    {
      'id': 'ROMANS_SHX',
      'name': 'ROMANS_SHX',
      'font': 'romans.shx',
      'pdfFamily': 'times',
      'widthFactor': 0.8,
      'obliqueDeg': 0,
      'bold': false,
      'italic': false,
      'description': 'Romans SHX',
    },
    {
      'id': 'Standard',
      'name': 'Standard',
      'font': 'romans.shx',
      'pdfFamily': 'times',
      'widthFactor': 0.8,
      'obliqueDeg': 15,
      'bold': false,
      'italic': true,
      'description': 'Drawing standard',
    },
    {
      'id': 'arial',
      'name': 'Arial',
      'font': 'arial.ttf',
      'pdfFamily': 'helvetica',
      'widthFactor': 1.0,
      'obliqueDeg': 0,
      'bold': false,
      'italic': false,
      'description': 'Arial TTF',
    },
    {
      'id': 'P-CONT',
      'name': 'P-CONT',
      'font': 'Souvenir Bold.ttf',
      'pdfFamily': 'helvetica',
      'widthFactor': 1.0,
      'obliqueDeg': 0,
      'bold': true,
      'italic': false,
      'description': 'Bold annotation',
    },
  ],
};
