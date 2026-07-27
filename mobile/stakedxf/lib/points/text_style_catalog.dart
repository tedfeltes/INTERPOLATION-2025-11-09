import 'dart:convert';

import 'package:flutter/material.dart' show FontStyle, FontWeight;
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;

/// One Civil/DXF text style mapped to a real bundled font face.
class PlotTextStyleDef {
  const PlotTextStyleDef({
    required this.id,
    required this.name,
    required this.font,
    required this.flutterFamily,
    required this.face,
    this.pdfFamily = 'times',
    this.widthFactor = 1.0,
    this.obliqueDeg = 0,
    this.bold = false,
    this.italic = false,
    this.description = '',
  });

  final String id;
  final String name;

  /// Original DWG font file / SHX name (e.g. `romans.shx`).
  final String font;

  /// Registered Flutter font family (PlotSerif, PlotSans, PlotRomans, …).
  final String flutterFamily;

  /// Face group key into bundled TTFs: serif | sans | mono | romans_tt |
  /// souvenir | poppins | roboto.
  final String face;

  /// Legacy Type1 fallback family name.
  final String pdfFamily;
  final double widthFactor;
  final double obliqueDeg;
  final bool bold;
  final bool italic;
  final String description;

  String get pickerLabel =>
      description.isEmpty ? name : '$name — $description';

  bool get effectiveItalic => italic || obliqueDeg.abs() > 0.5;

  FontWeight get flutterWeight =>
      bold ? FontWeight.w700 : FontWeight.w400;

  FontStyle get flutterStyle =>
      effectiveItalic ? FontStyle.italic : FontStyle.normal;

  /// Face key into [TextStyleCatalog] loaded TTF map.
  String get faceKey {
    final style = bold && effectiveItalic
        ? 'boldItalic'
        : bold
            ? 'bold'
            : effectiveItalic
                ? 'italic'
                : 'regular';
    return '${face}_$style';
  }

  /// Approximate Civil width factor as Flutter letter-spacing.
  double letterSpacingFor(double fontSize) {
    if ((widthFactor - 1.0).abs() < 0.02) return 0;
    return (widthFactor - 1.0) * fontSize * 0.35;
  }

  pw.Font legacyType1Font() {
    final family = pdfFamily.toLowerCase();
    if (family == 'times' || face == 'serif') {
      if (bold && effectiveItalic) return pw.Font.timesBoldItalic();
      if (bold) return pw.Font.timesBold();
      if (effectiveItalic) return pw.Font.timesItalic();
      return pw.Font.times();
    }
    if (family == 'courier' || face == 'mono') {
      if (bold) return pw.Font.courierBold();
      if (effectiveItalic) return pw.Font.courierOblique();
      return pw.Font.courier();
    }
    if (bold && effectiveItalic) return pw.Font.helveticaBoldOblique();
    if (bold) return pw.Font.helveticaBold();
    if (effectiveItalic) return pw.Font.helveticaOblique();
    return pw.Font.helvetica();
  }
}

/// Catalog of text styles from Drive Support Fonts + Civil STYLE tables.
///
/// TrueType faces from the Support folder (Romans TT, Souvenir, Poppins,
/// Roboto) are bundled. SHX fonts remain selectable and map to the closest
/// bundled stand-in (Romans→PlotRomans, Simplex/LD→PlotSans, etc.).
class TextStyleCatalog {
  TextStyleCatalog._(
    this.styles,
    this.byId,
    this.defaultStyleId,
    this._faceData,
  );

  final List<PlotTextStyleDef> styles;
  final Map<String, PlotTextStyleDef> byId;
  final String defaultStyleId;
  final Map<String, ByteData> _faceData;

  static TextStyleCatalog? _cached;

  static const assetPath = 'assets/plot_styles/text_style_catalog.json';

