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

  /// UI label: `ANSI B (11"×17")`.
  String get pickerLabel => '$label ($sizeCallout)';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

enum SheetOrientation {
  landscape('Landscape'),
  portrait('Portrait');

  const SheetOrientation(this.label);
  final String label;
}

/// Sheet layout — StakeDXF ships a single **ANSI full bleed** style.
///
/// The plan fills the entire sheet edge-to-edge; a compact corner block
/// carries name / date / scale bar / north arrow. This matches the field
/// staking plots the TRIO crews take to site.
enum PlotTemplateLayout {
  fullBleed(
    'ANSI Full Bleed',
    'Full-sheet plan; name, date, scale, and north in one corner.',
  );

  const PlotTemplateLayout(this.label, this.description);
  final String label;
  final String description;
}

/// Where the corner block (name / date / north / scale) sits on the sheet.
enum FieldLegendCorner {
  bottomRight,
  bottomLeft,
  topLeft,
  topRight,
}

/// A selectable staking-plot sheet template (ANSI size × orientation).
class PlotTemplate {
  const PlotTemplate({
    required this.id,
    required this.name,
    required this.size,
    required this.orientation,
    this.legendCorner = FieldLegendCorner.bottomRight,
    this.blurb = '',
  });

  final String id;
  final String name;
  final AnsiSheetSize size;
  final SheetOrientation orientation;
  final FieldLegendCorner legendCorner;

  /// Short why-this-template note for the UI.
  final String blurb;

  /// Every StakeDXF sheet is now ANSI full bleed.
  PlotTemplateLayout get layout => PlotTemplateLayout.fullBleed;

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

  /// Field-standard "short × long" callout (e.g. `11"×17"`) — orientation
  /// independent, matching the convention on the TRIO staking plots.
  String get sizeCallout =>
      '${_fmt(size.shortIn)}"×${_fmt(size.longIn)}"';

  String get subtitle =>
      '${size.label} $sizeCallout ${orientation.label}';

  @override
  bool operator ==(Object other) =>
      other is PlotTemplate && other.id == id;

  @override
  int get hashCode => id.hashCode;

  /// Approximate area (in²) reserved for the corner name / scale / north
  /// block. Used only for auto-scale so it doesn't overlap the plan.
  double get legendReserveIn2 {
    switch (size) {
      case AnsiSheetSize.a:
        return 2.4 * 1.6;
      case AnsiSheetSize.b:
        return 3.0 * 1.8;
      case AnsiSheetSize.c:
        return 3.4 * 2.0;
      case AnsiSheetSize.d:
        return 4.2 * 2.3;
    }
  }

  /// Usable plan width/height in inches for auto scale selection.
  ///
  /// Full-bleed sheets get the entire page minus a hair-line safe margin
  /// (0.15") and a slightly reduced height to keep the corner block from
  /// overlapping edge stakes.
  ({double widthIn, double heightIn}) get usablePlanInches {
    return (widthIn: widthIn - 0.30, heightIn: heightIn - 0.35);
  }

