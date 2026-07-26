import 'package:pdf/pdf.dart';

/// ANSI engineering sheet sizes (inches).
enum AnsiSheetSize {
  a('ANSI A', 8.5, 11),
  b('ANSI B', 11, 17),
  c('ANSI C', 17, 22),
  d('ANSI D', 22, 34);

  const AnsiSheetSize(this.label, this.shortIn, this.longIn);

  final String label;

  /// Short edge in inches (e.g. 8.5 for A).
  final double shortIn;

  /// Long edge in inches (e.g. 11 for A).
  final double longIn;

  String get sizeCallout =>
      '${_fmt(shortIn)}"×${_fmt(longIn)}"';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

enum SheetOrientation {
  landscape('Landscape'),
  portrait('Portrait');

  const SheetOrientation(this.label);
  final String label;
}

/// Sheet composition styles observed in field staking plot PDFs.
enum PlotTemplateLayout {
  /// Full-bleed plan; north arrow + scale + sheet size in a corner.
  /// Matches the majority of TRIO field plots (curb, utilities, lot lines).
  fieldMap(
    'Field map',
    'Full-sheet plan with corner north arrow, scale, and sheet-size callout.',
  ),

  /// Full-bleed plan with title / job / date clustered with north + scale.
  /// Matches titled field plots (e.g. Cardinal Ridge test-pit style).
  fieldHeader(
    'Titled field map',
    'Full-sheet plan with title block, north arrow, and scale grouped together.',
  ),

  /// Bordered sheet: plan viewport + side panel (title, optional point table,
  /// graphic scale, liability note, firm block). The original StakeDXF control note.
  sidePanel(
    'Control note',
    'Bordered sheet with plan on the left and title / notes / point list on the right.',
  );

  const PlotTemplateLayout(this.label, this.description);
  final String label;
  final String description;
}

/// Where north arrow + scale sit on field-map layouts.
enum FieldLegendCorner {
  bottomRight,
  bottomLeft,
  topLeft,
}

/// A selectable staking-plot sheet template (ANSI size × orientation × layout).
class PlotTemplate {
  const PlotTemplate({
    required this.id,
    required this.name,
    required this.size,
    required this.orientation,
    required this.layout,
    this.legendCorner = FieldLegendCorner.bottomRight,
    this.blurb = '',
  });

  final String id;
  final String name;
  final AnsiSheetSize size;
  final SheetOrientation orientation;
  final PlotTemplateLayout layout;
  final FieldLegendCorner legendCorner;

  /// Short why-this-template note for the UI.
  final String blurb;

  double get widthIn => orientation == SheetOrientation.landscape
      ? size.longIn
      : size.shortIn;

  double get heightIn => orientation == SheetOrientation.landscape
      ? size.shortIn
      : size.longIn;

  PdfPageFormat get pageFormat => PdfPageFormat(
        widthIn * PdfPageFormat.inch,
        heightIn * PdfPageFormat.inch,
        marginAll: 0,
      );

  String get sizeCallout =>
      '${_fmt(widthIn)}"×${_fmt(heightIn)}"';

  String get subtitle =>
      '${size.label} $sizeCallout ${orientation.label} · ${layout.label}';

  @override
  bool operator ==(Object other) =>
      other is PlotTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Outer page padding (PDF points) before the content / border.
  double get outerPaddingPt {
    switch (size) {
      case AnsiSheetSize.a:
        return 18;
      case AnsiSheetSize.b:
        return 28;
      case AnsiSheetSize.c:
        return 36;
      case AnsiSheetSize.d:
        return 44;
    }
  }

  /// Usable plan width/height in inches for auto scale selection.
  ({double widthIn, double heightIn}) get usablePlanInches {
    final padIn = outerPaddingPt / 72.0;
    final sheetW = widthIn - 2 * padIn;
    final sheetH = heightIn - 2 * padIn;
    switch (layout) {
      case PlotTemplateLayout.fieldMap:
        // Thin footer strip (~0.85") for north/scale/date.
        return (widthIn: sheetW - 0.15, heightIn: sheetH - 0.95);
      case PlotTemplateLayout.fieldHeader:
        // Header cluster (~1.35") + small bottom margin.
        return (widthIn: sheetW - 0.15, heightIn: sheetH - 1.45);
      case PlotTemplateLayout.sidePanel:
        // ~58% / 42% split when table shown; callers pass showPointList.
        return (widthIn: sheetW * 0.72, heightIn: sheetH - 0.35);
    }
  }

