import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stakedxf/points/plot_template_picker.dart';
import 'package:stakedxf/points/plot_templates.dart';

/// The card-grid template picker replaces the two chained dropdowns
/// (Sheet size / Orientation) — the picker the user reported never
/// having seen. This test spins the widget up and verifies that:
///
///   * All 8 ANSI templates (A/B/C/D × Portrait/Landscape) are rendered.
///   * Tapping a card fires `onSelected` with the corresponding
///     template.
void main() {
  testWidgets('PlotTemplatePicker shows all ANSI templates as cards',
      (tester) async {
    final defaultTemplate = composePlotTemplate(
      size: AnsiSheetSize.b,
      orientation: SheetOrientation.landscape,
    );
    PlotTemplate? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            child: PlotTemplatePicker(
              selected: defaultTemplate,
              onSelected: (t) => picked = t,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // One label per ANSI size, twice (portrait + landscape).
    expect(find.text('ANSI A'), findsNWidgets(2));
    expect(find.text('ANSI B'), findsNWidgets(2));
    expect(find.text('ANSI C'), findsNWidgets(2));
    expect(find.text('ANSI D'), findsNWidgets(2));

    // Tap the first "ANSI A" card — the landscape variant sorts to
    // position 1 (the second widget in a portrait/landscape pair).
    await tester.tap(find.text('ANSI A').first);
    await tester.pumpAndSettle();

    expect(picked, isNotNull);
    expect(picked!.size, AnsiSheetSize.a);
  });
}