  /// Kept for callers migrated from the old side-panel layout.
  ///
  /// The `showPointList` argument is ignored — there is no more point-list
  /// side panel — but the parameter is preserved so existing callers keep
  /// compiling.
  ({double widthIn, double heightIn}) usablePlanInchesFor({
    bool showPointList = false,
  }) =>
      usablePlanInches;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// ANSI full-bleed catalog — one template per (size × orientation).
const List<PlotTemplate> kPlotTemplates = [
  PlotTemplate(
    id: 'field_a_portrait',
    name: 'ANSI A · portrait',
    size: AnsiSheetSize.a,
    orientation: SheetOrientation.portrait,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Letter sheet for tight lot-line stakes.',
  ),
  PlotTemplate(
    id: 'field_a_landscape',
    name: 'ANSI A · landscape',
    size: AnsiSheetSize.a,
    orientation: SheetOrientation.landscape,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Letter landscape for short offset runs.',
  ),
  PlotTemplate(
    id: 'field_b_portrait',
    name: 'ANSI B · portrait',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.portrait,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Tabloid portrait for N–S curb runs.',
  ),
  PlotTemplate(
    id: 'field_b_landscape',
    name: 'ANSI B · landscape',
    size: AnsiSheetSize.b,
    orientation: SheetOrientation.landscape,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Default TRIO field size (17"×11").',
  ),
  PlotTemplate(
    id: 'field_c_landscape',
    name: 'ANSI C · landscape',
    size: AnsiSheetSize.c,
    orientation: SheetOrientation.landscape,
    legendCorner: FieldLegendCorner.bottomLeft,
    blurb: 'Medium site extents between B and D.',
  ),
  PlotTemplate(
    id: 'field_c_portrait',
    name: 'ANSI C · portrait',
    size: AnsiSheetSize.c,
    orientation: SheetOrientation.portrait,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Tall C sheet for N–S corridors.',
  ),
  PlotTemplate(
    id: 'field_d_landscape',
    name: 'ANSI D · landscape',
    size: AnsiSheetSize.d,
    orientation: SheetOrientation.landscape,
    legendCorner: FieldLegendCorner.bottomLeft,
    blurb: 'Full-size sheet for long curb / site stakeouts.',
  ),
  PlotTemplate(
    id: 'field_d_portrait',
    name: 'ANSI D · portrait',
    size: AnsiSheetSize.d,
    orientation: SheetOrientation.portrait,
    legendCorner: FieldLegendCorner.bottomRight,
    blurb: 'Tall D for long N–S alignments.',
  ),
];

/// Default template — 17"×11" ANSI B landscape field sheet.
const PlotTemplate kDefaultPlotTemplate = PlotTemplate(
  id: 'field_b_landscape',
  name: 'ANSI B · landscape',
  size: AnsiSheetSize.b,
  orientation: SheetOrientation.landscape,
  legendCorner: FieldLegendCorner.bottomRight,
  blurb: 'Default TRIO field size (17"×11").',
);

PlotTemplate plotTemplateById(String? id) {
  if (id == null || id.isEmpty) return kDefaultPlotTemplate;
  for (final t in kPlotTemplates) {
    if (t.id == id) return t;
  }
  final composed = tryParseComposedTemplateId(id);
  if (composed != null) return composed;
  return kDefaultPlotTemplate;
}

/// Build a sheet from ANSI size × orientation.
///
/// `layout` is accepted for backwards compatibility but ignored — every
/// StakeDXF sheet is ANSI full bleed.
PlotTemplate composePlotTemplate({
  required AnsiSheetSize size,
  required SheetOrientation orientation,
  PlotTemplateLayout layout = PlotTemplateLayout.fullBleed,
}) {
  final sizeKey = switch (size) {
    AnsiSheetSize.a => 'a',
    AnsiSheetSize.b => 'b',
    AnsiSheetSize.c => 'c',
    AnsiSheetSize.d => 'd',
  };
  final orientKey =
      orientation == SheetOrientation.landscape ? 'landscape' : 'portrait';
  final id = 'field_${sizeKey}_$orientKey';
  for (final t in kPlotTemplates) {
    if (t.id == id) return t;
  }
  final legend =
      (size == AnsiSheetSize.c || size == AnsiSheetSize.d) &&
              orientation == SheetOrientation.landscape
          ? FieldLegendCorner.bottomLeft
          : FieldLegendCorner.bottomRight;
  return PlotTemplate(
    id: id,
    name: '${size.pickerLabel} · ${orientation.label}',
    size: size,
    orientation: orientation,
    legendCorner: legend,
  );
}

PlotTemplate? tryParseComposedTemplateId(String id) {
  final parts = id.split('_');
  if (parts.length < 3) return null;
  // Accept legacy prefixes ("control_" / "header_") so historical ids still
  // resolve — they simply route to the full-bleed template of the same size.
  final size = switch (parts[1]) {
    'a' => AnsiSheetSize.a,
    'b' => AnsiSheetSize.b,
    'c' => AnsiSheetSize.c,
    'd' => AnsiSheetSize.d,
    _ => null,
  };
  final orient = switch (parts[2]) {
    'landscape' => SheetOrientation.landscape,
    'portrait' => SheetOrientation.portrait,
    _ => null,
  };
  if (size == null || orient == null) return null;
  return composePlotTemplate(size: size, orientation: orient);
}

/// Templates grouped for UI section headers.
Map<PlotTemplateLayout, List<PlotTemplate>> plotTemplatesByLayout() {
  return {PlotTemplateLayout.fullBleed: List.of(kPlotTemplates)};
}