  ({double widthIn, double heightIn}) usablePlanInchesFor({
    required bool showPointList,
  }) {
    if (layout != PlotTemplateLayout.sidePanel) {
      return usablePlanInches;
    }
    final padIn = outerPaddingPt / 72.0;
    final sheetW = widthIn - 2 * padIn;
    final sheetH = heightIn - 2 * padIn;
    final planFrac = showPointList ? 0.58 : 0.78;
    return (widthIn: sheetW * planFrac - 0.2, heightIn: sheetH - 0.35);
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Curated templates derived from commonalities in the field staking plot set
/// (Google Drive folder `1jmfZLTcZxhoksZeUCR0Jxq_cR9CgNp-S`).
const List<PlotTemplate> kPlotTemplates = [
  // --- Field map (dominant pattern in the Drive set) ---
  PlotTemplate(
    id: 'field_a_portrait',
    name: 'Field map — A portrait',
    size: AnsiSheetSize.a,
    orientation: SheetOrientation.portrait,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Letter sheet for tight lot-line / small-area stakes.',
  ),
  PlotTemplate(
    id: 'field_a_landscape',
    name: 'Field map — A landscape',
    size: AnsiSheetSize.a,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Letter landscape for short utility / offset runs.',
  ),
  PlotTemplate(
    id: 'field_b_portrait',
    name: 'Field map — B portrait',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.portrait,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Most common field size in the sample set (11×17).',
  ),
  PlotTemplate(
    id: 'field_b_landscape',
    name: 'Field map — B landscape',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Tabloid landscape — curb / water / buffer strips.',
  ),
  PlotTemplate(
    id: 'field_c_landscape',
    name: 'Field map — C landscape',
    size: AnsiSheetSize.c,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomLeft,
    blurb: 'ANSI C for medium site extents between B and D.',
  ),
  PlotTemplate(
    id: 'field_c_portrait',
    name: 'Field map — C portrait',
    size: AnsiSheetSize.c,
    orientation: SheetOrientation.portrait,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Tall C sheet for N–S corridors.',
  ),
  PlotTemplate(
    id: 'field_d_landscape',
    name: 'Field map — D landscape',
    size: AnsiSheetSize.d,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomLeft,
    blurb: 'Large sheet for long curb / site-wide stakeouts.',
  ),
  PlotTemplate(
    id: 'field_d_portrait',
    name: 'Field map — D portrait',
    size: AnsiSheetSize.d,
    orientation: SheetOrientation.portrait,
    layout: PlotTemplateLayout.fieldMap,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Tall D for long N–S alignments.',
  ),

  // --- Titled field map ---
  PlotTemplate(
    id: 'header_b_landscape',
    name: 'Titled field — B landscape',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.fieldHeader,
    legendCorner: FieldLegendCorner.topLeft,
    blurb: 'Title, date, north, and scale grouped (test-pit style).',
  ),
  PlotTemplate(
    id: 'header_b_portrait',
    name: 'Titled field — B portrait',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.portrait,
    layout: PlotTemplateLayout.fieldHeader,
    legendCorner: FieldLegendCorner.topLeft,
    blurb: 'Titled 11×17 portrait for named stake packages.',
  ),
  PlotTemplate(
    id: 'header_d_landscape',
    name: 'Titled field — D landscape',
    size: AnsiSheetSize.d,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.fieldHeader,
    legendCorner: FieldLegendCorner.topLeft,
    blurb: 'Large titled sheet with dual-scale-friendly header.',
  ),

  // --- Control note / side panel (StakeDXF original) ---
  PlotTemplate(
    id: 'control_a_portrait',
    name: 'Control note — A portrait',
    size: AnsiSheetSize.a,
    orientation: SheetOrientation.portrait,
    layout: PlotTemplateLayout.sidePanel,
    blurb: 'Bordered letter sheet with side title / notes panel.',
  ),
  PlotTemplate(
    id: 'control_b_landscape',
    name: 'Control note — B landscape',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.sidePanel,
    blurb: 'Default TRIO-style control note (17×11).',
  ),
  PlotTemplate(
    id: 'control_c_landscape',
    name: 'Control note — C landscape',
    size: AnsiSheetSize.c,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.sidePanel,
    blurb: 'Larger control note with room for longer point lists.',
  ),
  PlotTemplate(
    id: 'control_d_landscape',
    name: 'Control note — D landscape',
    size: AnsiSheetSize.d,
    orientation: SheetOrientation.landscape,
    layout: PlotTemplateLayout.sidePanel,
    blurb: 'Full-size control note for dense point tables.',
  ),
];

/// Default template — matches the historical StakeDXF control note.
const PlotTemplate kDefaultPlotTemplate = PlotTemplate(
  id: 'control_b_landscape',
  name: 'Control note — B landscape',
  size: AnsiSheetSize.b,
  orientation: SheetOrientation.landscape,
  layout: PlotTemplateLayout.sidePanel,
  blurb: 'Default TRIO-style control note (17×11).',
);

PlotTemplate plotTemplateById(String? id) {
  if (id == null || id.isEmpty) return kDefaultPlotTemplate;
  for (final t in kPlotTemplates) {
    if (t.id == id) return t;
  }
  return kDefaultPlotTemplate;
}

/// Templates grouped for UI section headers.
Map<PlotTemplateLayout, List<PlotTemplate>> plotTemplatesByLayout() {
  final map = <PlotTemplateLayout, List<PlotTemplate>>{};
  for (final t in kPlotTemplates) {
    map.putIfAbsent(t.layout, () => []).add(t);
  }
  return map;
}