  static const faceAssets = <String, String>{
    'serif_regular': 'assets/fonts/LiberationSerif-Regular.ttf',
    'serif_italic': 'assets/fonts/LiberationSerif-Italic.ttf',
    'serif_bold': 'assets/fonts/LiberationSerif-Bold.ttf',
    'serif_boldItalic': 'assets/fonts/LiberationSerif-BoldItalic.ttf',
    'sans_regular': 'assets/fonts/LiberationSans-Regular.ttf',
    'sans_italic': 'assets/fonts/LiberationSans-Italic.ttf',
    'sans_bold': 'assets/fonts/LiberationSans-Bold.ttf',
    'sans_boldItalic': 'assets/fonts/LiberationSans-BoldItalic.ttf',
    'mono_regular': 'assets/fonts/LiberationMono-Regular.ttf',
    'mono_italic': 'assets/fonts/LiberationMono-Italic.ttf',
    'mono_bold': 'assets/fonts/LiberationMono-Bold.ttf',
    'mono_boldItalic': 'assets/fonts/LiberationMono-BoldItalic.ttf',
    // Drive Support Fonts (TrueType)
    'romans_tt_regular': 'assets/fonts/RomansTT-Regular.ttf',
    'romans_tt_italic': 'assets/fonts/RomansTT-Regular.ttf',
    'romans_tt_bold': 'assets/fonts/RomansTT-Regular.ttf',
    'romans_tt_boldItalic': 'assets/fonts/RomansTT-Regular.ttf',
    'souvenir_regular': 'assets/fonts/Souvenir-Regular.ttf',
    'souvenir_italic': 'assets/fonts/Souvenir-Italic.ttf',
    'souvenir_bold': 'assets/fonts/Souvenir-Bold.ttf',
    'souvenir_boldItalic': 'assets/fonts/Souvenir-BoldItalic.ttf',
    'poppins_regular': 'assets/fonts/Poppins-Regular.ttf',
    'poppins_italic': 'assets/fonts/Poppins-Italic.ttf',
    'poppins_bold': 'assets/fonts/Poppins-Bold.ttf',
    'poppins_boldItalic': 'assets/fonts/Poppins-BoldItalic.ttf',
    'roboto_regular': 'assets/fonts/Roboto-Regular.ttf',
    'roboto_italic': 'assets/fonts/Roboto-Italic.ttf',
    'roboto_bold': 'assets/fonts/Roboto-Bold.ttf',
    'roboto_boldItalic': 'assets/fonts/Roboto-BoldItalic.ttf',
  };

  static Future<TextStyleCatalog> load() async {
    final cached = _cached;
    if (cached != null && cached._faceData.isNotEmpty) return cached;
    final raw = await rootBundle.loadString(assetPath);
    final faces = <String, ByteData>{};
    for (final e in faceAssets.entries) {
      faces[e.key] = await rootBundle.load(e.value);
    }
    final table = fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
      faceData: faces,
    );
    _cached = table;
    return table;
  }

  /// Sync fallback for unit tests (Type1 PDF fonts; no TTF bytes).
  static TextStyleCatalog builtin() => fromJson(_kBuiltin);

  static TextStyleCatalog fromJson(
    Map<String, dynamic> json, {
    Map<String, ByteData> faceData = const {},
  }) {
    final list = <PlotTextStyleDef>[];
    final byId = <String, PlotTextStyleDef>{};
    for (final item in (json['styles'] as List<dynamic>? ?? const [])) {
      final m = item as Map<String, dynamic>;
      final face = (m['face'] as String?) ??
          _faceFromFlutterFamily(m['flutterFamily'] as String?);
      final flutterFamily = (m['flutterFamily'] as String?) ??
          _flutterFamilyFromFace(face);
      final def = PlotTextStyleDef(
        id: (m['id'] as String?) ?? 'Standard',
        name: (m['name'] as String?) ?? 'Standard',
        font: (m['font'] as String?) ?? 'romans.shx',
        flutterFamily: flutterFamily,
        face: face,
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
      Map.unmodifiable(faceData),
    );
  }

  static String _faceFromFlutterFamily(String? family) {
    switch (family) {
      case 'PlotSans':
        return 'sans';
      case 'PlotMono':
        return 'mono';
      case 'PlotRomans':
        return 'romans_tt';
      case 'PlotSouvenir':
        return 'souvenir';
      case 'PlotPoppins':
        return 'poppins';
      case 'PlotRoboto':
        return 'roboto';
      default:
        return 'serif';
    }
  }

  static String _flutterFamilyFromFace(String face) {
    switch (face) {
      case 'sans':
        return 'PlotSans';
      case 'mono':
        return 'PlotMono';
      case 'romans_tt':
        return 'PlotRomans';
      case 'souvenir':
        return 'PlotSouvenir';
      case 'poppins':
        return 'PlotPoppins';
      case 'roboto':
        return 'PlotRoboto';
      default:
        return 'PlotSerif';
    }
  }

  PlotTextStyleDef resolve(String? id) {
    if (id == null || id.trim().isEmpty) {
      return byId[defaultStyleId] ?? styles.first;
    }
    return byId[id] ?? byId[defaultStyleId] ?? styles.first;
  }

  /// PDF font for [style] — bundled TTF when loaded, else Type1 fallback.
  pw.Font pdfFont(PlotTextStyleDef style) {
    final data = _faceData[style.faceKey] ??
        _faceData['${style.face}_regular'];
    if (data != null) return pw.Font.ttf(data);
    return style.legacyType1Font();
  }

  bool get hasBundledFaces => _faceData.isNotEmpty;

  List<String> get names => [for (final s in styles) s.name];
}

const _kBuiltin = {
  'defaultStyleId': 'ROMANS_SHX',
  'styles': [
    {
      'id': "ROMAND_SHX",
      'name': "ROMAND_SHX",
      'font': "romand.shx",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 0.85,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "romand.shx",
    },
    {
      'id': "OR-LD_SHX",
      'name': "OR-LD_SHX",
      'font': "or-ld.shx",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "or-ld.shx",
    },
    {
      'id': "SHR",
      'name': "SHR",
      'font': "SIMPLEX",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "SIMPLEX",
    },
    {
      'id': "arial",
      'name': "arial",
      'font': "arial.ttf",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "arial.ttf",
    },
    {
      'id': "HL-LD",
      'name': "HL-LD",
      'font': "hl-ld.shx",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "hl-ld.shx",
    },
    {
      'id': "ROMANS",
      'name': "ROMANS",
      'font': "ROMANS",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "ROMANS",
    },
    {
      'id': "SYLFAEN",
      'name': "SYLFAEN",
      'font': "sylfaen.ttf",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "sylfaen.ttf",
    },
    {
      'id': "ITALICT",
      'name': "ITALICT",
      'font': "italict.shx",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': true,
      'description': "italict.shx",
    },
    {
      'id': "L80",
      'name': "L80",
      'font': "SIMPLEX.SHX",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "SIMPLEX.SHX",
    },
    {
      'id': "P-CONT",
      'name': "P-CONT",
      'font': "Souvenir Bold.ttf",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': true,
      'italic': false,
      'description': "Souvenir Bold.ttf",
    },
    {
      'id': "P-TEXT",
      'name': "P-TEXT",
      'font': "Romans TT.ttf",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 0.95,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "Romans TT.ttf",
    },
    {
      'id': "ROMANS_SHX",
      'name': "ROMANS_SHX",
      'font': "romans.shx",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 0.8,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "romans.shx",
    },
    {
      'id': "Standard",
      'name': "Standard",
      'font': "romans.shx",
      'face': "serif",
      'flutterFamily': "PlotSerif",
      'pdfFamily': "times",
      'widthFactor': 0.8,
      'obliqueDeg': 15.0,
      'bold': false,
      'italic': true,
      'description': "romans.shx",
    },
    {
      'id': "TD-LD_SHX",
      'name': "TD-LD_SHX",
      'font': "td-ld.shx",
      'face': "sans",
      'flutterFamily': "PlotSans",
      'pdfFamily': "helvetica",
      'widthFactor': 1.0,
      'obliqueDeg': 0.0,
      'bold': false,
      'italic': false,
      'description': "td-ld.shx",
    },
  ],
};
